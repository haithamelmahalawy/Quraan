import Flutter
import UIKit
import SwiftyTesseract

// Local changes (qiraat_mushaf):
// - SwiftyTesseract reads its models from `tessdata` at the root of the app
//   bundle; the app's "Copy Tesseract data" build phase puts them there. The
//   original tried to symlink into the (read-only) bundle at run time, which
//   fails on devices, and SwiftyTesseract then stops the app (fatalError)
//   when it cannot initialise. The model is now checked first.
// - Every call answers: an empty text when the image or the model is missing
//   or recognition fails, instead of never returning.
public class SwiftFlutterTesseractOcrPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_tesseract_ocr", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterTesseractOcrPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "extractText" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard let params = call.arguments as? [String: Any],
              let imagePath = params["imagePath"] as? String,
              let image = UIImage(contentsOfFile: imagePath) else {
            result("")
            return
        }
        let language = (params["language"] as? String) ?? "eng"

        // Without the model SwiftyTesseract would terminate the app.
        let model = Bundle.main.bundleURL
            .appendingPathComponent("tessdata")
            .appendingPathComponent("\(language).traineddata")
        guard FileManager.default.fileExists(atPath: model.path) else {
            print("flutter_tesseract_ocr: missing \(model.path)")
            result("")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let swiftyTesseract = SwiftyTesseract(language: .custom(language))
            swiftyTesseract.performOCR(on: image) { recognizedString in
                DispatchQueue.main.async {
                    result(recognizedString ?? "")
                }
            }
        }
    }
}
