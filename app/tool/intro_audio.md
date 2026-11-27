# The opening's recitation

`assets/audio/intro_yahya.wav`: «يَٰيَحۡيَىٰ خُذِ ٱلۡكِتَٰبَ بِقُوَّةٖۖ» (مريم ١٢)
alone, Muhammad Siddiq al-Minshawi, murattal, from
`https://verse.mp3quran.net/arabic/mohammad_alminshawi/128/019012.mp3`
(the whole ayah; its first part is 0.8–5.5 s, the pause before
«وَءَاتَيۡنَٰهُ» after it). The mujawwad's was too long, about ten seconds
(the user, 2026-11-27).

Made with Node (`npm i mpg123-decoder` beside the scripts):

    node tool/intro_audio/make.mjs 019012.mp3 assets/audio/intro_yahya.wav 0.8 5.5

It cuts the first part, makes it mono, fades it in and out, adds a soft dark
reverb (four damped combs and two allpasses) and three far quiet echoes, and
sets its peak at 45% of full: low, a faint sad echo behind the voice.
