const fs = require('node:fs');
const path = require('node:path');

// One audio sample boundary per video frame: 2483 frames at 30 fps = 82.7667 s.
// Forty 116 BPM bars end eight milliseconds before the picture, so the final
// cadence lands on the logo and the tail fades cleanly with the last frame.
const sampleRate = 44100;
const videoFrames = 2483;
const samplesPerVideoFrame = sampleRate / 30;
const samples = videoFrames * samplesPerVideoFrame;
const duration = samples / sampleRate;
const beat = 60 / 116;
const barLength = beat * 4;
const rootMidi = [38, 34, 41, 36]; // Dm, Bb, F, C
const chordSteps = [[0, 3, 7, 12], [0, 4, 7, 12], [0, 4, 7, 12], [0, 4, 7, 12]];
const midiFrequency = (pitch) => 440 * 2 ** ((pitch - 69) / 12);

const musicLeft = new Float32Array(samples);
const musicRight = new Float32Array(samples);
const effectsLeft = new Float32Array(samples);
const effectsRight = new Float32Array(samples);

const sceneHits = [0, 2.07, 4.14, 10.34, 14.48, 20.69, 26.90, 37.24, 43.45, 60, 68.28, 76.55];
const sectionEnergy = (bar) => {
  if (bar < 2) return 0.45; // ink and the first impossible movement
  if (bar < 10) return 0.86; // Animate Ink and Moon
  if (bar < 13) return 0.46; // reasoning rewinds
  if (bar < 18) return 0.82; // corrected branch grows
  if (bar < 29) return 1.00; // graph opens up
  if (bar < 33) return 0.66; // cool, tight local-AI bridge
  if (bar < 37) return 1.12; // final montage
  return 0.57; // logo and voice tag
};

const seededNoise = (seed) => {
  let state = seed | 0;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return state / 2147483648;
  };
};

function addMusic({at, length, voice, pitch = 60, level = 0.1, pan = 0}) {
  const start = Math.max(0, Math.floor(at * sampleRate));
  const count = Math.min(samples - start, Math.floor(length * sampleRate));
  if (count <= 0) return;
  const frequency = midiFrequency(pitch);
  const leftPan = Math.cos((pan + 1) * Math.PI / 4);
  const rightPan = Math.sin((pan + 1) * Math.PI / 4);
  const noise = seededNoise((start ^ Math.round(frequency * 17) ^ 0x5a31) | 0);
  let lowpass = 0;
  for (let i = 0; i < count; i++) {
    const t = i / sampleRate;
    const remaining = (count - i) / sampleRate;
    const phase = 2 * Math.PI * frequency * t;
    const white = noise();
    lowpass += (white - lowpass) * 0.11;
    let value = 0;
    if (voice === 'pad') {
      const envelope = Math.min(1, t / 0.24) * Math.min(1, remaining / 0.45) * Math.exp(-t * 0.16);
      value = (Math.sin(phase) + 0.25 * Math.sin(phase * 2.003 + 0.17) + 0.11 * Math.sin(phase * 0.503 + 0.8)) * envelope;
    } else if (voice === 'piano') {
      const envelope = (1 - Math.exp(-t * 110)) * Math.exp(-t * 2.3) * Math.min(1, remaining / 0.08);
      value = (Math.sin(phase) + 0.33 * Math.sin(phase * 2.006) + 0.12 * Math.sin(phase * 4.01)) * envelope;
    } else if (voice === 'pluck') {
      const envelope = (1 - Math.exp(-t * 180)) * Math.exp(-t * 9.5) * Math.min(1, remaining / 0.025);
      value = (Math.sin(phase) + 0.26 * Math.sin(phase * 2.01 + 0.2) + 0.07 * Math.sin(phase * 3.97)) * envelope;
    } else if (voice === 'bass') {
      const envelope = (1 - Math.exp(-t * 62)) * Math.exp(-t * 2.7) * Math.min(1, remaining / 0.07);
      value = (Math.sin(phase) + 0.24 * Math.sin(phase * 2.006) + 0.06 * Math.sin(phase * 3)) * envelope;
    } else if (voice === 'kick') {
      const sweptPhase = 2 * Math.PI * (48 * t + 96 * (1 - Math.exp(-34 * t)) / 34);
      value = Math.sin(sweptPhase) * Math.exp(-t * 18) + 0.16 * white * Math.exp(-t * 195);
    } else if (voice === 'snare') {
      const envelope = Math.exp(-t * 22) + 0.36 * Math.exp(-Math.abs(t - 0.018) * 80);
      value = ((white - lowpass) * 0.78 + 0.16 * Math.sin(2 * Math.PI * 176 * t)) * envelope;
    } else if (voice === 'hat') {
      value = (white - lowpass) * Math.exp(-t * 72);
    } else if (voice === 'riser') {
      const progress = t / length;
      value = (white - lowpass) * Math.pow(progress, 1.8) * Math.min(1, remaining / 0.04) * 0.55;
    }
    const amplitude = value * level;
    musicLeft[start + i] += amplitude * leftPan;
    musicRight[start + i] += amplitude * rightPan;
  }
}

// Original score: four-bar harmonic motion, tactile eighth-note detail, a
// restrained InkDebug breakdown, and a wider graph/recap section. The cuts at
// 2.07, 20.69, 37.24, 68.28, and 76.55 all land on bar downbeats.
for (let bar = 0; bar < 37; bar++) {
  const barAt = bar * barLength;
  const chordIndex = Math.floor(bar / 2) % 4;
  const root = rootMidi[chordIndex];
  const tones = chordSteps[chordIndex];
  const energy = sectionEnergy(bar);
  if (bar % 2 === 0) {
    for (let i = 0; i < 3; i++) {
      addMusic({at: barAt, length: barLength * 2.05, voice: 'pad', pitch: root + 12 + tones[i], level: (0.067 - i * 0.006) * energy, pan: [-0.28, 0.05, 0.28][i]});
    }
  }
  if (bar === 0 || bar === 10 || bar === 18 || bar === 29 || bar === 33) {
    addMusic({at: barAt, length: 0.58, voice: 'kick', level: 0.19 * energy});
    addMusic({at: barAt, length: 1.1, voice: 'bass', pitch: root - 12, level: 0.15 * energy});
  }
  for (let step = 0; step < 4; step++) {
    const at = barAt + step * beat;
    const beatPitch = root + 24 + tones[[0, 2, 1, 3][step]];
    if (bar < 2) {
      addMusic({at: at + beat * 0.52, length: 0.25, voice: 'pluck', pitch: beatPitch, level: 0.055, pan: step % 2 ? 0.26 : -0.26});
      continue;
    }
    const breakdown = bar >= 10 && bar < 13;
    const bridge = bar >= 29 && bar < 33;
    const kickLevel = (breakdown ? 0.10 : bridge ? 0.17 : 0.25) * energy;
    if (!breakdown || step % 2 === 0) addMusic({at, length: 0.32, voice: 'kick', level: kickLevel});
    if (step === 2 && !breakdown) addMusic({at, length: 0.25, voice: 'snare', level: 0.108 * energy, pan: 0.08});
    if (step === 0 || step === 2 || (bar >= 18 && !bridge)) {
      addMusic({at: at + 0.015, length: 0.48, voice: 'bass', pitch: root - 12 + (step === 3 ? 7 : 0), level: 0.18 * energy});
    }
    addMusic({at: at + beat * 0.5, length: 0.19, voice: 'hat', level: (bridge ? 0.038 : 0.052) * energy, pan: step % 2 ? 0.40 : -0.40});
    addMusic({at: at + beat * 0.50, length: 0.33, voice: 'pluck', pitch: beatPitch, level: (breakdown ? 0.043 : 0.072) * energy, pan: step % 2 ? 0.30 : -0.30});
    if (bar >= 18 && bar < 29 && step % 2 === 1) {
      addMusic({at: at + beat * 0.75, length: 0.18, voice: 'pluck', pitch: beatPitch + 12, level: 0.027 * energy, pan: -0.22});
    }
  }
  if ([9, 12, 17, 28, 32, 36].includes(bar)) {
    addMusic({at: barAt + barLength - 0.58, length: 0.56, voice: 'riser', level: 0.065 * energy, pan: bar % 2 ? 0.35 : -0.35});
  }
}

// A strong logo chord breathes beneath the only spoken line, then resolves.
const logoAt = 37 * barLength;
for (const [offset, level, pan] of [[0, 0.080, -0.20], [3, 0.068, 0.08], [7, 0.065, 0.27], [12, 0.052, -0.10]]) {
  addMusic({at: logoAt, length: duration - logoAt, voice: 'pad', pitch: 50 + offset, level, pan});
}
addMusic({at: logoAt, length: 0.9, voice: 'kick', level: 0.34});
addMusic({at: logoAt, length: 2.1, voice: 'bass', pitch: 26, level: 0.19});
addMusic({at: logoAt + beat * 0.15, length: 1.9, voice: 'piano', pitch: 74, level: 0.12, pan: -0.20});
addMusic({at: logoAt + beat * 1.2, length: 1.4, voice: 'piano', pitch: 77, level: 0.075, pan: 0.22});
addMusic({at: logoAt + barLength * 2, length: 1.8, voice: 'piano', pitch: 62, level: 0.055, pan: 0.05});

const effectEvents = [
  {at: 0.00, kind: 'pen', power: 0.75},
  {at: 0.52, kind: 'lift', power: 0.52},
  {at: 2.07, kind: 'hit', power: 0.87},
  {at: 4.14, kind: 'snap', power: 0.72},
  {at: 6.20, kind: 'glide', power: 0.40},
  {at: 10.34, kind: 'lift', power: 0.70},
  {at: 14.48, kind: 'drop', power: 1.00},
  {at: 20.69, kind: 'rewind', power: 0.95},
  {at: 26.90, kind: 'branch', power: 0.86},
  {at: 37.24, kind: 'unfold', power: 1.00},
  {at: 43.45, kind: 'snap', power: 0.68},
  {at: 47.59, kind: 'snap', power: 0.42},
  {at: 60.00, kind: 'pulse', power: 0.70},
  {at: 68.28, kind: 'hit', power: 0.72},
  {at: 70.34, kind: 'snap', power: 0.46},
  {at: 72.41, kind: 'snap', power: 0.46},
  {at: 74.48, kind: 'snap', power: 0.46},
  {at: 76.55, kind: 'logo', power: 1.10},
];

const effectLengths = {pen: 0.16, lift: 0.52, hit: 0.70, snap: 0.22, glide: 0.43, drop: 0.82, rewind: 0.78, branch: 0.91, unfold: 1.12, pulse: 0.66, logo: 2.25};

function addEffect({at, kind, power}) {
  const length = effectLengths[kind];
  const lead = kind === 'rewind' ? 0.62 : kind === 'unfold' ? 0.12 : 0;
  const start = Math.max(0, Math.floor((at - lead) * sampleRate));
  const count = Math.min(samples - start, Math.floor(length * sampleRate));
  if (count <= 0) return;
  const noise = seededNoise((start ^ Math.round(power * 41000) ^ 0x19af) | 0);
  let lowpass = 0;
  for (let i = 0; i < count; i++) {
    const t = i / sampleRate;
    const progress = t / length;
    const white = noise();
    lowpass += (white - lowpass) * 0.065;
    const hiss = white - lowpass;
    const sub = Math.sin(2 * Math.PI * (78 * t + 47 * (1 - Math.exp(-18 * t)) / 18));
    let value = 0;
    if (kind === 'pen') {
      value = 0.32 * hiss * Math.exp(-t * 62) + 0.20 * Math.sin(2 * Math.PI * 1360 * t) * Math.exp(-t * 96);
    } else if (kind === 'lift' || kind === 'glide') {
      const envelope = Math.sin(Math.PI * progress) ** 1.3;
      value = 0.22 * hiss * envelope + 0.085 * Math.sin(2 * Math.PI * (500 + 450 * progress) * t) * envelope;
    } else if (kind === 'hit' || kind === 'drop' || kind === 'logo') {
      const low = kind === 'logo' ? 0.38 : kind === 'drop' ? 0.32 : 0.27;
      value = low * sub * Math.exp(-t * (kind === 'logo' ? 3.8 : 8.5)) + 0.23 * hiss * Math.exp(-t * 21);
      if (kind === 'logo') {
        value += 0.11 * Math.sin(2 * Math.PI * (690 + 175 * progress) * t) * Math.exp(-t * 2.4);
      }
    } else if (kind === 'snap') {
      value = 0.24 * hiss * Math.exp(-t * 35) + 0.13 * Math.sin(2 * Math.PI * 980 * t) * Math.exp(-t * 32);
    } else if (kind === 'rewind') {
      const crescendo = Math.min(1, progress / 0.78) ** 1.8;
      value = 0.19 * hiss * crescendo + 0.10 * Math.sin(2 * Math.PI * (1550 - 1080 * progress) * t) * crescendo;
      if (progress > 0.78) value += 0.26 * sub * Math.exp(-(progress - 0.78) * 35);
    } else if (kind === 'branch' || kind === 'unfold') {
      const shimmer = Math.sin(2 * Math.PI * (590 + 690 * progress) * t);
      const release = Math.sin(Math.PI * Math.min(1, progress)) ** 0.7;
      value = 0.19 * shimmer * Math.exp(-t * 4.1) + 0.16 * hiss * release;
      if (kind === 'unfold') value += 0.13 * sub * Math.exp(-t * 12);
    } else if (kind === 'pulse') {
      value = 0.18 * Math.sin(2 * Math.PI * (210 + 360 * progress) * t) * Math.exp(-t * 6) + 0.11 * hiss * Math.exp(-t * 12);
    }
    const amplitude = value * power;
    effectsLeft[start + i] += amplitude * 0.95;
    effectsRight[start + i] += amplitude * 1.04;
  }
}

for (const event of effectEvents) addEffect(event);

function writeStereoWav(left, right, targetPeak, outputPath, isMusic) {
  // Leave space for the other stem and for the short recorded sign-off. Light
  // ducking around the principal impacts keeps clicks, drops and rewinds crisp.
  let peak = 0;
  let totalSquare = 0;
  for (let i = 0; i < samples; i++) {
    const t = i / sampleRate;
    let fade = 1;
    if (isMusic) {
      fade = Math.min(1, t / 0.055) * Math.min(1, (duration - t) / 1.25);
      for (const hit of sceneHits) {
        const delta = t - hit;
        if (delta >= 0 && delta < 0.30) fade *= 1 - 0.18 * Math.exp(-delta * 15);
      }
    } else {
      fade = Math.min(1, (duration - t) / 0.18);
    }
    left[i] *= fade;
    right[i] *= fade;
    peak = Math.max(peak, Math.abs(left[i]), Math.abs(right[i]));
    totalSquare += left[i] ** 2 + right[i] ** 2;
  }
  const gain = peak > 0 ? targetPeak / peak : 1;
  const output = Buffer.allocUnsafe(44 + samples * 4);
  output.write('RIFF', 0);
  output.writeUInt32LE(output.length - 8, 4);
  output.write('WAVE', 8);
  output.write('fmt ', 12);
  output.writeUInt32LE(16, 16);
  output.writeUInt16LE(1, 20);
  output.writeUInt16LE(2, 22);
  output.writeUInt32LE(sampleRate, 24);
  output.writeUInt32LE(sampleRate * 4, 28);
  output.writeUInt16LE(4, 32);
  output.writeUInt16LE(16, 34);
  output.write('data', 36);
  output.writeUInt32LE(samples * 4, 40);
  let at = 44;
  for (let i = 0; i < samples; i++) {
    output.writeInt16LE(Math.round(Math.max(-1, Math.min(1, left[i] * gain)) * 32767), at); at += 2;
    output.writeInt16LE(Math.round(Math.max(-1, Math.min(1, right[i] * gain)) * 32767), at); at += 2;
  }
  fs.mkdirSync(path.dirname(outputPath), {recursive: true});
  fs.writeFileSync(outputPath, output);
  console.log(JSON.stringify({file: outputPath, seconds: duration, sampleRate, frames: samples, peak: Number(targetPeak.toFixed(3)), rms: Number((Math.sqrt(totalSquare / (samples * 2)) * gain).toFixed(4)), bytes: output.length}));
}

const audioDir = path.resolve('demo/video/public/audio');
writeStereoWav(musicLeft, musicRight, 0.76, path.join(audioDir, 'inkmind-score.wav'), true);
writeStereoWav(effectsLeft, effectsRight, 0.48, path.join(audioDir, 'sound-design.wav'), false);
