import fs from 'fs';
import { decode } from './env.mjs';
const [src, out, from, to] = process.argv.slice(2);
const { channelData, sampleRate: sr } = await decode(src);
const a = Math.round(+from * sr), b = Math.round(+to * sr);
const n = b - a, tail = Math.round(1.0 * sr);
// Mono, the phrase alone.
const dry = new Float32Array(n + tail);
for (let i = 0; i < n; i++) dry[i] = (channelData[0][a + i] + channelData[1][a + i]) / 2;
// Fade in 40ms, fade out the last 600ms of the phrase.
const fin = Math.round(.04 * sr), fout = Math.round(.6 * sr);
for (let i = 0; i < fin; i++) dry[i] *= i / fin;
for (let i = 0; i < fout; i++) dry[n - 1 - i] *= i / fout;
// A soft, dark reverb: four combs then two allpasses (Schroeder), damped.
function comb(x, ms, fb, damp) {
  const d = Math.round(ms * sr / 1000), buf = new Float32Array(d), y = new Float32Array(x.length);
  let k = 0, lp = 0;
  for (let i = 0; i < x.length; i++) {
    const o = buf[k]; lp = o * (1 - damp) + lp * damp; buf[k] = x[i] + lp * fb; y[i] = o; k = (k + 1) % d;
  }
  return y;
}
function allpass(x, ms, g) {
  const d = Math.round(ms * sr / 1000), buf = new Float32Array(d), y = new Float32Array(x.length);
  let k = 0;
  for (let i = 0; i < x.length; i++) { const o = buf[k]; const v = x[i] + o * g; buf[k] = v; y[i] = o - v * g; k = (k + 1) % d; }
  return y;
}
let wet = new Float32Array(dry.length);
for (const [ms, fb] of [[29.7, .84], [37.1, .83], [41.1, .82], [43.7, .81]]) {
  const c = comb(dry, ms, fb, .45); for (let i = 0; i < wet.length; i++) wet[i] += c[i] / 4;
}
wet = allpass(allpass(wet, 5, .7), 1.7, .7);
// Two far echoes, low and quiet: the sad space behind the voice.
const echo = new Float32Array(dry.length);
for (const [s, g] of [[.32, .22], [.64, .12], [.96, .06]]) {
  const d = Math.round(s * sr); for (let i = d; i < echo.length; i++) echo[i] += dry[i - d] * g;
}
const mix = new Float32Array(dry.length);
let peak = 0;
for (let i = 0; i < mix.length; i++) { mix[i] = dry[i] * .8 + wet[i] * .35 + echo[i] * .6; peak = Math.max(peak, Math.abs(mix[i])); }
// Quiet: the peak at 45% of full.
const gain = .45 / peak;
const end = Math.round(.8 * sr);
for (let i = 0; i < end; i++) mix[mix.length - 1 - i] *= i / end;
const pcm = Buffer.alloc(44 + mix.length * 2);
pcm.write('RIFF', 0); pcm.writeUInt32LE(36 + mix.length * 2, 4); pcm.write('WAVE', 8);
pcm.write('fmt ', 12); pcm.writeUInt32LE(16, 16); pcm.writeUInt16LE(1, 20); pcm.writeUInt16LE(1, 22);
pcm.writeUInt32LE(sr, 24); pcm.writeUInt32LE(sr * 2, 28); pcm.writeUInt16LE(2, 32); pcm.writeUInt16LE(16, 34);
pcm.write('data', 36); pcm.writeUInt32LE(mix.length * 2, 40);
for (let i = 0; i < mix.length; i++) pcm.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(mix[i] * gain * 32767))), 44 + i * 2);
fs.writeFileSync(out, pcm);
console.log(out, (mix.length / sr).toFixed(2) + 's', (pcm.length / 1024).toFixed(0) + 'KB');
