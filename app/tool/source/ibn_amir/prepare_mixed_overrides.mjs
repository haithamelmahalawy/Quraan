// Explicitly reviewed mixed lexical/performance rows. Only source manifests
// are written here; the farsh builder aligns them against the Hafs word spans.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const dir=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(dir,'../../..');
const q=JSON.parse(fs.readFileSync(path.join(root,'assets/data/quran.json')));
const source=JSON.parse(fs.readFileSync(path.join(root,'../reports/ibn_amir_farsh_41_144/decoded_source.json')));
const out={};
const row=id=>source.find(r=>r.id===id);
const hf=(s,a,w)=>q.ayahs.find(r=>r[0]===s&&r[1]===a)[4].split(' ')[w];
function put(n,id,text,description,extra={}) {
  (out[n]??={})[id]={text,description,...extra};
}
function both(n,text,description,extra={}) {
  for(const id of ['hisham','ibn_dhakwan']) put(n,id,text,description,extra);
}
for(const n of [343,352]) {
  const a=row(n).alignment[0];
  both(n,'ءَ'+hf(row(n).surah,a.ayah,a.word),'بزيادة همزة استفهام');
}
for(const n of [350,853]) {
  put(n,'hisham','أَرۡجِئۡهُۥ','بزيادة همزة ساكنة بعد الجيم؛ وحكم الهاء في الأصول');
  put(n,'ibn_dhakwan','أَرۡجِئۡهِ','بزيادة همزة ساكنة بعد الجيم؛ وحكم الهاء في الأصول');
}
both(392,'تَتَوَفَّى','بالتاء بدل الياء',{wordOffset:1,count:1});
for(const n of [515,547,709,922,1081]) {
  const r=row(n),a=r.alignment[0];
  both(n,hf(r.surah,a.ayah,a.word).replace('تِ','تَ'),'بفتح تاء يا أبت وصلاً',
    n===709?{ayahs:[42,43,44,45]}:{});
}
// The table omits Hisham's second Shatibiyya face. Verified against the
// author's الوافي في شرح الشاطبية, باب فرش سورة هود/يوسف, bayt 777.
put(525,'hisham','هِئۡتَ','بكسر الهاء وهمزة ساكنة بدل الياء',{
  wujuh:'فتح التاء: «هِئْتَ»، وضمها: «هِئْتُ»',
  correctionSource:'https://quranpedia.app/books/b38075/s24.html',
});
put(525,'ibn_dhakwan','هِيتَ','بكسر الهاء ثم ياء ساكنة وفتح التاء');
put(677,'hisham','تَسۡـَٔلَنِّي','بفتح اللام وتشديد النون');
put(677,'ibn_dhakwan','تَسۡـَٔلَنِّ','بفتح اللام وتشديد النون؛ وحذف الياء في الزوائد');
const r715=row(715),a715=r715.alignment[0];
put(715,'ibn_dhakwan',hf(19,66,a715.word),'وجهان في همزة الاستفهام',{
  wujuh:'تحقيق همزة الاستفهام كحفص وهو المقدّم، وحذفها: «إِذَا»',
});
put(737,'hisham','تَلَقَّفۡ','بفتح اللام وتشديد القاف');
put(737,'ibn_dhakwan','تَلَقَّفُ','بفتح اللام وتشديد القاف وضم الفاء');
put(902,'hisham','يَذَّكَّرُونَ','بالياء وتشديد الذال');
put(902,'ibn_dhakwan','تَذَّكَّرُونَ','بتشديد الذال');
both(1019,'صَدَقَ','بتخفيف الدال',{wordOffset:1,count:1});
both(1180,'جَآءَانَا','بإثبات ألف بعد الهمزة');
both(1226,'ءَأَذۡهَبۡتُمۡ','بزيادة همزة استفهام؛ وأداء الهمزتين في الأصول');
put(1265,'hisham','ٱلۡمُسَيۡطِرُونَ','بالسين بدل الصاد');
const r1265=row(1265),a1265=r1265.alignment[0];
put(1265,'ibn_dhakwan',hf(52,37,a1265.word),'بالصاد كحفص');
both(1361,'ءَأَن','بزيادة همزة استفهام؛ وأداء الهمزتين في الأصول');
put(1368,'hisham','يَذَّكَّرُونَ','بالياء وتشديد الذال');
put(1368,'ibn_dhakwan','يَذَّكَّرُونَ','بالياء وتشديد الذال',{
  wujuh:'بالياء وتشديد الذال وهو المقدّم، وبالتاء وتشديد الذال: «تَذَّكَّرُونَ»',
});
fs.writeFileSync(path.join(dir,'farsh_overrides.json'),JSON.stringify(out,null,2));
console.log(`Prepared ${Object.keys(out).length} mixed source overrides.`);
