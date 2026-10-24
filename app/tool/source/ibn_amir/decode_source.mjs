// Reproduce the PDF table glyph decoding and Hafs word alignment.
// Run from a directory containing pdfjs-dist and @napi-rs/canvas, or install them here.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
const require=createRequire(path.join(process.cwd(),'package.json'));
const {DOMMatrix,ImageData,Path2D}=require('@napi-rs/canvas');
Object.assign(globalThis,{DOMMatrix,ImageData,Path2D});
const pdfjs=await import(pathToFileURL(require.resolve('pdfjs-dist/legacy/build/pdf.mjs')).href);
const here=path.dirname(fileURLToPath(import.meta.url));
const [pdfPath,quranPath,outPath]=process.argv.slice(2);
if(!outPath)throw new Error('Usage: node decode_source.mjs <PDF> <quran.json> <output.json>');
const maps=JSON.parse(fs.readFileSync(path.join(here,'legacy_glyph_maps.json')));
const map=maps.letters,mm=maps.marks;
const rows=JSON.parse(fs.readFileSync(path.join(here,'source_table_rows.json')));
const q=JSON.parse(fs.readFileSync(quranPath));
const doc=await pdfjs.getDocument({data:new Uint8Array(fs.readFileSync(pdfPath)),fontExtraProperties:true}).promise;
const widths={};
for(let n=41;n<=144;n++){
 const page=await doc.getPage(n),content=await page.getTextContent();
 const ops=await page.getOperatorList();const names={};
 for(const k of Object.keys(content.styles))names[k]=page.commonObjs.get(k).name.split('+').at(-1);
 let font;for(let i=0;i<ops.fnArray.length;i++){
  if(ops.fnArray[i]===pdfjs.OPS.setFont)font=page.commonObjs.get(ops.argsArray[i][0]);
  if(ops.fnArray[i]===pdfjs.OPS.showText&&font&&/HQPB|aaemala|anabera/.test(font.name))
   for(const g of ops.argsArray[i][0])if(typeof g==='object')widths[font.name.split('+').at(-1)+':'+g.unicode.charCodeAt(0).toString(16)]={width:g.width};
 }
 for(const row of rows.filter(r=>r.page===n)){
  const items=content.items.filter(i=>i.str?.trim()&&i.transform[5]<row.top&&i.transform[5]>row.bottom);
  for(const [name,left,right]of[['hafs',357,433],['reading',125,202]])
   row[name]=items.filter(i=>i.transform[4]>=left&&i.transform[4]<right).map(i=>({s:i.str,f:names[i.fontName],x:i.transform[4],y:i.transform[5],w:i.width}));
 }
}
const letter=(f,c)=>{const cp=c.charCodeAt(0);if(!f.includes('HQPB'))return maps.special[f]?.[cp.toString(16)]??'';if(cp<0xf000)return '';const suffix=(cp-0xf000).toString(16);return map[f+':'+suffix]??map[f.replace(/,Bold$/,'')+',Bold:'+suffix]??'';};
const decodeConsonants=items=>{const lines=[];for(const item of items){let l=lines.find(l=>Math.abs(l.y-item.y)<2);if(!l)lines.push(l={y:item.y,items:[]});l.items.push(item);}return lines.sort((a,b)=>b.y-a.y).map(l=>l.items.sort((a,b)=>b.x-a.x).map(i=>[...i.s].reverse().map(c=>letter(i.f,c)).join('')).join('').replaceAll('االله','الله')).filter(Boolean);};


const unknown={};
function decode(items){const lines=[];for(const i of items){let l=lines.find(l=>Math.abs(l.y-i.y)<2);if(!l)lines.push(l={y:i.y,items:[]});let total=[...i.s].reduce((n,c)=>n+(widths[i.f+':'+c.charCodeAt(0).toString(16)]?.width??1),0);let offset=0;for(const c of i.s){let w=widths[i.f+':'+c.charCodeAt(0).toString(16)]?.width??1;l.items.push({...i,s:c,x:i.x+offset/(total||1)*i.w,w:w/(total||1)*i.w});offset+=w;}}return lines.sort((a,b)=>b.y-a.y).map(l=>{let groups=[];for(const i of l.items){let g=groups.find(g=>Math.abs(i.x-g.x)<.08);if(!g)groups.push(g={x:i.x,items:[]});g.items.push(i);}let out='';let previous=null;for(const g of groups.sort((a,b)=>b.x-a.x)){let bases='',marks='';let baseWidth=0;for(const i of g.items){const c=i.s,b=letter(i.f,c),k=i.f.replace(',Bold','')+':'+c.charCodeAt(0).toString(16);if(b){bases+=b;baseWidth=Math.max(baseWidth,i.w);}else if(k in mm)marks+=mm[k];else if(i.f.includes('HQPB')&&c.charCodeAt(0)>=0xf000)unknown[k]=(unknown[k]??0)+1;}if(bases){if(previous&&previous.x-(g.x+baseWidth)>2.5)out+=' ';out+=bases+marks;previous=g;}else {out+=marks;if(g.items.some(i=>i.w>1))previous=g;}}return out.replace(/االله/g,'الله');});}

const decoded=rows.map(r=>({...r,hafsDecoded:decodeConsonants(r.hafs),readingDecoded:decodeConsonants(r.reading),hafsFull:decode(r.hafs),readingFull:decode(r.reading)}));
const norm=s=>s.replace(/ۧ/g,'ي').replace(/ۨ/g,'ن').replace(/ٔ/g,'ء').replace(/[أإآٱ]/g,'ا').replace(/ى/g,'ي').replace(/[ؤئ]/g,'ء').replace(/[^ء-غف-ي]/g,'');for(const r of decoded){r.matches=[];const ayats=[...r.ayah.matchAll(/\d+/g)].map(m=>+m[0]);for(const ay of q.ayahs.filter(a=>a[0]===r.surah&&ayats.includes(a[1]))){let words=ay[4].split(/\s+/);for(const hf of r.hafsDecoded){const target=norm(hf);for(let w=0;w<words.length;w++){for(let count=1;count<=Math.min(5,words.length-w);count++){let source=words.slice(w,w+count).join(' ');if(target&&norm(source)===target)r.matches.push({ayah:ay[1],word:w,count,hafs:source,decoded:hf});}}}}}
const target=(s,a,w,n=1)=>{let t=q.ayahs.find(r=>r[0]===s&&r[1]===a);let words=t[4].split(/\s+/);if(w<0)w+=words.length;return{ayah:a,word:w,count:n,hafs:words.slice(w,w+n).join(' ')};};let overrides={162:[target(4,49,-1),target(4,50,0)],517:[target(12,8,-1),target(12,9,0)],728:[target(20,30,-1),target(20,31,0)],829:[target(25,8,-1),target(25,9,0)],1066:[{...target(37,17,0),sourcePrefix:'أو'}],1292:[{...target(56,48,0),sourcePrefix:'أو'}]};for(const r of decoded){r.alignment=r.matches.length?r.matches:overrides[r.id]??[];r.alignmentStatus=r.matches.length?'exact-source-consonants':overrides[r.id]?'reviewed-cross-ayah-or-prefix':'reviewed-special-hamza';if([162,517,728,829].includes(r.id))r.crossAyah=true;r.vowelStatus='decoded-glyph-geometry-needs-normalization';}
// Two Hafs-specific special hamza spellings do not normalize as literal seats.
for(const [id,s,a,w]of [[1044,36,19,3],[1159,41,44,7]]){
 const row=decoded.find(r=>r.id===id);
 const ay=q.ayahs.find(r=>r[0]===s&&r[1]===a);
 const words=ay[4].split(/\s+/);
 // Match explicitly by lexical stem to avoid a hard-coded index depending on tokenization.
 const index=words.findIndex(t=>id===1044?t.includes('أَئِن'):t.includes('عۡجَمِي'));
 row.alignment=[{ayah:a,word:index,count:1,hafs:words[index]}];
}
if(decoded.some(r=>!r.alignment.length))throw new Error('Unaligned table rows');
fs.writeFileSync(outPath,JSON.stringify(decoded));
console.log(JSON.stringify({rows:decoded.length,exact:decoded.filter(r=>r.matches.length).length,unknownGlyphs:unknown}));
