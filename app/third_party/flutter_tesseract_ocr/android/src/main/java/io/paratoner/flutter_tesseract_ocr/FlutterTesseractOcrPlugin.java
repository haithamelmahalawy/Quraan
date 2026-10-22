package io.paratoner.flutter_tesseract_ocr;

import com.googlecode.tesseract.android.TessBaseAPI;
import android.os.Handler;
import android.os.Looper;
import androidx.annotation.NonNull;
import java.io.File;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** One serial worker owns the engine, including initialization and disposal. */
public class FlutterTesseractOcrPlugin implements FlutterPlugin, MethodCallHandler {
  private TessBaseAPI baseApi;
  private String lastLanguage = "";
  private String lastPath = "";
  private MethodChannel channel;
  private ExecutorService worker;
  private final Handler main = new Handler(Looper.getMainLooper());

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    worker = Executors.newSingleThreadExecutor();
    channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_tesseract_ocr");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    channel = null;
    // Recycling may not race with an active recognition call.
    worker.execute(this::recycle);
    worker.shutdown();
  }

  private void recycle() {
    if (baseApi != null) {
      baseApi.recycle();
      baseApi = null;
    }
    lastLanguage = "";
    lastPath = "";
  }

  private void initialize(String path, String language) {
    if (baseApi != null && lastLanguage.equals(language) && lastPath.equals(path)) return;
    recycle();
    baseApi = new TessBaseAPI();
    if (!baseApi.init(path, language)) {
      recycle();
      throw new IllegalStateException("Could not initialize OCR language: " + language);
    }
    lastLanguage = language;
    lastPath = path;
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (!call.method.equals("prepare") && !call.method.equals("extractPixels") &&
        !call.method.equals("extractText") && !call.method.equals("extractHocr")) {
      result.notImplemented();
      return;
    }
    worker.execute(() -> {
      try {
        String path = call.argument("tessData");
        String language = call.argument("language");
        initialize(path, language == null ? "eng" : language);
        if (call.method.equals("prepare")) {
          main.post(() -> result.success(null));
          return;
        }
        Map<String, String> args = call.argument("args");
        int psm = TessBaseAPI.PageSegMode.PSM_AUTO_OSD;
        if (args != null) {
          for (Map.Entry<String, String> entry : args.entrySet()) {
            if (entry.getKey().equals("psm")) psm = Integer.parseInt(entry.getValue());
            else baseApi.setVariable(entry.getKey(), entry.getValue());
          }
        }
        baseApi.setPageSegMode(psm);
        if (call.method.equals("extractPixels")) {
          byte[] pixels = call.argument("pixels");
          Integer width = call.argument("width");
          Integer height = call.argument("height");
          if (pixels == null || width == null || height == null || width <= 0 ||
              height <= 0 || (long) width * height != pixels.length) {
            throw new IllegalArgumentException("Invalid luminance image");
          }
          baseApi.setImage(pixels, width, height, 1, width);
        } else {
          String imagePath = call.argument("imagePath");
          if (imagePath == null) throw new IllegalArgumentException("Missing image path");
          baseApi.setImage(new File(imagePath));
        }
        String text = call.method.equals("extractHocr")
            ? baseApi.getHOCRText(0) : baseApi.getUTF8Text();
        main.post(() -> result.success(text == null ? "" : text));
      } catch (Exception error) {
        main.post(() -> result.error("ocr_error", error.getMessage(), null));
      } finally {
        // Free per-frame pixels/results, keeping the language model warm.
        if (baseApi != null) baseApi.clear();
      }
    });
  }
}
