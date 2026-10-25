# Audio verse numbering

Boundary data: Quran.ws, https://github.com/quran-ws/qiraat-ayah-map
Revision: a9b4d345f3e1d0e9282711c5e09f24119b17e4e1
Copyright 2026 Quran.ws. Data licensed CC BY 4.0:
https://creativecommons.org/licenses/by/4.0/
See LICENSE for the author's licensing policy and product attribution waiver.
The two JSON source files are unmodified. The app asset adds the Hafs verse
and word counts, the word index of each internal boundary, and source metadata;
regenerate with:

    dart run tool/build_audio_numbering.dart

Use the counting system of the recording, not that of a printed edition.
Quranpedia's verse recordings use their reciter's associated counting system
(confirmed at the Baqarah endpoint for representatives of each system).
Fatiha's uncounted basmala is recording 001000 for the non-Kufan/non-Makkan
systems. A native recording can cover multiple displayed verses, or a displayed
verse can require multiple native recordings. No sub-verse timestamps are
available: playback therefore preserves whole native clips and reports their
displayed verse range rather than pretending to seek to an exact sub-verse.

The displayed narration's counting system supplies its verse markers and the
word span selected by a tap/hold. That span is mapped independently to the
listened narration. Internal boundaries prefer exact bare spelling before
looser Uthmani alignment (كثير is distinct from كثيرا). In 7:38, النار means
the second occurrence, after عذابا ضعفا من النار. Regression tests compare
all native Warsh verse spans with KFGQPC's original warshData_v10.json.

The `makki-6220` profile adds the end after قريبا (78:40). The KFGQPC Bazzi
text and Quranpedia recording 268 count it; recording 269 (Qunbul) uses the
6219 profile instead. On 2026-10-25, 268/078041.mp3 returned 200 and
268/078042.mp3 returned 404; 269/078040.mp3 returned 200 and 269/078041.mp3
returned 404 at https://files.quranpedia.net/recitations/.
`reciters.json` records the override on recitation 268, and
`tool/build_tafsir.dart` preserves it when rebuilding the catalogue.
