const fs = require('node:fs');
const { chromium } = require('playwright');

const audioPath = process.argv[2] || 'demo/video/public/audio/narration.mp3';

(async () => {
  const bytes = fs.readFileSync(audioPath);
  const encoded = bytes.toString('base64');
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  try {
    const page = await browser.newPage();
    const activity = await page.evaluate(async (data) => {
      const context = new OfflineAudioContext(1, 1, 48000);
      const raw = Uint8Array.from(atob(data), (character) => character.charCodeAt(0));
      const buffer = await context.decodeAudioData(raw.buffer);
      const samples = buffer.getChannelData(0);
      const windowSize = Math.floor(buffer.sampleRate * 0.05);
      const windows = [];
      for (let start = 0; start < samples.length; start += windowSize) {
        const end = Math.min(samples.length, start + windowSize);
        let sum = 0;
        for (let i = start; i < end; i++) sum += samples[i] * samples[i];
        windows.push(Math.sqrt(sum / (end - start)));
      }
      const threshold = Math.max(0.0015, Math.max(...windows) * 0.035);
      const spans = [];
      let start = -1;
      let lastActive = -1;
      for (let i = 0; i < windows.length; i++) {
        if (windows[i] >= threshold) {
          if (start < 0) start = i;
          lastActive = i;
        } else if (start >= 0 && i - lastActive > 5) {
          spans.push([start * 0.05, (lastActive + 1) * 0.05]);
          start = -1;
        }
      }
      if (start >= 0) spans.push([start * 0.05, (lastActive + 1) * 0.05]);
      return {
        duration: buffer.duration,
        threshold,
        spans: spans.map(([start, end]) => [Number(start.toFixed(2)), Number(end.toFixed(2))]),
      };
    }, encoded);
    console.log(JSON.stringify(activity, null, 2));
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
