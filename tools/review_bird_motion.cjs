const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

(async () => {
  const source = path.resolve('demo/video/public/footage/inkmind-action-bird.webm');
  const output = path.resolve('demo/video/action-bird-temp');
  const data = fs.readFileSync(source).toString('base64');
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  try {
    const page = await browser.newPage();
    await page.setContent(`<video id="clip" preload="auto" muted src="data:video/webm;base64,${data}"></video>`);
    for (const second of [4.5, 6.4, 6.9, 97.9, 98.2, 98.8, 99.5, 100.2, 101.0, 102.5]) {
      const frame = await page.evaluate(async (time) => {
        const video = document.querySelector('#clip');
        if (video.readyState < 1) await new Promise(resolve => video.addEventListener('loadedmetadata', resolve, { once: true }));
        video.currentTime = time;
        await new Promise(resolve => video.addEventListener('seeked', resolve, { once: true }));
        const canvas = document.createElement('canvas');
        canvas.width = video.videoWidth;
        canvas.height = video.videoHeight;
        canvas.getContext('2d').drawImage(video, 0, 0);
        return canvas.toDataURL('image/png').split(',')[1];
      }, second);
      const file = path.join(output, `review-${second.toFixed(1)}.png`);
      fs.writeFileSync(file, Buffer.from(frame, 'base64'));
      console.log(file);
    }
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
