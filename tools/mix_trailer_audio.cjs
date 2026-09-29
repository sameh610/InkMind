const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve('demo/video');
const readPcm = (file) => {
  const bytes = fs.readFileSync(file);
  if (bytes.toString('ascii', 0, 4) !== 'RIFF' || bytes.toString('ascii', 8, 12) !== 'WAVE' || bytes.readUInt16LE(20) !== 1 || bytes.readUInt16LE(34) !== 16) {
    throw new Error(`Expected 16-bit PCM WAV: ${file}`);
  }
  const channels = bytes.readUInt16LE(22);
  const rate = bytes.readUInt32LE(24);
  const frames = bytes.readUInt32LE(40) / (channels * 2);
  return {bytes, channels, rate, frames, sample: (frame, channel) => bytes.readInt16LE(44 + (frame * channels + Math.min(channel, channels - 1)) * 2) / 32768};
};

const score = readPcm(path.join(root, 'public/audio/inkmind-score-action.wav'));
const effects = readPcm(path.join(root, 'public/audio/sound-design-action.wav'));
const voice = readPcm(path.join(root, 'out/narration-film.wav'));
const filmFrames = 2340;
const samplesPerFrame = 1470; // 44.1 kHz / 30 fps.
const frameCount = filmFrames * samplesPerFrame;
for (const [name, track] of [['score', score], ['effects', effects], ['voice', voice]]) {
  if (track.rate !== 44100 || track.frames !== frameCount) throw new Error(`${name} does not match the 78-second film.`);
}

const clamp01 = (x) => Math.max(0, Math.min(1, x));
const lerp = (a, b, t) => a + (b - a) * t;
const voiceStartFrame = 2253; // 75.1 seconds.
const musicVolume = (frame) => {
  const duck = lerp(0.92, 0.23, clamp01((frame - (voiceStartFrame - 8)) / 14));
  const fade = lerp(1, 0, clamp01((frame - (filmFrames - 12)) / 12));
  return duck * fade;
};

const mixed = new Float32Array(frameCount * 2);
let peak = 0;
for (let i = 0; i < frameCount; i++) {
  const filmFrame = Math.floor(i / samplesPerFrame);
  const music = musicVolume(filmFrame);
  for (let channel = 0; channel < 2; channel++) {
    const sample = score.sample(i, channel) * music + effects.sample(i, channel) * 0.72 + voice.sample(i, 0);
    mixed[i * 2 + channel] = sample;
    peak = Math.max(peak, Math.abs(sample));
  }
}

const gain = Math.min(1, 0.96 / (peak || 1));
const dataBytes = frameCount * 4;
const output = Buffer.allocUnsafe(44 + dataBytes);
output.write('RIFF', 0); output.writeUInt32LE(36 + dataBytes, 4); output.write('WAVE', 8);
output.write('fmt ', 12); output.writeUInt32LE(16, 16); output.writeUInt16LE(1, 20);
output.writeUInt16LE(2, 22); output.writeUInt32LE(44100, 24); output.writeUInt32LE(44100 * 4, 28);
output.writeUInt16LE(4, 32); output.writeUInt16LE(16, 34); output.write('data', 36); output.writeUInt32LE(dataBytes, 40);
for (let i = 0; i < mixed.length; i++) output.writeInt16LE(Math.round(Math.max(-1, Math.min(1, mixed[i] * gain)) * 32767), 44 + i * 2);
const file = path.join(root, 'out/inkmind-launch-trailer-mix.wav');
fs.writeFileSync(file, output);
console.log(JSON.stringify({file, seconds: frameCount / 44100, peakBeforeMasterGain: peak, masterGain: gain, bytes: output.length}, null, 2));
