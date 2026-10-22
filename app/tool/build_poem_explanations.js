// Classical, public-domain commentary by Abu Shama (d. 665 AH).
// Rebuild: node tool/build_poem_explanations.js [download-cache-directory]
// Uses the printed-book transcription, not generated interpretations.
const fs = require('fs');
const path = require('path');
const os = require('os');
const base = 'https://quranpedia.app/books/b5486/';
const cache = process.argv[2] || path.join(os.tmpdir(), 'quraan-abushama');
const root = path.resolve(__dirname, '..');
const poems = JSON.parse(fs.readFileSync(path.join(root, 'assets/data/manzumat.json'), 'utf8'));
const plain = s => s.replace(/<[^>]*>/g, '').replace(/&nbsp;|&#160;/g, ' ')
  .replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/\s+/g, ' ').trim();
const letters = s => plain(s).normalize('NFC').replace(/[أإآٱ]/g, 'ا')
  .replace(/ى/g, 'ي').replace(/ـ/g, '').replace(/[^ء-ي]/g, '');
const grams = s => new Set(Array.from({ length: Math.max(0, s.length - 2) }, (_, i) => s.slice(i, i + 3)));
const corpus = poems.shatibiyya.map(v => ({ n: v[0], grams: grams(letters(v[2] + v[3])) }));
function match(text) {
  const g = grams(letters(text));
  if (g.size < 20) return null;
  let best = null, score = .64;
  for (const v of corpus) {
    let common = 0;
    for (const x of g) if (v.grams.has(x)) common++;
    const s = 2 * common / (g.size + v.grams.size);
    if (s > score) { best = v.n; score = s; }
  }
  return best;
}
(async () => {
  fs.mkdirSync(cache, { recursive: true });
  const blocks = [];
  for (let s = 1; s <= 63; s++) {
    const file = path.join(cache, `s${s}.html`);
    if (!fs.existsSync(file)) {
      const r = await fetch(`${base}s${s}.html`);
      if (!r.ok) throw new Error(`${s}: ${r.status}`);
      fs.writeFileSync(file, await r.text());
    }
    const html = fs.readFileSync(file, 'utf8');
    for (const a of html.matchAll(/<article class="bk-page"[^>]*data-loc="([^"]+)"[^>]*>([\s\S]*?)<\/article>/g)) {
      const body = /<div class="bk-text">([\s\S]*?)<\/div>/.exec(a[2]);
      if (!body) continue;
      for (const p of body[1].matchAll(/<(p|h2)\b[^>]*>([\s\S]*?)<\/\1>/g)) {
        blocks.push({ text: plain(p[2]), heading: p[1] === 'h2', url: `${base}s${s}.html`, page: a[1] });
      }
    }
  }
  const out = {};
  let current = null;
  for (let i = 0; i < blocks.length; i++) {
    const b = blocks[i];
    if (b.heading) { current = null; continue; }
    const marker = /^(\d+)\s*[-–]\s*(.*)$/.exec(b.text);
    if (marker) {
      // A marker always ends the preceding explanation, even if its quote
      // cannot be matched. Edition numbers occasionally repeat or differ.
      const previous = current;
      current = null;
      let quote = marker[2] || blocks[++i]?.text || '';
      let n = match(quote);
      // In one place the two hemistichs occupy separate paragraphs.
      if (!n && blocks[i + 1] && !blocks[i + 1].heading &&
          !/^\d+\s*[-–]/.test(blocks[i + 1].text)) {
        n = match(quote + ' ' + blocks[i + 1].text);
        if (n) i++;
      }
      if (n && !out[n]) {
        const verse = poems.shatibiyya.find(v => v[0] === n);
        const full = letters(verse[2] + verse[3]);
        const next = blocks[i + 1];
        if (next && !next.heading && letters(next.text).length >= 8 &&
            full.includes(letters(next.text))) i++;
        current = previous && !previous.text.length ? previous :
          { text: [], url: b.url, page: b.page, group: [] };
        current.group.push(n);
        out[n] = current;
      }
      continue;
    }
    if (current && b.text) current.text.push(b.text);
  }
  const entries = Object.entries(out).filter(([n, v]) => Number(n) !== 377 && v.text.length)
    .map(([n, v]) => [Number(n), v.text.join('\n\n'), v.url, v.page, v.group]);
  // The first transcription omits printed pp. 274–281. Fill just those
  // nine bayts and the interrupted preceding explanation from another
  // transcription of the same classical work,
  // validating the quoted verse text instead of trusting its number alone.
  const supplementUrl = 'https://www.islamicbook.ws/qbook/alom/ibraz-almaani-003.html';
  const supplementFile = path.join(cache, 'supplement.html');
  if (!fs.existsSync(supplementFile)) {
    const r = await fetch(supplementUrl);
    if (!r.ok) throw new Error(`Supplement: ${r.status}`);
    fs.writeFileSync(supplementFile, await r.text());
  }
  const supplement = fs.readFileSync(supplementFile, 'utf8');
  for (const m of supplement.matchAll(/\((\d{3})\)<br\s*\/>([\s\S]*?)(?=<br\s*\/>\(\d{3}\)|$)/g)) {
    const n = Number(m[1]);
    if (n < 377 || n > 386) continue;
    const start = m[2].search(/<p>|<br\s*\/>/);
    if (start < 0 || match(m[2].slice(0, start)) !== n) throw new Error(`Unverified supplement ${n}`);
    const text = m[2].slice(start).split(/<p>|<br\s*\/>/).map(plain).filter(Boolean)
      .join('\n\n').replace(/\n\nباب[^\n]*$/, '');
    entries.push([n, text, supplementUrl, `شرح البيت ${n}`, [n],
      'إبراز المعاني من حرز الأماني — أبو شامة المقدسي (ت ٦٦٥ هـ)، عبر المكتبة الإسلامية islamicbook.ws']);
  }
  entries.sort((a, b) => a[0] - b[0]);
  if (entries.length !== 1173 || new Set(entries.map(e => e[0])).size !== 1173)
    throw new Error('The complete commentary must cover all 1173 bayts exactly once.');
  const result = {
    source: 'إبراز المعاني من حرز الأماني — أبو شامة المقدسي (ت ٦٦٥ هـ)، نسخة المكتبة الشاملة، عبر الموسوعة القرآنية الشاملة quranpedia.app',
    url: base + 'index.html',
    shatibiyya: entries,
  };
  fs.writeFileSync(path.join(root, 'assets/data/poem_explanations.json'), JSON.stringify(result));
  const missing = corpus.filter(v => !entries.some(e => e[0] === v.n)).map(v => v.n);
  console.log(`Commentaries: ${entries.length}; missing: ${missing.join(', ')}`);
})();
