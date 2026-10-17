const fs=require("fs");
const [,,id,cat,n="25"]=process.argv;
const q=JSON.parse(fs.readFileSync("assets/data/quran.json"));
const words={};for(const [s,a,,,t] of q.ayahs) words[s+":"+a]=t.split(" ");
const v=JSON.parse(fs.readFileSync(`assets/data/qiraat/${id}.json`)).variants;
const m=new Map();
for(const [s,a,w,c,t,k] of v){ if(cat&&k!==cat)continue; const h=words[s+":"+a].slice(w,w+c).join(" "); const key=h+"  →  "+t; if(!m.has(key))m.set(key,{n:0,at:s+":"+a});m.get(key).n++;}
console.log(id,cat,"distinct",m.size);
for(const [k,x] of [...m].sort((a,b)=>b[1].n-a[1].n).slice(0,+n)) console.log(x.n,x.at,k);
