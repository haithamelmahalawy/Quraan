import { MPEGDecoder } from 'mpg123-decoder';
import fs from 'fs';
export function strip(buf) {
  if (buf[0] === 0x49 && buf[1] === 0x44 && buf[2] === 0x33) {
    const size = (buf[6] << 21) | (buf[7] << 14) | (buf[8] << 7) | buf[9];
    buf = buf.subarray(10 + size);
  }
  // to the first frame sync
  let i = 0; while (i < buf.length - 1 && !(buf[i] === 0xff && (buf[i + 1] & 0xe0) === 0xe0)) i++;
  return buf.subarray(i);
}
export async function decode(f) {
  const d = new MPEGDecoder(); await d.ready;
  const r = d.decode(new Uint8Array(strip(fs.readFileSync(f))));
  d.free(); return r;
}
if (process.argv[1].endsWith('env.mjs')) {
  for (const f of process.argv.slice(2)) {
    const { channelData, sampleRate } = await decode(f);
    const x = channelData[0]; const win = Math.round(sampleRate * 0.1);
    let line = '';
    for (let i = 0; i < x.length; i += win) {
      let e = 0; for (let j = i; j < Math.min(i + win, x.length); j++) e += x[j] * x[j];
      const db = 10 * Math.log10(e / win + 1e-12);
      line += db < -45 ? '.' : db < -30 ? '-' : '#';
    }
    console.log(f, sampleRate, channelData.length, (x.length / sampleRate).toFixed(2) + 's');
    console.log(line.replace(/(.{50})/g, '$1\n'));
  }
}
