const fs = require('node:fs');

const captions = JSON.parse(fs.readFileSync('demo/video/src/captions.json', 'utf8'));
const stamp = (ms) => {
  const value = Math.round(ms);
  const hours = Math.floor(value / 3_600_000);
  const minutes = Math.floor((value % 3_600_000) / 60_000);
  const seconds = Math.floor((value % 60_000) / 1_000);
  const millis = value % 1_000;
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')},${String(millis).padStart(3, '0')}`;
};

const output = captions.map((item, i) => `${i + 1}\n${stamp(item.startMs)} --> ${stamp(item.endMs)}\n${item.text}`).join('\n\n') + '\n';
fs.mkdirSync('demo/video/out', {recursive: true});
fs.writeFileSync('demo/video/out/inkmind-launch-trailer.srt', output, 'utf8');
console.log(`Wrote ${captions.length} caption cues to demo/video/out/inkmind-launch-trailer.srt`);
