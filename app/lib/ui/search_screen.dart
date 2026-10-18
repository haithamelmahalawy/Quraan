import 'dart:async';

import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../data/quran_search.dart';
import 'theme.dart';

/// Search in the Quran: every place a word or phrase occurs, with its surah,
/// ayah and page; pops with the page of the place chosen.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.quran});

  final QuranRepository quran;

  /// Built once: the search index of the whole text.
  static QuranSearch? _index;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _search = SearchScreen._index ??= QuranSearch(widget.quran);
  final _query = TextEditingController();
  Timer? _debounce;
  List<SearchHit> _hits = const [];
  String _searched = '';

  static const _limit = 1000;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _searched = text.trim();
        _hits = _searched.isEmpty
            ? const []
            : _search.search(_searched, limit: _limit);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'ابحث عن كلمة أو عبارة',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 18),
          onChanged: _onChanged,
        ),
        actions: [
          if (_query.text.isNotEmpty)
            IconButton(
              tooltip: 'مسح',
              icon: const Icon(Icons.clear),
              onPressed: () {
                _query.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _searched.isEmpty
          ? const Center(child: Text('اكتب كلمة للبحث في المصحف'))
          : _hits.isEmpty
          ? const Center(child: Text('لا توجد نتائج'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    _hits.length >= _limit
                        ? 'أول $_limit موضع'
                        : 'عدد المواضع: ${_hits.length}',
                    style: TextStyle(color: MushafColors.green),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _hits.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _HitTile(
                      hit: _hits[i],
                      surah: widget.quran.surah(_hits[i].ayah.surah).nameAr,
                      onTap: () => Navigator.of(context).pop(_hits[i].page),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.surah, required this.onTap});

  final SearchHit hit;
  final String surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final words = hit.ayah.words;
    return ListTile(
      onTap: onTap,
      title: Text(
        'سورة $surah • الآية ${hit.ayah.number}',
        style: TextStyle(
          color: MushafColors.green,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      trailing: Text('ص ${hit.page}'),
      subtitle: Text.rich(
        TextSpan(
          children: [
            for (var w = 0; w < words.length; w++)
              TextSpan(
                text: '${words[w]} ',
                style: w >= hit.from && w < hit.to
                    ? TextStyle(
                        color: MushafColors.rose,
                        backgroundColor: MushafColors.rose.withAlpha(30),
                      )
                    : null,
              ),
          ],
        ),
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'Hafs',
          fontSize: 19,
          height: 1.8,
          color: MushafColors.ink,
        ),
      ),
    );
  }
}
