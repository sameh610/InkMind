const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

(async () => {
  const source = process.argv[2];
  const output = path.resolve(process.argv.find(arg=>arg.startsWith('--out='))?.slice(6) || 'video-review');
  fs.mkdirSync(output, { recursive: true });
  const data = fs.readFileSync(source).toString('base64');
  const mime = path.extname(source).toLowerCase() === '.webm' ? 'video/webm' : 'video/mp4';
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  try {
    const page = await browser.newPage();
    await page.setContent(`<video id="clip" preload="auto" muted src="data:${mime};base64,${data}"></video>`);
    const meta = await page.evaluate(async () => {
      const video = document.querySelector('#clip');
      await new Promise((resolve, reject) => {
        if (video.readyState >= 1) return resolve();
        video.addEventListener('loadedmetadata', resolve, { once: true });
        video.addEventListener('error', () => reject(new Error('Could not decode video')), { once: true });
      });
      return { duration: video.duration, width: video.videoWidth, height: video.videoHeight };
    });
    console.log(JSON.stringify(meta));
    const everyArg = process.argv.slice(3).find(arg => arg.startsWith('--every='));
    const interval = everyArg ? Number(everyArg.split('=')[1]) : 0;
    const requested = interval > 0
      ? Array.from({length: Math.ceil(meta.duration / interval)}, (_, i) => i * interval + .01)
      : process.argv.slice(3).map(Number).filter(Number.isFinite);
    const count = Math.min(12, Math.max(4, Math.ceil(meta.duration / 1.5)));
    const sampleTimes = requested.length ? requested : Array.from({length: count}, (_, i) => (i + 0.25) * meta.duration / count);
    for (let i = 0; i < sampleTimes.length; i++) {
      const second = Math.max(0, Math.min(meta.duration - 0.05, sampleTimes[i]));
      const frame = await page.evaluate(async second => {
        const video = document.querySelector('#clip');
        video.currentTime = second;
        await new Promise(resolve => video.addEventListener('seeked', resolve, { once: true }));
        const canvas = document.createElement('canvas');
        canvas.width = video.videoWidth;
        canvas.height = video.videoHeight;
        canvas.getContext('2d').drawImage(video, 0, 0);
        return canvas.toDataURL('image/png').split(',')[1];
      }, second);
      const file = path.join(output, `frame-${String(i).padStart(2, '0')}.png`);
      fs.writeFileSync(file, Buffer.from(frame, 'base64'));
      console.log(`${i}: ${second.toFixed(2)}s ${file}`);
    }
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
