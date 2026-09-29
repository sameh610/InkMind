const fs = require('node:fs');
const data = fs.readFileSync(process.argv[2]);
let offset = 0;
if (data.toString('ascii', 0, 3) === 'ID3') {
  offset = 10 + ((data[6] & 0x7f) << 21) + ((data[7] & 0x7f) << 14) + ((data[8] & 0x7f) << 7) + (data[9] & 0x7f);
}
const mpeg1Layer3 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
const mpeg2Layer3 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
const sampleRates = [44100, 48000, 32000];
let frames = 0;
let duration = 0;
for (; offset + 4 < data.length;) {
  if (data[offset] !== 0xff || (data[offset + 1] & 0xe0) !== 0xe0) { offset++; continue; }
  const version = (data[offset + 1] >> 3) & 3;
  const layer = (data[offset + 1] >> 1) & 3;
  const bitrateIndex = data[offset + 2] >> 4;
  const rateIndex = (data[offset + 2] >> 2) & 3;
  if (version === 1 || layer !== 1 || bitrateIndex === 0 || bitrateIndex === 15 || rateIndex === 3) { offset++; continue; }
  const sampleRate = sampleRates[rateIndex] / (version === 3 ? 1 : version === 2 ? 2 : 4);
  const kbps = (version === 3 ? mpeg1Layer3 : mpeg2Layer3)[bitrateIndex];
  const padding = (data[offset + 2] >> 1) & 1;
  const frameBytes = Math.floor((version === 3 ? 144 : 72) * kbps * 1000 / sampleRate) + padding;
  if (frameBytes < 24 || offset + frameBytes > data.length) { offset++; continue; }
  duration += (version === 3 ? 1152 : 576) / sampleRate;
  frames++;
  offset += frameBytes;
}
console.log(JSON.stringify({ frames, durationSeconds: Number(duration.toFixed(2)), size: data.length }));
