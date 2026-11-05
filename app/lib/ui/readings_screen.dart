import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../data/tafsir_repository.dart';
import '../services/audio_library.dart' show DownloadStatus;
import '../services/reading_downloads.dart';
import 'reading_library_screen.dart';

/// All that is read beside the Quran: each book to open, and those read online
/// to keep on the device, as the recitations are in «المسموعات».
class ReadingsScreen extends StatefulWidget {
  const ReadingsScreen({
    super.key,
    required this.quran,
    this.downloads,
    this.tafsir,
  });

  final QuranRepository quran;

  /// For tests; the app's own otherwise.
  final ReadingDownloads? downloads;
  final TafsirRepository? tafsir;

  @override
  State<ReadingsScreen> createState() => _ReadingsScreenState();
}

class _ReadingsScreenState extends State<ReadingsScreen> {
  late final ReadingDownloads _downloads =
      widget.downloads ?? ReadingDownloads.instance;
  late final TafsirRepository _tafsir =
      widget.tafsir ?? TafsirRepository(local: _downloads.lookup);
  late final List<int> _counts = [
    for (final s in widget.quran.surahs) s.ayahCount,
  ];

  static const _sections = [
    ('التفسير', TafsirRepository.books),
    ('الإعراب', TafsirRepository.e3rabBooks),
    ('توجيه القراءات', TafsirRepository.tawjihBooks),
    ('الوقف والابتداء', TafsirRepository.waqfBooks),
  ];

  @override
  void initState() {
    super.initState();
    for (final (_, books) in _sections) {
      for (final book in books) {
        if (!book.offline) _downloads.load(book.id, _counts);
      }
    }
  }

  static String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} ك.ب'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} م.ب';

  Widget _action(TafsirBook book, BookDownload d) {
    if (book.offline) {
      return const Tooltip(
        message: 'في التطبيق، يُقرأ دون إنترنت',
        child: Icon(Icons.offline_pin_rounded, color: Color(0xFF2F785C)),
      );
    }
    return switch (d.status) {
      DownloadStatus.downloading => IconButton(
        key: ValueKey('reading-pause-${book.id}'),
        tooltip: 'إيقاف مؤقت',
        icon: const Icon(Icons.pause_rounded),
        onPressed: () => _downloads.pause(book.id),
      ),
      DownloadStatus.complete => IconButton(
        key: ValueKey('reading-delete-${book.id}'),
        tooltip: 'حذف من الجهاز',
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: () => _downloads.delete(book.id, _counts),
      ),
      _ => IconButton(
        key: ValueKey('reading-download-${book.id}'),
        tooltip: d.done > 0 ? 'إكمال التحميل' : 'تحميل للقراءة دون إنترنت',
        icon: const Icon(Icons.download_rounded),
        onPressed: () => _downloads.download(book.id, _counts),
      ),
    };
  }

  String _state(TafsirBook book, BookDownload d) {
    if (book.offline) return '${book.author} • في التطبيق';
    final percent = (d.progress * 100).toStringAsFixed(0);
    return switch (d.status) {
      DownloadStatus.notStarted => '${book.author} • من الإنترنت',
      DownloadStatus.downloading => '${book.author} • جارٍ التحميل $percent٪',
      DownloadStatus.paused =>
        '${book.author} • متوقف عند $percent٪ (${_size(d.bytes)})',
      DownloadStatus.complete =>
        '${book.author} • على الجهاز (${_size(d.bytes)})',
    };
  }

  Widget _book(TafsirBook book) {
    final d = _downloads.statusOf(book.id);
    return Card(
      key: ValueKey('reading-book-${book.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(book.name),
            subtitle: Text(_state(book, d)),
            trailing: _action(book, d),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => BookReaderScreen(
                  book: book,
                  quran: widget.quran,
                  tafsir: _tafsir,
                ),
              ),
            ),
          ),
          if (d.status == DownloadStatus.downloading ||
              d.status == DownloadStatus.paused && d.done > 0)
            LinearProgressIndicator(value: d.progress),
          if (d.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Text(
                d.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المقروءات')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: _downloads,
        builder: (context, _) => ListView(
          key: const ValueKey('readings-list'),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'كل كتاب يمكن قراءته من هنا. وما يُقرأ من الإنترنت يمكن تحميله '
              'لقراءته بعد ذلك دون اتصال، وقد تبلغ الكتب الطويلة عشرات '
              'الميجابايت.',
            ),
            for (final (title, books) in _sections) ...[
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              for (final book in books) _book(book),
            ],
            const SizedBox(height: 16),
            Text(
              'المتون والمصادر',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Card(
              child: ListTile(
                key: const ValueKey('readings-texts'),
                title: const Text('المتون ومصادر القراءات'),
                subtitle: const Text(
                  'الشاطبية، الدرة، التسهيل لقراءات التنزيل • في التطبيق',
                ),
                trailing: const Icon(
                  Icons.offline_pin_rounded,
                  color: Color(0xFF2F785C),
                ),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ReadingLibraryScreen(quran: widget.quran),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A book read surah by surah: its text of each ayah, once where it gives one
/// text to several together.
class BookReaderScreen extends StatefulWidget {
  const BookReaderScreen({
    super.key,
    required this.book,
    required this.quran,
    required this.tafsir,
  });

  final TafsirBook book;
  final QuranRepository quran;
  final TafsirRepository tafsir;

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  int _surah = 1;

  Future<(String?, bool)> _ayah(int ayah) async {
    final text = await widget.tafsir.text(widget.book, _surah, ayah);
    if (ayah == 1 || text == null) return (text, false);
    final before = await widget.tafsir.text(widget.book, _surah, ayah - 1);
    return (text, text == before);
  }

  @override
  Widget build(BuildContext context) {
    final surah = widget.quran.surah(_surah);
    return Scaffold(
      appBar: AppBar(title: Text(widget.book.name)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButton<int>(
                key: const ValueKey('reading-surah'),
                isExpanded: true,
                value: _surah,
                items: [
                  for (final s in widget.quran.surahs)
                    DropdownMenuItem(value: s.number, child: Text(s.nameAr)),
                ],
                onChanged: (s) => setState(() => _surah = s ?? 1),
              ),
            ),
            Expanded(
              child: ListView.builder(
                key: ValueKey('reading-ayahs-$_surah'),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: surah.ayahCount,
                itemBuilder: (context, i) => FutureBuilder<(String?, bool)>(
                  key: ValueKey('reading-$_surah-${i + 1}'),
                  future: _ayah(i + 1),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'الآية ${i + 1}: تعذر التحميل، تحقق من الاتصال '
                          'أو حمّل الكتاب.',
                        ),
                      );
                    }
                    final data = snapshot.data;
                    if (data == null) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final (text, same) = data;
                    if (text == null || same) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الآية ${i + 1}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            text,
                            style: const TextStyle(fontSize: 17, height: 1.7),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
