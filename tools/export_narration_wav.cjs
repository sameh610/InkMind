const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require('playwright');

const inputPath = path.resolve(process.argv[2] || 'demo/video/public/audio/narration.mp3');
const outputPath = path.resolve(process.argv[3] || 'demo/video/out/narration.wav');
const alignToFilm = process.argv.includes('--film');

(async () => {
  const encoded = fs.readFileSync(inputPath).toString('base64');
  const browser = await chromium.launch({channel: 'msedge', headless: true});
  try {
    const context = await browser.newContext({acceptDownloads: true});
    const page = await context.newPage();
    await page.setContent('<!doctype html><meta charset="utf-8"><title>Audio export</title>');
    const downloadPromise = page.waitForEvent('download');
    const info = await page.evaluate(async (data, align) => {
      const bytes = Uint8Array.from(atob(data), (c) => c.charCodeAt(0));
      const audio = new AudioContext({sampleRate: 44100});
      const decoded = await audio.decodeAudioData(bytes.buffer);
      const channels = Math.min(2, decoded.numberOfChannels);
      const sourceDuration = decoded.duration;
      const length = align ? decoded.sampleRate * 78 : decoded.length;
      const buffer = new ArrayBuffer(44 + length * channels * 2);
      const view = new DataView(buffer);
      const write = (s, p) => { for (let i = 0; i < s.length; i++) view.setUint8(p + i, s.charCodeAt(i)); };
      write('RIFF', 0); view.setUint32(4, 36 + length * channels * 2, true); write('WAVE', 8);
      write('fmt ', 12); view.setUint32(16, 16, true); view.setUint16(20, 1, true);
      view.setUint16(22, channels, true); view.setUint32(24, decoded.sampleRate, true);
      view.setUint32(28, decoded.sampleRate * channels * 2, true); view.setUint16(32, channels * 2, true);
      view.setUint16(34, 16, true); write('data', 36); view.setUint32(40, length * channels * 2, true);
      const tracks = Array.from({length: channels}, (_, channel) => decoded.getChannelData(channel));
      const outputTracks = Array.from({length: channels}, () => new Float32Array(length));
      if (align) {
        const taglineSourceFrame = Math.round((2423 / 30) * decoded.sampleRate);
        const taglineFilmFrame = Math.round(75.1 * decoded.sampleRate);
        for (let channel = 0; channel < channels; channel++) {
          outputTracks[channel].set(tracks[channel].subarray(taglineSourceFrame, taglineSourceFrame + length - taglineFilmFrame), taglineFilmFrame);
        }
      } else {
        for (let channel = 0; channel < channels; channel++) outputTracks[channel].set(tracks[channel]);
      }
      let offset = 44;
      for (let frame = 0; frame < length; frame++) {
        for (let channel = 0; channel < channels; channel++) {
          const sample = Math.max(-1, Math.min(1, outputTracks[channel][frame]));
          view.setInt16(offset, sample < 0 ? sample * 32768 : sample * 32767, true);
          offset += 2;
        }
      }
      const url = URL.createObjectURL(new Blob([buffer], {type: 'audio/wav'}));
      const link = document.createElement('a'); link.href = url; link.download = 'narration.wav';
      document.body.appendChild(link); link.click();
      await audio.close();
      return {sourceDuration, duration: length / decoded.sampleRate, sampleRate: decoded.sampleRate, channels, bytes: buffer.byteLength, filmAligned: align};
    }, encoded, alignToFilm);
    const download = await downloadPromise;
    fs.mkdirSync(path.dirname(outputPath), {recursive: true});
    await download.saveAs(outputPath);
    console.log(JSON.stringify({...info, outputPath}, null, 2));
  } finally {
    await browser.close();
  }
})().catch((error) => { console.error(error); process.exitCode = 1; });
