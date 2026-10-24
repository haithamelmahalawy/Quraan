import fs from'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../../..'),r=JSON.parse(fs.readFileSync(root+'/reports/ibn_amir_farsh_41_144/decoded_source.json')),m=JSON.parse(fs.readFileSync(root+'/reports/ibn_amir_farsh_41_144/extraction_audit.json')).rows,q=JSON.parse(fs.readFileSync(root+'/app/assets/data/quran.json'));const all={};const vowels=/[\u064b-\u0650\u0652\u0656-\u0658\u065e\u06e1]/g;const words=(s,a)=>q.ayahs.find(r=>r[0]===s&&r[1]===a)[4].split(/\s+/);const row=id=>r.find(r=>r.id===id);const info=id=>m.find(r=>r.id===id);const clusters=s=>[...s.matchAll(/([ء-يٱ])([^ء-يٱ]*)/g)].map(m=>[m[1],m[2]]);const edit=(s,at,vowel,shadda)=>{const c=clusters(s),i=at<0?c.length+at:at;c[i][1]=c[i][1].replace(vowels,'')+(shadda===true&&!c[i][1].includes('ّ')?'ّ':'')+vowel;if(shadda===false)c[i][1]=c[i][1].replace(/ّ/g,'');return c.map(c=>c.join('')).join('');};const spelling=(id,off=0,a=row(id).alignment[0])=>words(row(id).surah,a.ayah)[a.word+off];function add(id,text,opts={}){const ids=opts.only??(info(id).narrators==='هشام'?['hisham']:info(id).narrators==='ابن ذكوان'?['ibn_dhakwan']:['hisham','ibn_dhakwan']);all[id]??={};for(const narrator of ids)all[id][narrator]={text,description:info(id).description,...opts};for(const v of Object.values(all[id]))delete v.only;}
// Letters/words shared with Hafs are copied from Hafs, with only the stated change.
add(21,'وَمِيكَٰئِيلَ');
for(const id of[24])add(id,edit(edit(spelling(id),0,'ُ'),2,'ِ'),{count:1});
for(const id of[27,98,707,1060,1147])add(id,edit(spelling(id,1),-1,'َ'),{offset:1,count:1});
for(const id of[29,33,35,37,38,40,41,42,43,44,75,78]){
 const original=spelling(id),changed=original.replace(/هِ[ـۧي]*/,'هَٰ');
 add(id,changed,{only:['hisham'],transform:'ibrahaam'});
 add(id,original,{only:['ibn_dhakwan'],primaryHafs:true,transform:'ibrahaam-optional',wujuh:'الأول كحفص وهو المقدم، والثاني بفتح الهاء وألف بعدها: إبراهام'});
}
add(54,edit(spelling(54,1),-1,'ُ'),{offset:1,count:1});
for(const id of[55,59]){add(id,'',{changes:[{offset:0,count:1,text:edit(spelling(id),-1,'ِ',false)},{offset:1,count:1,text:edit(spelling(id,1),-1,'ُ')}]});}
add(70,spelling(70).replace('ص','س').replace(/ۜ/g,''),{only:['ibn_dhakwan'],wujuh:'الأول بالسين وهو المقدم، والثاني بالصاد كحفص'});
add(135,edit(spelling(135,1),1,'ِ',true),{offset:1,count:1});
add(136,spelling(136),{primaryHafs:true,only:['hisham'],wujuh:'الأول بالتاء كحفص وهو المقدم، والثاني بالياء: يحسبن'});
add(170,spelling(170,1).replace('ت','ي'),{offset:1,count:1});
add(246,edit(spelling(246,1),-1,'ُ'),{offset:1,count:1});
add(267,edit(spelling(267),-2,'ِ',false).replace(/وٓ/g,'و'),{only:['ibn_dhakwan']});add(267,edit(spelling(267),-2,'ِ',false).replace(/وٓ/g,'و'),{only:['hisham'],wujuh:'الأول بتخفيف النون، والثاني بالتشديد كحفص'});
add(283,spelling(283,1).replace(/^ي/,'ت'),{offset:1,count:1});
for(const id of[301,394,396])add(id,spelling(id,1).replace(/^ي/,'ت'),{offset:1,count:1});
add(323,spelling(323,1).replace(/^و[^ء-يٱ]*/,''),{offset:1,count:1});
add(326,'',{changes:[{offset:0,count:1,text:edit(spelling(326),-1,'َ',true)},{offset:1,count:1,text:edit(spelling(326,1),-1,'َ').replace(/^لَّ/,'لَ')}]});
add(364,edit(spelling(364,1),-1,'ِ',true),{offset:1,count:1});
add(385,edit(spelling(385),-1,'ِ',false),{count:1});
for(const id of[390,780,1299])add(id,edit(edit(spelling(id),0,'َ'),2,'ِ'),{count:1});
add(445,edit(spelling(445,1),1,'َ'),{offset:1,count:1});
add(461,edit(spelling(461,1),-1,'ِ',false),{offset:1,count:1});
add(467,edit(spelling(467),-1,'ُ'),{count:1});add(530,edit(spelling(530),-1,'ُ'),{count:1});
add(569,'ٱللَّهُ');
add(576,spelling(576).replace(/ِٔ/,'ِٔي'),{only:['hisham'],wujuh:'الأول بزيادة ياء بعد الهمزة وهو المقدم، والثاني كحفص'});
add(579,spelling(579,1).replace(/^نُ/,'تَ').replace('زِّ','زَّ'),{offset:1,count:1});
add(580,edit(spelling(580),-1,'ُ'));
add(604,spelling(604,1).replace(/^ي/,'ت'),{offset:1,count:1});
add(612,spelling(612).replace('نَجۡ','يَجۡ'),{only:['hisham']});add(612,spelling(612).replace('نَجۡ','يَجۡ'),{only:['ibn_dhakwan'],wujuh:'الأول بالياء وهو المقدم، والثاني بالنون كحفص'});
add(613,edit(edit(spelling(613,1),0,'َ'),1,'َ'),{offset:1,count:1});
add(628,spelling(628,1).replace(/^ي/,'ت'),{offset:1,count:1});add(629,spelling(629).replace(/^ت/,'ي'),{count:1});
add(649,spelling(649).replace(/[ۜۗ]/g,''),{count:1});
add(654,edit(spelling(654,1).replace(/^ي/,'ت'),-1,'ۡ'),{offset:1,count:1});
add(659,spelling(659).replace(/[۟۠]/g,''),{count:1});
add(711,spelling(711).replace(/هِ[ـۧي]*/,'هَٰ'));
for(const id of[746,766])add(id,'قُلۡ',{count:1});
add(756,edit(spelling(756,1).replace(/^ي/,'ت'),0,'ُ').replace('مَ','مِ'),{offset:1,count:1});
add(817,edit(spelling(817),-1,'َ'),{count:1});
add(831,edit(spelling(831),-1,'ُ')+' '+spelling(831,1).replace('لَّ','لَ'),{count:2});
add(874,'',{changes:[{offset:0,count:1,text:spelling(874).replace(/^ي/,'ت')},{absoluteWord:row(874).alignment[1].word,ayah:row(874).alignment[1].ayah,count:1,text:edit(words(26,row(874).alignment[1].ayah)[row(874).alignment[1].word],-1,'ٌ')}]});
add(959,edit(edit(spelling(959),0,'َ'),2,'ُ'),{only:['ibn_dhakwan'],wujuh:'الأول بفتح التاء وضم الراء وهو المقدم، والثاني كحفص'});
add(962,spelling(962),{only:['hisham'],primaryHafs:true,wujuh:'الأول بفتح السين كحفص وهو المقدم، والثاني بإسكانها'});add(962,edit(spelling(962),1,'ۡ'),{only:['ibn_dhakwan']});
add(1053,spelling(1053).replace(/[ۜۗ]/g,''),{count:1});
add(1084,'ٱلۡيَاسَ',{offset:1,count:1,only:['ibn_dhakwan'],wujuh:'وجه بهمزة وصل بدل همزة القطع، ووجه بتحقيقها كحفص'});
add(1085,'',{changes:row(1085).alignment.map((a,i)=>({absoluteWord:a.word,ayah:a.ayah,count:1,text:i===0?'ٱللَّهُ':edit(words(37,a.ayah)[a.word],i===1?1:-1,'ُ',true)}))});
add(1087,'ءَالِ',{count:1});
add(1130,'وَأَن',{count:2});
add(1137,edit(spelling(1137),-1,'ٍ'),{count:1});
add(1167,spelling(1167,1).replace(/^ف[^ء-يٱ]*/,''),{offset:1,count:1});
add(1179,spelling(1179),{only:['hisham'],primaryHafs:true,wujuh:'وجه بتخفيف الميم، ووجه بالتشديد كحفص'});add(1179,edit(spelling(1179),1,'َ',false),{only:['ibn_dhakwan']});
add(1266,edit(spelling(1266,1),1,'َ',true),{offset:1,count:1});
add(1282,'ذَا',{count:1});add(1286,'ذُو',{count:1});
add(1300,'وَكُلٌّ',{count:1});
add(1304,spelling(1304,1).replace(/^ي/,'ت'),{offset:1,count:1});
add(1318,spelling(1318,1),{offset:1,count:1,only:['hisham'],primaryHafs:true,wujuh:'الأول بالتاء وهو المقدم، والثاني بالياء كحفص'});add(1318,spelling(1318,1).replace(/^ي/,'ت'),{offset:1,count:1,only:['ibn_dhakwan']});
add(1325,spelling(1325,1).replace(/هِ[ـۧي]*/,'هَٰ'),{offset:1,count:1});
add(1367,spelling(1367).replace(/^ت/,'ي'),{only:['hisham']});add(1367,spelling(1367).replace(/^ت/,'ي'),{only:['ibn_dhakwan'],wujuh:'الأول بالياء وهو المقدم، والثاني بالتاء كحفص'});
add(1378,edit(spelling(1378),0,'ُ'),{only:['hisham'],wujuh:'الأول بضم اللام وهو المقدم، والثاني بكسرها كحفص'});
add(1389,'إِذَا دَبَرَ',{count:2});
add(1396,spelling(1396).replace(/[ۜۗۡ]/g,'')+' '+edit(spelling(1396,1),0,'َ',true),{count:2});
add(1431,spelling(1431).replace(/[ۜۗۡ]/g,'')+' '+edit(spelling(1431,1),0,'َ',true),{count:2});
add(1448,spelling(1448).replace(/^و[^ء-يٱ]*/,'فَ'),{count:1});

// Reviewed geometry/ligature anomalies, verified against the unchanged Hafs letters.
add(249,edit(spelling(249),-1,'ِ'));
add(373,'بِئۡسٖ');
for(const id of[588,602,606,827])add(id,edit(spelling(id),0,'ِ'));
add(620,'لِيَسُوٓءَ');
add(1055,edit(edit(edit(spelling(1055),0,'ُ'),1,'ۡ'),2,'ً',false));
for(const id of[1066,1292])add(id,edit(spelling(id),1,'ۡ'));
add(1159,'أَعۡجَمِيٌّ');
add(1199,spelling(1199).replace(/^ي/,'ت'));
add(1347,edit(spelling(1347),1,'ُ'));
add(1398,edit(spelling(1398),-2,'ً').replace(/اْ$/,'ا'));
add(1462,spelling(1462).replace(/إِي/,'إِ'));

add(231,spelling(231).replace(/ٰ/g,''));
add(1004,'تُرۡجِئُ');
add(1263,'ذُرِّيَّٰتُهُم',{word:3,count:1});
add(1264,'ذُرِّيَّٰتِهِمۡ',{word:7,count:1});
add(1422,edit(spelling(1422),1,'ِ',false));
fs.writeFileSync(root+'/app/tool/source/ibn_amir/farsh_decoder_overrides.json',JSON.stringify(all,null,2));console.log('overrides',Object.keys(all).length);
