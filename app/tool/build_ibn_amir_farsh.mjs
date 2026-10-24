import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

// Source-first preparation. By default writes a review manifest and audit only.
// No qiraat JSON can be changed while an unresolved source row remains.
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../..');
const report=path.join(root,'reports/ibn_amir_farsh_41_144');
const book=JSON.parse(fs.readFileSync(path.join(report,'decoded_source.json')));
const classification=JSON.parse(fs.readFileSync(path.join(report,'extraction_audit.json'))).rows;
const q=JSON.parse(fs.readFileSync(path.join(root,'app/assets/data/quran.json')));
const data=Object.fromEntries(['hisham','ibn_dhakwan','shubah','warsh'].map(id=>[id,JSON.parse(fs.readFileSync(path.join(root,'app/assets/data/qiraat',id+'.json')))]));
const wordsAt=(s,a)=>q.ayahs.find(r=>r[0]===s&&r[1]===a)[4].split(/\s+/);

export function readingKey(input){
  let s=input.replace(/ٗ/g,'ً').replace(/ٖ/g,'ٍ').replace(/ٞ/g,'ٌ').replace(/ٔ/g,'ء').replace(/[ؤئ]/g,'ء').replace(/([ء-ي])ا([\u064b-\u0651]+)/g,'$1$2ا').replace(/لاَ/g,'لَا').replace(/الأْ/g,'الْأ').replace(/([َ])ي(?=[^ء-ي]*$)/g,'$1ى').replace(/([ا])ْ/g,'$1').replace(/[ـ\s]/g,'').replace(/ے/g,'ي').replace(/ِى/g,'ِي').replace(/ٱ/g,'ا').replace(/ۧ/g,'ي').replace(/ۥ/g,'و').replace(/ۦ/g,'ي').replace(/ۡ/g,'ْ');
  // Quranic hamza seats and superscript long vowels, without changing vowels.
  s=s.replace(/([ىي])ـ?ٔ/g,'ئ').replace(/ؤ/g,'ؤ').replace(/[ىي]ٰ/g,'ا').replace(/اٰ+/g,'ا').replace(/ٰ+/g,'ا').replace(/ى/g,'ا');
  s=s.replace(/َۢ/g,'ً').replace(/ُۢ/g,'ٌ').replace(/ِۢ/g,'ٍ');
  s=s.replace(/[^ء-ي\u064b-\u0652]/g,'');
  return s.replace(/([ء-ي])([\u064b-\u0652]*)/g,(_,c,m)=>c+[...new Set(m)].sort().join(''));
}
const baseKey=s=>readingKey(s).replace(/[\u064b-\u0652]/g,'');
const cleanText=s=>s.replace(/ٰ+/g,'ٰ').replace(/اَ/g,'ا').replace(/([اى])ٰ/g,'$1').replace(/([\u064b-\u0652])\1+/g,'$1').replace(/\s+/g,' ').trim();
const meta=(r,extra={})=>({sourceBook:'ar-qarat-ibn-3amer-new.pdf',sourcePage:r.page,sourceRow:r.id,...extra});
const narrators=m=>m.narrators==='هشام'?['hisham']:m.narrators==='ابن ذكوان'?['ibn_dhakwan']:['hisham','ibn_dhakwan'];

const overridePath=path.join(here,'source/ibn_amir');
const decoderOverrides=JSON.parse(fs.readFileSync(path.join(overridePath,'farsh_decoder_overrides.json')));
const reviewedPath=path.join(overridePath,'farsh_overrides.json');
const reviewedOverrides=fs.existsSync(reviewedPath)?JSON.parse(fs.readFileSync(reviewedPath)):{};
const overrides={...decoderOverrides};for(const [id,v]of Object.entries(reviewedOverrides))overrides[id]={...(overrides[id]??{}),...v};
const distance=(a,b)=>{let p=Array.from({length:b.length+1},(_,i)=>i);for(let i=1;i<=a.length;i++){let n=[i];for(let j=1;j<=b.length;j++)n[j]=Math.min(p[j]+1,n[j-1]+1,p[j-1]+(a[i-1]===b[j-1]?0:1));p=n;}return p[b.length];};
function canonicalAt(id,s,a,w,count,text){
 for(const source of ['shubah','warsh']){const v=data[source].variants.find(v=>v[0]===s&&v[1]===a&&v[2]===w&&v[3]===count&&v[4]&&readingKey(v[4])===readingKey(text));if(v)return{text:v[4].replace(/[۪ٜ]/g,''),from:source};}
 const old=data[id].variants.find(v=>v[0]===s&&v[1]===a&&v[2]===w&&v[3]===count&&v[4]&&readingKey(v[4])===readingKey(text));
 return old?{text:old[4].replace(/[۪ٜ]/g,''),from:'existing-verified-by-pdf'}:{text,from:'reviewed-source'};
}
function reviewedVariants(r,m,byNarrator){
 const variants=[];for(const [id,o]of Object.entries(byNarrator)){
  if(!['hisham','ibn_dhakwan'].includes(id)||o.skip)continue;
  let bases=r.alignment;
  if(o.changes)bases=[bases[0]];
  if(o.ayahs){const original=wordsAt(r.surah,bases[0].ayah)[bases[0].word];bases=o.ayahs.map(a=>({ayah:a,word:wordsAt(r.surah,a).findIndex(t=>baseKey(t)===baseKey(original)),count:bases[0].count}));}
  for(const a of bases){for(const c of o.changes??[o]){
   const ayah=c.ayah??a.ayah,words=wordsAt(r.surah,ayah);let word=c.absoluteWord??c.word??o.word??a.word+(c.wordOffset??o.wordOffset??c.offset??o.offset??0),count=c.count??o.count??a.count;
   let text=c.text??o.text;if(o.transform==='ibrahaam')text=words[word].replace(/هِ[ـۧي]*/,'هَٰ');
   if(o.transform==='ibrahaam-optional'||o.primaryHafs)text=words[word];
   if(!c.wordOffset&&!o.wordOffset&&!c.offset&&!o.offset&&c.word===undefined&&o.word===undefined&&count>1&&text.split(/\s+/).length===1){
    const scores=words.slice(word,word+count).map((t,i)=>({i,d:distance(baseKey(t),baseKey(text))})).sort((a,b)=>a.d-b.d);
    if(scores[0]?.d<scores[1]?.d){word+=scores[0].i;count=1;}
   }
   let tokens=text.split(/\s+/);if(!/سكت/.test(o.description??m.description)&&tokens.length===count&&count>1){
    while(count>1&&readingKey(tokens[0])===readingKey(words[word])){word++;count--;tokens.shift();}
    while(count>1&&readingKey(tokens.at(-1))===readingKey(words[word+count-1])){count--;tokens.pop();}text=tokens.join(' ');
   }
   if(word<0||word+count>words.length)throw new Error('Invalid reviewed source position '+r.id);
   if(!o.wujuh&&!o.omission&&!/سكت/.test(o.description??m.description)&&readingKey(text)===readingKey(words.slice(word,word+count).join(' ')))continue;
   const canonical=canonicalAt(id,r.surah,ayah,word,count,text);
   const row=[r.surah,ayah,word,count,canonical.text,'f',o.description??m.description,'reviewed_farsh',meta(r,{canonicalFrom:canonical.from,...(o.wujuh?{wujuh:o.wujuh}:{}),...(o.primaryHafs?{primaryHafs:true}:{}),...(o.omission?{omission:true}:{})})];
   variants.push({id,row,proof:'reviewed-source-override'});
  }}
 }return variants;
}

const proposed={hisham:[],ibn_dhakwan:[]},audit=[];
const farsh=classification.filter(r=>r.status==='farsh');
for(const m of farsh){
 const rawRow=book.find(r=>r.id===m.id),r={...rawRow,alignment:rawRow.alignment},ids=narrators(m);
 if(!/موضع|مواضع/.test(m.description)){const exact=r.alignment.filter(a=>r.hafsFull.some(t=>readingKey(t)===readingKey(a.hafs)));if(exact.length)r.alignment=exact;}
 const result={id:r.id,page:r.page,surah:r.surah,ayah:r.ayah,description:m.description,narrators:ids,hafs:r.hafsFull,reading:r.readingFull,alignment:r.alignment,status:'ready',variants:[],warnings:[]};
 if(overrides[r.id]){result.variants=reviewedVariants(r,m,overrides[r.id]);result.status='ready';for(const v of result.variants)proposed[v.id].push(v.row);audit.push(result);continue;}
 // A reviewed omission must remove just هو, never the entire source quotation.
 if(r.id===1307){
  const a=24,s=57,w=wordsAt(s,a).findIndex(t=>baseKey(t)==='هو');
  for(const id of ids){let row=[s,a,w,1,'','f','بحذف «هو»','reviewed_farsh',meta(r,{omission:true})];proposed[id].push(row);result.variants.push({id,row});}
  audit.push(result);continue;
 }
 if(r.id===1106){result.status='reclassify-usul';result.warnings.push('صلة/إسكان هاء يرضه: أصل هاء الكناية، وليس فرشًا مستقلاً.');audit.push(result);continue;}
 const multipleWords=r.hafsFull.length>1&&r.hafsFull.length===r.readingFull.length;
 const alternatives=r.hafsFull.length===1&&r.readingFull.length>1;
 if(alternatives){result.status='unresolved';result.warnings.push('بدائل أداء/راويين: يلزم فصل الفرش عن الأصل وربط كل وجه براويه.');audit.push(result);continue;}
 if(r.alignment.some(a=>a.count>1)){result.status='unresolved';result.warnings.push('اقتباس يحوي سياقًا: يجب تقليصه إلى الكلمات المختلفة فعليًا قبل الاستبدال.');audit.push(result);continue;}
 if(!r.alignment.length||r.hafsFull.length>1&&!multipleWords){result.status='unresolved';result.warnings.push('لم تثبت مقابلة سطر القراءة بكلمة الأصل.');audit.push(result);continue;}
 if(/كهشام|كالسابق|كحفص|وجهان|وجه آخر|وجهًا|وجهين/.test(m.description)){result.warnings.push('وصف متعدد الأوجه: يلزم تحرير النص المقدم وأوجهه.');result.status='unresolved';}
 for(const a of r.alignment){
  let index=multipleWords?r.hafsFull.findIndex(t=>readingKey(t)===readingKey(a.hafs)):0;
  if(index<0&&multipleWords)index=r.hafsDecoded.findIndex(t=>baseKey(t)===baseKey(a.decoded));
  if(index<0){result.status='unresolved';result.warnings.push('تعذر ربط أحد الأسطر بالكلمة.');continue;}
  const sourceText=cleanText(r.readingFull[index]);
  if(!sourceText||sourceText.includes('الله')||/ٰٰ/.test(r.readingFull[index])){result.status='unresolved';result.warnings.push('رسم مركب أو علامة صغيرة يحتاج تطبيعًا مستقلًا.');continue;}
  const key=readingKey(sourceText),hf=wordsAt(r.surah,a.ayah)[a.word];
  for(const id of ids){
   let text=sourceText,canonicalFrom=null;
   for(const canonical of ['shubah','warsh']){
    const v=data[canonical].variants.find(v=>v[0]===r.surah&&v[1]===a.ayah&&v[2]===a.word&&v[3]===1&&v[4]&&readingKey(v[4])===key);
    if(v){text=v[4];canonicalFrom=canonical;break;}
   }
   const old=data[id].variants.filter(v=>v[0]===r.surah&&v[1]===a.ayah&&v[2]===a.word);
   const agreement=old.find(v=>v[4]&&readingKey(v[4])===key);
   if(!canonicalFrom&&agreement){text=agreement[4];canonicalFrom='existing-verified-by-pdf';}
   const explicitDifference=readingKey(text)!==readingKey(hf);
   if(!explicitDifference)continue;
   if(!canonicalFrom&&baseKey(sourceText)===baseKey(hf)&&!/[\u064b-\u0652]/.test(sourceText)){result.status='unresolved';result.warnings.push('الرسم بلا حركات لا يثبت الفرق المذكور.');continue;}
   const row=[r.surah,a.ayah,a.word,1,text,'f',m.description,'reviewed_farsh',meta(r,canonicalFrom?{canonicalFrom}:{})];
   result.variants.push({id,row,proof:canonicalFrom??'decoded-pdf-glyphs',existingConflict:old.filter(v=>v[5]==='f'&&readingKey(v[4])!==key).map(v=>v[4])});
  }
 }
 if(result.status==='ready')for(const v of result.variants)proposed[v.id].push(v.row);
 audit.push(result);
}
const summary={sourceRows:farsh.length,ready:audit.filter(r=>r.status==='ready').length,unresolved:audit.filter(r=>r.status==='unresolved').length,reclassifyUsul:audit.filter(r=>r.status==='reclassify-usul').length,variants:Object.fromEntries(Object.entries(proposed).map(([id,v])=>[id,v.length])),canonicalReuses:audit.flatMap(r=>r.variants).filter(v=>['shubah','warsh'].includes(v.row[8].canonicalFrom)).length};
fs.writeFileSync(path.join(report,'farsh_prepared_manifest.json'),JSON.stringify({summary,note:'Prepared candidates only. Unresolved rows are not approved production readings.',variants:proposed,audit},null,2));
console.log(summary);
if(process.argv.includes('--apply'))throw new Error('Apply is intentionally blocked until the source review is complete; review unresolved rows with the root agent.');
