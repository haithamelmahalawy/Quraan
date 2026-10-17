import 'package:flutter/material.dart';

import '../data/quran_repository.dart';

/// Surah list; pops with the selected surah's start page.
class SurahIndex extends StatelessWidget {
  const SurahIndex({super.key, required this.quran});

  final QuranRepository quran;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فهرس السور')),
      body: ListView.builder(
        itemCount: quran.surahs.length,
        itemBuilder: (context, i) {
          final s = quran.surahs[i];
          return ListTile(
            leading: CircleAvatar(child: Text('${s.number}')),
            title: Text(
              'سورة ${s.nameAr}',
              style: const TextStyle(fontFamily: 'Hafs', fontSize: 20),
            ),
            subtitle: Text('${s.nameEn} • ${s.ayahCount} آية'),
            trailing: Text('ص ${s.startPage}'),
            onTap: () => Navigator.of(context).pop(s.startPage),
          );
        },
      ),
    );
  }
}
