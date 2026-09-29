const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const profile = path.join(root, 'build', '.edge-demo-capture-final3');
const temp = path.join(root, 'demo', 'video', 'bird-capture-temp');
const output = path.join(root, 'demo', 'video', 'public', 'footage', 'inkmind-bird.webm');
const marksPath = path.join(root, 'demo', 'video', 'bird-capture-marks.json');
const viewport = { width: 1600, height: 900 };
const stamp = (name, detail = '') => {
  const item = { name, seconds: Number(((Date.now() - start) / 1000).toFixed(2)), detail };
  marks.push(item);
  console.log(JSON.stringify(item));
};
const marks = [];
const start = Date.now();

async function click(locator) {
  await locator.first().waitFor({ timeout: 15000 });
  await locator.first().evaluate(element => element.click());
}

async function openBird(page) {
  await page.goto('http://127.0.0.1:8080/?native-ai=1', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(2500);
  const back = page.getByRole('button', { name: 'Back to library' });
  if (await back.count()) await click(back);
  const open = page.getByRole('button', { name: 'Open InkMind Demo' });
  if (await open.count()) await click(open);
  else await click(page.getByRole('button', { name: /InkMind Demo/ }));
  await page.getByRole('button', { name: 'Next page' }).waitFor({ timeout: 20000 });
  for (let i = 0; i < 3; i++) {
    await click(page.getByRole('button', { name: 'Next page' }));
    await page.waitForTimeout(350);
  }
  const body = await page.locator('body').innerText();
  if (!body.includes('04 / GENERALITY')) throw new Error(`Bird page not visible: ${body.slice(0, 500)}`);
  stamp('bird-page', 'Prepared fourth page visible');
}

async function launch(record = false) {
  return chromium.launchPersistentContext(profile, {
    channel: 'msedge',
    headless: true,
    viewport,
    deviceScaleFactor: 1,
    ...(record ? { recordVideo: { dir: temp, size: viewport } } : {}),
    args: ['--autoplay-policy=no-user-gesture-required'],
  });
}

(async () => {
  fs.mkdirSync(temp, { recursive: true });
  fs.mkdirSync(path.dirname(output), { recursive: true });
  const context = await launch();
  try {
    const page = context.pages()[0] || await context.newPage();
    await openBird(page);
    const play = page.getByRole('button', { name: 'Play motion' });
    if (!(await play.count())) {
      await click(page.getByRole('button', { name: /Choose how AI should make it alive/ }));
      await click(page.getByRole('menuitem', { name: /Animate my ink/i }));
      const field = page.getByRole('textbox').last();
      await field.fill('Make this bird fly across the page to the other side, turn around, fly back, and repeat. Move the original bird strokes together.');
      await click(page.getByRole('button', { name: 'Done' }));
      stamp('bird-request', 'Animate my ink submitted through the real app UI');
      const deadline = Date.now() + 90000;
      while (!(await play.count())) {
        if (Date.now() > deadline) throw new Error('Bird motion was not ready within 90 seconds.');
        const body = await page.locator('body').innerText();
        if (/Downloading (?:native|browser) model/i.test(body)) throw new Error('A model download is required; capture stopped.');
        if (/Retry|The model returned no motion plan|Unknown ink motion|could not/i.test(body.slice(-300))) {
          throw new Error(`AI motion failed: ${body.slice(-500)}`);
        }
        await page.waitForTimeout(500);
      }
    }
    stamp('bird-ready', 'Real bird page has Play motion control');
    await page.screenshot({ path: path.join(temp, 'bird-ready.png') });
    await page.waitForTimeout(1500);
  } finally {
    await context.close();
  }

  const before = new Set(fs.readdirSync(temp).filter(name => name.endsWith('.webm')));
  const recorded = await launch(true);
  try {
    const page = recorded.pages()[0] || await recorded.newPage();
    await openBird(page);
    await page.waitForTimeout(500);
    const play = page.getByRole('button', { name: 'Play motion' });
    await play.waitFor({ timeout: 12000 });
    stamp('record-play', 'Bird motion playback started');
    await click(play);
    await page.getByRole('button', { name: 'Pause motion' }).waitFor({ timeout: 5000 });
    for (const [i, delay] of [600, 900, 900, 900, 900].entries()) {
      await page.waitForTimeout(delay);
      await page.screenshot({ path: path.join(temp, `bird-motion-${i}.png`) });
      stamp(`bird-frame-${i}`, 'Captured the real app during playback');
    }
    await page.waitForTimeout(3000);
    await click(page.getByRole('button', { name: 'Pause motion' }));
  } finally {
    await recorded.close();
  }
  const after = fs.readdirSync(temp).filter(name => name.endsWith('.webm') && !before.has(name));
  if (after.length !== 1) throw new Error(`Expected one new Edge recording, found ${after.length}.`);
  fs.copyFileSync(path.join(temp, after[0]), output);
  fs.writeFileSync(marksPath, JSON.stringify({ output, marks }, null, 2));
  console.log(JSON.stringify({ output, marksPath, marks }, null, 2));
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
