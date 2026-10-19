import 'package:flutter/material.dart';

import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../state/reader_settings.dart';
import 'qiraat_sheet.dart';
import 'raised.dart';
import 'reader_screen.dart';
import 'scan_screen.dart';
import 'search_screen.dart';
import 'surah_index.dart';
import 'theme.dart';

/// The first screen: open the mushaf, read the riwayat of a page of a
/// printed mushaf through the camera, search, and the settings.
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

  Future<void> _openMushaf(BuildContext context, {int? page}) {
    if (page != null) settings.page = page;
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(
          quran: quran,
          variants: variants,
          mutashabihat: mutashabihat,
          settings: settings,
        ),
      ),
    );
  }

  void _openScan(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (scanContext) => ScanScreen(
        quran: quran,
        variants: variants,
        mutashabihat: mutashabihat,
        settings: settings,
        onOpen: (page) => _openMushaf(scanContext, page: page),
      ),
    ),
  );

  /// A page chosen on another screen (surah index, search) opens in the
  /// mushaf.
  Future<void> _pick(BuildContext context, Widget screen) async {
    final page = await Navigator.of(context)
        .push<int>(MaterialPageRoute(builder: (_) => screen));
    if (page != null && context.mounted) _openMushaf(context, page: page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MushafColors.paper,
              Color.lerp(MushafColors.paper, MushafColors.gold, 0.12)!,
            ],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) {
              final last = quran.page(settings.page).first;
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                children: [
                  const _Header(),
                  const SizedBox(height: 22),
                  _HeroTile(
                    icon: Icons.menu_book_rounded,
                    title: 'المصحف',
                    subtitle: 'مصحف المدينة برواية حفص، والقراءات في الهامش',
                    color: MushafColors.green,
                    onTap: () => _openMushaf(context),
                  ),
                  const SizedBox(height: 16),
                  _HeroTile(
                    icon: Icons.document_scanner_rounded,
                    title: 'قراءة الروايات بالكاميرا',
                    subtitle: 'وجّه الكاميرا إلى صفحة من مصحفك الورقي فتظهر بالروايات التي تختارها',
                    color: MushafColors.gold,
                    onTap: () => _openScan(context),
                  ),
                  const SizedBox(height: 18),
                  Raised(
                    onTap: () => _openMushaf(context),
                    tooltip: 'متابعة القراءة',
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        _Badge(
                          icon: Icons.bookmark_rounded,
                          color: MushafColors.green,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'متابعة القراءة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: MushafColors.ink,
                                ),
                              ),
                              Text(
                                'صفحة ${settings.page} • سورة ${quran.surah(last.surah).nameAr}',
                                style: TextStyle(color: MushafColors.frame),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_left_rounded,
                          color: MushafColors.green,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _SquareTile(
                          icon: Icons.format_list_bulleted_rounded,
                          label: 'فهرس السور',
                          onTap: () => _pick(context, SurahIndex(quran: quran)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SquareTile(
                          icon: Icons.search_rounded,
                          label: 'البحث',
                          onTap: () =>
                              _pick(context, SearchScreen(quran: quran)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SquareTile(
                          icon: Icons.tune_rounded,
                          label: 'الإعدادات',
                          onTap: () =>
                              QiraatSheet.show(context, settings, variants),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The app's name under its icon, «خُذِ ٱلۡكِتَٰبَ بِقُوَّةٖ».
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Raised(
      color: MushafColors.green,
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/logo.png',
                width: 76,
                height: 76,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مصحف القراءات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'حفص عن عاصم مع أوجه القراءات العشر',
                  style: TextStyle(color: Color(0xFFF3E6BC)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({
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
    return Raised(
      color: color,
      radius: 26,
      depth: 1.3,
      tooltip: title,
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _Badge(icon: icon, color: color, size: 64, light: true),
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
                  style: TextStyle(color: Colors.white.withAlpha(225)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareTile extends StatelessWidget {
  const _SquareTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Raised(
      tooltip: label,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          _Badge(icon: icon, color: MushafColors.green),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: MushafColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// An icon on a small raised disc.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.color,
    this.size = 46,
    this.light = false,
  });

  final IconData icon;
  final Color color;
  final double size;

  /// On a coloured tile: a pale disc with the icon in white.
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Raised(
      circle: true,
      depth: 0.5,
      color: light ? Color.lerp(color, Colors.white, 0.18) : MushafColors.page,
      child: SizedBox.square(
        dimension: size,
        child: Icon(
          icon,
          size: size * 0.55,
          color: light ? Colors.white : color,
        ),
      ),
    );
  }
}
