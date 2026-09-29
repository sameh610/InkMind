const fs = require('node:fs');
const path = require('node:path');

// Original, beat-locked score for the action cut. The musical grid is shared
// with the Remotion edit: 128 BPM, 40 four-beat bars, then a three-second tag.
const rate = 44100;
const launchFile = path.resolve('demo/video/launch-v3-cut.json');
const launch = process.argv.includes('--launch-v3') ? JSON.parse(fs.readFileSync(launchFile,'utf8')) : null;
const frames = launch ? Math.round(launch.duration * 30) : 2340;
const duration = frames / 30;
const length = duration * rate;
const beat = 60 / (launch?.bpm || 128);
const bar = beat * 4;
const logo = launch?.logo || 75;
const musicL = new Float32Array(length);
const musicR = new Float32Array(length);
const fxL = new Float32Array(length);
const fxR = new Float32Array(length);
const note = (midi) => 440 * 2 ** ((midi - 69) / 12);

function noise(seed) {
  let state = (seed | 0) || 1;
  return () => {
    state ^= state << 13; state ^= state >>> 17; state ^= state << 5;
    return state / 2147483648;
  };
}

function add(targetL, targetR, at, seconds, level, pan, voice, pitch = 48) {
  const first = Math.round(at * rate);
  const count = Math.min(length - first, Math.round(seconds * rate));
  if (first < 0 || count <= 0) return;
  const left = Math.cos((pan + 1) * Math.PI / 4);
  const right = Math.sin((pan + 1) * Math.PI / 4);
  const hz = note(pitch);
  const rand = noise(first ^ Math.round(hz * 101) ^ 0x712f);
  let low = 0;
  for (let i = 0; i < count; i++) {
    const t = i / rate;
    const p = t / seconds;
    const white = rand();
    low += (white - low) * 0.048;
    const high = white - low;
    let x = 0;
    if (voice === 'kick') {
      const phase = 2 * Math.PI * (47 * t + 86 * (1 - Math.exp(-38 * t)) / 38);
      x = Math.sin(phase) * Math.exp(-t * 15) + high * 0.10 * Math.exp(-t * 125);
    } else if (voice === 'snare') {
      x = (high * 0.70 + Math.sin(2 * Math.PI * 190 * t) * 0.16) * Math.exp(-t * 25);
    } else if (voice === 'hat') {
      x = high * Math.exp(-t * 63);
    } else if (voice === 'tick') {
      x = (high * 0.32 + Math.sin(2 * Math.PI * 2200 * t) * 0.11) * Math.exp(-t * 82);
    } else if (voice === 'bass') {
      const phase = 2 * Math.PI * hz * t;
      const env = Math.min(1, t * 160) * Math.exp(-t * 3.9);
      x = (Math.sin(phase) + 0.34 * Math.sin(2 * phase) + 0.12 * Math.sin(3 * phase)) * env;
    } else if (voice === 'stab') {
      const phase = 2 * Math.PI * hz * t;
      const env = Math.min(1, t * 120) * Math.exp(-t * 5.4);
      x = (Math.sin(phase) + 0.38 * Math.sin(2.005 * phase) + 0.18 * Math.sin(3.012 * phase)) * env;
    } else if (voice === 'arp') {
      const phase = 2 * Math.PI * hz * t;
      x = (Math.sin(phase) + 0.24 * Math.sin(2.01 * phase) + 0.10 * Math.sin(4.015 * phase)) * Math.exp(-t * 13);
    } else if (voice === 'riser') {
      x = (high * 0.55 + Math.sin(2 * Math.PI * (550 + 750 * p) * t) * 0.10) * p ** 1.6 * Math.min(1, (seconds - t) / 0.04);
    } else if (voice === 'tone') {
      x = (Math.sin(2 * Math.PI * hz * t) + 0.16 * Math.sin(2 * Math.PI * hz * 2.003 * t)) * Math.exp(-t * 1.8);
    }
    targetL[first + i] += x * level * left;
    targetR[first + i] += x * level * right;
  }
}

// Dm – Bb – Gm – A: urgent, warm, and deliberately percussive. The first
// four bars put the selection and activation on a dry pulse; the full groove
// arrives with the first impossible movement. Debug narrows to a rewind pulse,
// and the last montage reaches the score's highest density.
const roots = [38, 34, 31, 33];
const thirds = [3, 4, 3, 4];
function energy(b) {
  if (b < 2) return 0.74;
  if (b < 9) return 1.00;
  if (b < 12) return 0.62;
  if (b < 18) return 0.94;
  if (b < 25) return 1.08;
  if (b < 32) return 1.13;
  if (b < 36) return 0.82;
  return 1.27;
}
for (let b = 0; b < (launch ? 43 : 40); b++) {
  const start = b * bar;
  const root = roots[Math.floor(b / 2) % roots.length];
  const third = thirds[Math.floor(b / 2) % thirds.length];
  const e = energy(b);
  const sparse = b < 2 || (b >= 9 && b < 12);
  for (let j = 0; j < 8; j++) {
    const at = start + j * beat / 2;
    const accent = j % 2 === 0 ? 1 : 0.75;
    add(musicL, musicR, at, 0.11, (sparse ? 0.050 : 0.067) * e * accent, j % 2 ? 0.32 : -0.32, sparse ? 'tick' : 'hat');
    if (b >= 25 && b < 32 && j % 2) add(musicL, musicR, at + beat / 4, 0.09, 0.025 * e, -0.19, 'hat');
    if (b >= 36 && j % 2) add(musicL, musicR, at + beat / 4, 0.08, 0.034 * e, 0.30, 'hat');
  }
  for (let j = 0; j < 4; j++) {
    const at = start + j * beat;
    if (j === 0 || j === 2 || (b >= 18 && j === 3)) {
      add(musicL, musicR, at, 0.38, (sparse ? 0.20 : 0.28) * e, 0, 'kick');
    }
    if (!sparse && (j === 1 || j === 3)) {
      add(musicL, musicR, at, 0.24, 0.14 * e, 0.05, 'snare');
    }
    const bassNote = root - 12 + (j === 3 ? 7 : 0);
    if (!(b >= 9 && b < 12 && j % 2)) {
      add(musicL, musicR, at, beat * 0.90, 0.18 * e, -0.04, 'bass', bassNote);
    }
    if (b >= 2 && b < 36 && (j === 0 || j === 2)) {
      const chord = [root + 24, root + third + 24, root + 31];
      chord.forEach((pitch, k) => add(musicL, musicR, at + (j === 2 ? beat / 4 : 0), 0.39, (sparse ? 0.026 : 0.047) * e, (k - 1) * 0.35, 'stab', pitch));
    }
  }
  if (b >= 18 && b < (launch ? 43 : 36)) {
    const steps = [0, 7, 12, 7, third, 12, 7, third];
    for (let j = 0; j < 8; j++) add(musicL, musicR, start + j * beat / 2, 0.19, 0.040 * e, j % 2 ? 0.28 : -0.28, 'arp', root + 36 + steps[j]);
  }
  if ([1, 8, 11, 17, 24, 31, 35, 38].includes(b)) {
    add(musicL, musicR, start + bar - 0.47, 0.44, 0.080 * e, b % 2 ? -0.22 : 0.22, 'riser');
  }
}

// Stop the sequencer at 75 seconds. Keep the logo impact short and leave
// enough space for the recorded final brand line if it is retained.
add(musicL, musicR, logo, 0.84, 0.29, 0, 'kick');
for (const [interval, pan] of [[0, -0.24], [3, 0.16], [7, 0.29], [12, -0.05]]) {
  add(musicL, musicR, logo, 2.6, 0.066, pan, 'tone', 50 + interval);
}

const defaultCues = [
  {at: 0.00, kind: 'pen'}, {at: 0.94, kind: 'select'},
  {at: 2.34, kind: 'click'}, {at: 3.75, kind: 'activate'},
  {at: 8.91, kind: 'lift'}, {at: 12.66, kind: 'drop'},
  {at: 17.81, kind: 'click'}, {at: 20.63, kind: 'rewind'},
  {at: 23.44, kind: 'stop'}, {at: 25.31, kind: 'branch'},
  {at: 33.75, kind: 'click'}, {at: 35.16, kind: 'unfold'},
  {at: 38.44, kind: 'slider'}, {at: 39.38, kind: 'slider'},
  {at: 40.31, kind: 'slider'}, {at: 44.06, kind: 'unfold'},
  {at: 48.75, kind: 'lift'}, {at: 59.06, kind: 'click'},
  {at: 70.31, kind: 'impact'}, {at: 75.00, kind: 'logo'},
];
const cuePath = path.resolve('demo/video/action-cues.json');
const cues = fs.existsSync(cuePath) ? JSON.parse(fs.readFileSync(cuePath, 'utf8')) : defaultCues;
const effectLength = {pen: 0.15, select: 0.25, click: 0.15, activate: 0.54, lift: 0.40, drop: 0.72, gravity: 0.58, air: 0.46, rewind: 0.93, stop: 0.31, branch: 0.62, unfold: 0.86, slider: 0.13, impact: 0.72, logo: 1.68};
function effect(cue) {
  const seconds = effectLength[cue.kind] || 0.22;
  const first = Math.round(cue.at * rate);
  const count = Math.min(length - first, Math.round(seconds * rate));
  if (first < 0 || count <= 0) return;
  const random = noise(first ^ 0x24efa);
  let low = 0;
  for (let i = 0; i < count; i++) {
    const t = i / rate, p = t / seconds;
    const white = random();
    low += (white - low) * 0.04;
    const high = white - low;
    let x = 0;
    if (cue.kind === 'pen' || cue.kind === 'select') x = (high * 0.34 + Math.sin(2 * Math.PI * 1030 * t) * 0.11) * Math.exp(-t * (cue.kind === 'pen' ? 55 : 19));
    if (cue.kind === 'click' || cue.kind === 'slider' || cue.kind === 'stop') x = (high * 0.38 + Math.sin(2 * Math.PI * 950 * t) * 0.22) * Math.exp(-t * (cue.kind === 'stop' ? 27 : 48));
    if (cue.kind === 'activate') x = (Math.sin(2 * Math.PI * (680 + 880 * p) * t) * 0.23 + high * 0.26) * Math.exp(-t * 9) + Math.sin(2 * Math.PI * (60 + 75 * Math.exp(-t * 25)) * t) * 0.25 * Math.exp(-t * 12);
    if (cue.kind === 'lift') x = (high * 0.18 + Math.sin(2 * Math.PI * (390 + 650 * p) * t) * 0.12) * Math.sin(Math.PI * p);
    if (cue.kind === 'air') x = (high * 0.28 + Math.sin(2 * Math.PI * (340 + 520 * p) * t) * 0.06) * Math.sin(Math.PI * p) ** 1.3;
    if (cue.kind === 'drop' || cue.kind === 'impact' || cue.kind === 'logo') x = Math.sin(2 * Math.PI * (52 + 80 * Math.exp(-t * 30)) * t) * 0.35 * Math.exp(-t * (cue.kind === 'logo' ? 4 : 8)) + high * 0.30 * Math.exp(-t * 29);
    if (cue.kind === 'gravity') x = (Math.sin(2 * Math.PI * (165 - 120 * p) * t) * 0.19 + low * 0.08) * Math.sin(Math.PI * p) ** 0.9;
    if (cue.kind === 'rewind') x = (high * 0.24 + Math.sin(2 * Math.PI * (1630 - 1190 * p) * t) * 0.14) * Math.min(1, p * 2.8) * (1 - p ** 3);
    if (cue.kind === 'branch' || cue.kind === 'unfold') x = (high * 0.18 + Math.sin(2 * Math.PI * (450 + 850 * p) * t) * 0.20) * Math.sin(Math.PI * p) ** 0.65;
    const power = cue.power ?? 1;
    fxL[first + i] += x * power * 0.98;
    fxR[first + i] += x * power * 1.02;
  }
}
cues.forEach(effect);

function writeWav(filename, left, right, targetPeak, isMusic) {
  let peak = 0, sum = 0;
  for (let i = 0; i < length; i++) {
    const t = i / rate;
    let fade = Math.min(1, t / 0.015) * Math.min(1, (duration - t) / 0.06);
    if (isMusic) {
      if (t >= logo) fade *= 0.70;
      for (const cue of cues) {
        const delta = t - cue.at;
        if (delta >= 0 && delta < 0.20) fade *= 1 - 0.11 * Math.exp(-delta * 18);
      }
    }
    left[i] *= fade; right[i] *= fade;
    peak = Math.max(peak, Math.abs(left[i]), Math.abs(right[i]));
    sum += left[i] * left[i] + right[i] * right[i];
  }
  const gain = peak ? targetPeak / peak : 1;
  const output = Buffer.allocUnsafe(44 + length * 4);
  output.write('RIFF', 0); output.writeUInt32LE(output.length - 8, 4);
  output.write('WAVEfmt ', 8); output.writeUInt32LE(16, 16);
  output.writeUInt16LE(1, 20); output.writeUInt16LE(2, 22);
  output.writeUInt32LE(rate, 24); output.writeUInt32LE(rate * 4, 28);
  output.writeUInt16LE(4, 32); output.writeUInt16LE(16, 34);
  output.write('data', 36); output.writeUInt32LE(length * 4, 40);
  let offset = 44;
  for (let i = 0; i < length; i++) {
    output.writeInt16LE(Math.round(Math.max(-1, Math.min(1, left[i] * gain)) * 32767), offset); offset += 2;
    output.writeInt16LE(Math.round(Math.max(-1, Math.min(1, right[i] * gain)) * 32767), offset); offset += 2;
  }
  const target = path.resolve('demo/video/public/audio', filename);
  fs.writeFileSync(target, output);
  console.log(JSON.stringify({target, duration, peak: targetPeak, rms: Math.sqrt(sum / (length * 2)) * gain, bytes: output.length}));
}

writeWav(launch ? 'inkmind-score-v3-local.wav' : 'inkmind-score-action.wav', musicL, musicR, 0.72, true);
writeWav(launch ? 'sound-design-v3.wav' : 'sound-design-action.wav', fxL, fxR, 0.46, false);
fs.writeFileSync(path.resolve('demo/video', launch ? 'beat-markers-v3.json' : 'beat-markers.json'), JSON.stringify({bpm: launch?.bpm || 128, beatSeconds: beat, duration, downbeats: Array.from({length: launch ? 44 : 41}, (_, i) => Number((i * bar).toFixed(5)))}, null, 2) + '\n');
