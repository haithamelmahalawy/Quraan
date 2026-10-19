import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../state/reader_settings.dart';
import 'qiraat_sheet.dart';
import 'reader_screen.dart';
import 'scan_screen.dart';
import 'search_screen.dart';
import 'surah_index.dart';
import 'theme.dart';

/// The first screen: where the reader is, open the mushaf or the camera,
/// the surah index, the riwayat, search and settings; a bar of the same at
/// the bottom. Glass cards over a warm glow.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.mushafs,
    required this.variants,
    required this.mutashabihat,
    required this.settings,
  });

  final Mushafs mushafs;
  final VariantRepository variants;
  final MutashabihatRepository mutashabihat;
  final ReaderSettings settings;

  /// The mushaf open: Madinah or Shamarly.
  QuranRepository get quran => mushafs.of(settings.edition);

  Future<void> _openMushaf(BuildContext context, {int? page}) {
    if (page != null) settings.page = page;
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(
          mushafs: mushafs,
          variants: variants,
          mutashabihat: mutashabihat,
          settings: settings,
        ),
      ),
    );
  }

  /// The camera recognises Madinah pages; the page opens in the mushaf open.
  void _openScan(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (scanContext) => ScanScreen(
        quran: mushafs.madani,
        variants: variants,
        mutashabihat: mutashabihat,
        settings: settings,
        onOpen: (page) => _openMushaf(
          scanContext,
          page: mushafs.convert(page, MushafEdition.madani, settings.edition),
        ),
      ),
    ),
  );

  /// Switches the mushaf, at the place read.
  void _toggleEdition() {
    final next = settings.edition == MushafEdition.madani
        ? MushafEdition.shamarly
        : MushafEdition.madani;
    settings.openEdition(
      next,
      mushafs.convert(settings.page, settings.edition, next),
    );
  }

  /// A page chosen on another screen (surah index, search) opens in the
  /// mushaf.
  Future<void> _pick(BuildContext context, Widget screen) async {
    final page = await Navigator.of(context)
        .push<int>(MaterialPageRoute(builder: (_) => screen));
    if (page != null && context.mounted) _openMushaf(context, page: page);
  }

  void _settings(BuildContext context) =>
      QiraatSheet.show(context, settings, variants);

  void _search(BuildContext context) =>
      _pick(context, SearchScreen(quran: quran));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(color: _Look.base),
        child: Stack(
          children: [
            // A warm glow at the top, as in a lit page.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -1.05),
                    radius: 1.1,
                    colors: [_Look.glow, _Look.glow.withAlpha(0)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: ListenableBuilder(
                listenable: settings,
                builder: (context, _) => _content(context),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              child: _BottomBar(
                items: [
                  (Icons.home_rounded, 'الرئيسية', null),
                  (Icons.menu_book_rounded, 'المصحف', () => _openMushaf(context)),
                  (Icons.document_scanner_rounded, 'الكاميرا', () => _openScan(context)),
                  (Icons.search_rounded, 'البحث', () => _search(context)),
                  (Icons.tune_rounded, 'الإعدادات', () => _settings(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final first = quran.page(settings.page).first;
    final surah = quran.surah(first.surah).nameAr;
    final selected = [
      for (final q in qiraat)
        for (final r in q.riwayat)
          if (settings.selected.contains(r.id)) r.nameAr,
    ];
    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.paddingOf(context).bottom + 100),
      children: [
        // The app's icon, and the quick buttons.
        Row(
          children: [
            ClipOval(
              child: Image.asset('assets/images/logo.png', width: 46, height: 46),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'مصحف القراءات',
                style: TextStyle(
                  color: _Look.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
            _RoundButton(
              icon: Icons.search_rounded,
              tooltip: 'البحث',
              onTap: () => _search(context),
            ),
            const SizedBox(width: 10),
            _RoundButton(
              icon: Icons.tune_rounded,
              tooltip: 'الإعدادات',
              onTap: () => _settings(context),
            ),
          ],
        ),
        const SizedBox(height: 34),
        // Where the reader is.
        Text(
          'متابعة القراءة • صفحة ${settings.page}',
          textAlign: TextAlign.center,
          style: TextStyle(color: _Look.muted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _openMushaf(context),
          child: Text(
            'سورة $surah',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Hafs',
              color: _Look.text,
              fontSize: 40,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: _Glass(
            radius: 22,
            onTap: _toggleEdition,
            padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MushafColors.green,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.auto_stories_rounded,
                      size: 15, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  settings.edition.nameAr,
                  style: TextStyle(color: _Look.text, fontWeight: FontWeight.w600),
                ),
                Icon(Icons.swap_horiz_rounded, color: _Look.muted, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        // Open the mushaf, or the camera.
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.menu_book_outlined,
                label: 'المصحف',
                onTap: () => _openMushaf(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: Icons.document_scanner_outlined,
                label: 'الكاميرا',
                onTap: () => _openScan(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Banner(onTap: () => _openScan(context)),
        const SizedBox(height: 16),
        _Glass(
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              _Row(
                icon: Icons.format_list_bulleted_rounded,
                color: const Color(0xFF4CAF50),
                title: 'فهرس السور',
                subtitle: '١١٤ سورة',
                trailing: settings.edition.nameAr,
                onTap: () => _pick(context, SurahIndex(quran: quran)),
              ),
              _Row(
                icon: Icons.layers_rounded,
                color: const Color(0xFFFF8A3D),
                title: 'الروايات',
                subtitle: selected.isEmpty
                    ? 'حفص عن عاصم وحده'
                    : selected.join('، '),
                trailing: '${selected.length} / ١٩',
                onTap: () => _settings(context),
              ),
              _Row(
                icon: Icons.search_rounded,
                color: const Color(0xFFB46CF0),
                title: 'البحث في المصحف',
                subtitle: 'كل مواضع الكلمة أو العبارة',
                onTap: () => _search(context),
              ),
              _Row(
                icon: Icons.tune_rounded,
                color: const Color(0xFFE56BA8),
                title: 'الإعدادات',
                subtitle: 'طريقة العرض، المظهر، التحكم بالعينين',
                onTap: () => _settings(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The start page's colours: dark glass over a warm glow (or light glass
/// over paper in the light theme).
abstract final class _Look {
  static bool get dark => MushafColors.isDark;
  static Color get base => dark ? const Color(0xFF0E0F12) : MushafColors.paper;
  static Color get glow =>
      dark ? const Color(0xFF8A3B12).withAlpha(200) : MushafColors.gold.withAlpha(110);
  static Color get text => dark ? Colors.white : MushafColors.ink;
  static Color get muted => dark ? Colors.white.withAlpha(150) : MushafColors.frame;
  static Color get glass =>
      dark ? Colors.white.withAlpha(20) : Colors.white.withAlpha(150);
  static Color get edge =>
      dark ? Colors.white.withAlpha(28) : Colors.white.withAlpha(220);
}

/// Frosted glass: the background blurred through it, a fine light edge.
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.radius = 20,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.circle = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final shape = circle
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: _Look.glass,
          shape: shape.copyWith(side: BorderSide(color: _Look.edge)),
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: _Glass(
      circle: true,
      onTap: onTap,
      child: SizedBox.square(
        dimension: 44,
        child: Icon(icon, color: _Look.text, size: 22),
      ),
    ),
  );
}

/// A wide button: an icon in a ring, and its name.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Glass(
    radius: 22,
    onTap: onTap,
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _Look.text, width: 1.4),
          ),
          child: Icon(icon, size: 16, color: _Look.text),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: _Look.text,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );
}

/// The camera, as a warm banner: point it at a printed page.
class _Banner extends StatelessWidget {
  const _Banner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [Color(0xFFE8892F), Color(0xFFB44A16)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB44A16).withAlpha(110),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اقرأ الروايات من مصحفك',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'وجّه الكاميرا إلى صفحة من مصحفك الورقي فتظهر بالروايات التي تختارها',
                      style: TextStyle(color: Color(0xFFFFE9D6), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // A raised badge with the camera.
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFD08A), Color(0xFFE0662A)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(70),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.document_scanner_rounded,
                    color: Colors.white, size: 38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A line of the list: a coloured round icon, a title and a note.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(color, Colors.white, 0.25)!, color],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(90),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _Look.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _Look.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                color: _Look.text,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
        ],
      ),
    ),
  );
}

/// The bar at the bottom: the start page and the app's main screens.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.items});

  /// Icon, name, and what it opens (null: this page).
  final List<(IconData, String, VoidCallback?)> items;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 26,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          for (final (icon, label, onTap) in items)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: onTap == null ? _Look.text : _Look.muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              onTap == null ? FontWeight.bold : FontWeight.normal,
                          color: onTap == null ? _Look.text : _Look.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
