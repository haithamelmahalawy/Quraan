import 'package:flutter/material.dart';

import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../state/reader_settings.dart';
import 'mushaf_decor.dart';
import 'qiraat_sheet.dart';
import 'reader_screen.dart';
import 'scan_screen.dart';
import 'surah_index.dart';
import 'theme.dart';

/// The first screen: open the mushaf, or read the riwayat of a page of a
/// printed mushaf through the camera.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.quran,
    required this.variants,
    required this.mutashabihat,
    required this.settings,
  });

  final QuranRepository quran;
  final VariantRepository variants;
  final MutashabihatRepository mutashabihat;
  final ReaderSettings settings;

  void _openMushaf(BuildContext context, {int? page, bool replace = false}) {
    if (page != null) settings.page = page;
    final route = MaterialPageRoute<void>(
      builder: (_) => ReaderScreen(
        quran: quran,
        variants: variants,
        mutashabihat: mutashabihat,
        settings: settings,
      ),
    );
    final nav = Navigator.of(context);
    replace ? nav.pushReplacement(route) : nav.push(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            final last = quran.page(settings.page).first;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                SizedBox(
                  height: 64,
                  child: SurahBanner(
                    title: 'مصحف القراءات',
                    fontSize: 28,
                    height: 64,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'حفص عن عاصم مع أوجه القراءات العشر',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MushafColors.frame),
                ),
                const SizedBox(height: 28),
                _HomeTile(
                  icon: Icons.menu_book_rounded,
                  title: 'المصحف',
                  subtitle: 'مصحف المدينة برواية حفص، والقراءات في الهامش',
                  color: MushafColors.green,
                  onTap: () => _openMushaf(context),
                ),
                const SizedBox(height: 16),
                _HomeTile(
                  icon: Icons.document_scanner_rounded,
                  title: 'قراءة الروايات من المصحف',
                  subtitle:
                      'وجّه الكاميرا إلى صفحة من مصحفك الورقي فتُفتح بالروايات التي تختارها',
                  color: MushafColors.gold,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (scanContext) => ScanScreen(
                        quran: quran,
                        variants: variants,
                        settings: settings,
                        onOpen: (page) =>
                            _openMushaf(scanContext, page: page, replace: true),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  color: MushafColors.page,
                  child: ListTile(
                    leading: Icon(Icons.bookmark_rounded,
                        color: MushafColors.green),
                    title: const Text('متابعة القراءة'),
                    subtitle: Text(
                        'صفحة ${settings.page} • سورة ${quran.surah(last.surah).nameAr}'),
                    onTap: () => _openMushaf(context),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: MushafColors.page,
                        child: ListTile(
                          leading: Icon(Icons.list_rounded,
                              color: MushafColors.green),
                          title: const Text('فهرس السور'),
                          onTap: () async {
                            final page = await Navigator.of(context).push<int>(
                              MaterialPageRoute(
                                builder: (_) => SurahIndex(quran: quran),
                              ),
                            );
                            if (page != null && context.mounted) {
                              _openMushaf(context, page: page);
                            }
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        color: MushafColors.page,
                        child: ListTile(
                          leading: Icon(Icons.tune_rounded,
                              color: MushafColors.green),
                          title: const Text('الإعدادات'),
                          onTap: () =>
                              QiraatSheet.show(context, settings, variants),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [color.withAlpha(230), color.withAlpha(150)],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(70),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(45),
                ),
                child: Icon(icon, size: 38, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withAlpha(220)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
