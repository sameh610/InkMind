const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const url = process.env.INKMIND_DEMO_URL || 'http://127.0.0.1:8080';
const viewport = { width: 1600, height: 900 };
const captureDir = path.join(root, 'demo', 'video', 'capture-action-debug');
const output = path.join(root, 'demo', 'video', 'public', 'footage', 'inkmind-action-debug.webm');
const marksPath = path.join(root, 'demo', 'video', 'action-debug-marks.json');
const began = Date.now();
const marks = [];
const mark = (name, detail = '') => {
  const item = { name, seconds: Number(((Date.now() - began) / 1000).toFixed(2)), detail };
  marks.push(item);
  console.log(JSON.stringify(item));
};

async function semanticsClick(locator) {
  await locator.first().waitFor({ timeout: 20000 });
  await locator.first().evaluate((element) => element.click());
}

async function lasso(page) {
  const tool = page.getByRole('button', { name: 'Lasso / select' });
  await semanticsClick(tool);
  mark('lasso-tool', 'Selected the app Lasso / select tool');
  const points = [
    [526, 236], [596, 214], [681, 223], [746, 258],
    [764, 330], [750, 410], [667, 433], [572, 415],
    [530, 352], [526, 236],
  ];
  await page.mouse.move(...points[0]);
  await page.mouse.down();
  for (const point of points.slice(1)) {
    await page.mouse.move(...point, { steps: 3 });
  }
  await page.mouse.up();
  await page.waitForTimeout(450);
  const body = await page.locator('body').innerText();
  const selected = await page.getByRole('button', { name: 'Selection options' }).count() > 0 ||
    await page.getByText('Move', { exact: true }).count() > 0;
  mark('selection', `selected=${selected}; ${body.slice(-160)}`);
  if (!selected) throw new Error(`Lasso did not select the math object: ${body.slice(-280)}`);
}

(async () => {
  fs.mkdirSync(captureDir, { recursive: true });
  fs.mkdirSync(path.dirname(output), { recursive: true });
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const context = await browser.newContext({
    viewport,
    deviceScaleFactor: 1,
    recordVideo: { dir: captureDir, size: viewport },
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(1900);
    const back = page.getByRole('button', { name: 'Back to library' });
    if (await back.count()) await semanticsClick(back);
    const demo = page.getByRole('button', { name: 'Open InkMind Demo' });
    if (await demo.count()) await semanticsClick(demo);
    else await semanticsClick(page.getByRole('button', { name: /InkMind Demo/ }));
    await page.getByRole('button', { name: 'Next page' }).waitFor({ timeout: 30000 });
    // This capture-only pointer ring follows real mouse events. It makes the
    // selection and Debug tap legible in Edge's screen recording.
    await page.evaluate(() => {
      const ring = document.createElement('div');
      ring.setAttribute('data-capture-pointer', '');
      ring.style.cssText = 'position:fixed;z-index:2147483647;width:22px;height:22px;border:2px solid #e48869;border-radius:50%;background:#e4886933;box-shadow:0 0 0 3px #ffffffaa;pointer-events:none;left:-30px;top:-30px;transform:translate(-50%,-50%);';
      document.body.appendChild(ring);
      window.addEventListener('pointermove', (event) => {
        ring.style.left = `${event.clientX}px`;
        ring.style.top = `${event.clientY}px`;
      }, { passive: true });
    });
    await semanticsClick(page.getByRole('button', { name: 'Next page' }));
    await page.getByText('02 / REASONING', { exact: false }).first().waitFor({ timeout: 15000 });
    mark('wrong-work', 'Prepared math reads 3x + 5 = 20; 3x = 25; x = 8.33');
    await page.waitForTimeout(800);
    await lasso(page);
    await page.waitForTimeout(650);
    const debug = page.getByRole('button', { name: 'Debug', exact: true });
    await debug.waitFor({ timeout: 15000 });
    const box = await debug.boundingBox();
    if (!box) throw new Error('The real Debug button has no visible bounds.');
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2, { steps: 12 });
    await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
    mark('debug-trigger', 'Clicked the visible Debug action');
    await page.getByRole('button', { name: 'Replay reasoning' }).waitFor({ timeout: 300000 });
    mark('debug-result', 'App created a reasoning replay result from the selected work');
    await page.waitForTimeout(1300);
    await page.screenshot({ path: path.join(captureDir, 'debug-rewind.png') });
    await page.waitForTimeout(900);
    await page.screenshot({ path: path.join(captureDir, 'debug-stop.png') });
    await page.waitForTimeout(1800);
    await page.screenshot({ path: path.join(captureDir, 'debug-corrected.png') });
    const body = await page.locator('body').innerText();
    const verified = body.includes('3x = 15') && body.includes('x = 5') &&
      body.includes('Step 2 changed the solution');
    mark('verification', verified
      ? 'First divergence at 3x = 25; corrected branch contains 3x = 15 and x = 5'
      : 'Expected correction text was not visible in the real app');
    if (!verified) throw new Error('InkDebug did not visibly show the expected correction.');
    await page.waitForTimeout(650);
  } catch (error) {
    mark('capture-error', String(error));
    await page.screenshot({ path: path.join(captureDir, 'capture-error.png') }).catch(() => {});
  } finally {
    const recording = page.video();
    await context.close();
    await browser.close();
    if (recording) fs.copyFileSync(await recording.path(), output);
    fs.writeFileSync(marksPath, JSON.stringify({ marks, errors }, null, 2));
  }
  console.log(JSON.stringify({ output, marksPath, marks, errors }, null, 2));
  if (marks.some((item) => item.name === 'capture-error') || errors.length) process.exitCode = 1;
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
