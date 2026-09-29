const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const profile = path.join(root, 'build', '.edge-action-ink-capture');
const captureDir = path.join(root, 'demo', 'video', 'action-ink-capture-temp');
const footagePath = path.join(root, 'demo', 'video', 'public', 'footage', 'inkmind-action-ink.webm');
const marksPath = path.join(root, 'demo', 'video', 'action-ink-capture-marks.json');
const viewport = { width: 1600, height: 900 };
const inspectOnly = process.argv.includes('--inspect');
const marks = [];
let start = 0;

function stamp(name, detail = '') {
  const item = { name, seconds: Number(((Date.now() - start) / 1000).toFixed(2)), detail };
  marks.push(item);
  console.log(JSON.stringify(item));
}

async function click(locator) {
  await locator.first().waitFor({ timeout: 20000 });
  await locator.first().click();
}

async function clickSemantics(locator) {
  await locator.first().waitFor({ timeout: 20000 });
  await locator.first().evaluate((element) => element.click());
}

async function installPointer(page) {
  await page.evaluate(() => {
    const dot = document.createElement('div');
    dot.id = 'inkmind-capture-pointer';
    dot.style.cssText = 'position:fixed;left:0;top:0;width:17px;height:17px;border:2px solid #c46a47;background:#fff9;border-radius:50%;box-shadow:0 0 0 5px #c46a4729,0 2px 7px #24382f55;transform:translate(-100px,-100px);pointer-events:none;z-index:2147483647;transition:width .08s,height .08s;';
    document.body.append(dot);
  });
}

async function moveMouse(page, x, y, options = {}) {
  await page.mouse.move(x, y, options);
  await page.evaluate(({ x, y }) => {
    const dot = document.getElementById('inkmind-capture-pointer');
    if (dot) dot.style.transform = `translate(${x - 8}px,${y - 8}px)`;
  }, { x, y });
}

async function downMouse(page) {
  await page.mouse.down();
  await page.evaluate(() => {
    const dot = document.getElementById('inkmind-capture-pointer');
    if (dot) dot.style.background = '#c46a47';
  });
}

async function upMouse(page) {
  await page.mouse.up();
  await page.evaluate(() => {
    const dot = document.getElementById('inkmind-capture-pointer');
    if (dot) dot.style.background = '#fff9';
  });
}

async function clickReal(page, locator) {
  await locator.first().waitFor({ timeout: 20000 });
  const box = await locator.first().boundingBox();
  if (!box) throw new Error('Action target has no visible bounds.');
  const x = box.x + box.width / 2;
  const y = box.y + box.height / 2;
  await moveMouse(page, x, y);
  await page.waitForTimeout(90);
  await downMouse(page);
  await page.waitForTimeout(100);
  await upMouse(page);
}

async function openDemo(page) {
  await page.goto('http://127.0.0.1:8080/?action-ink=1', { waitUntil: 'domcontentloaded' });
  await page.getByRole('button', { name: 'Back to library' }).or(page.getByRole('button', { name: 'Open InkMind Demo' })).first().waitFor({ timeout: 30000 });
  const back = page.getByRole('button', { name: 'Back to library' });
  if (await back.count()) await clickSemantics(back);
  const demo = page.getByRole('button', { name: 'Open InkMind Demo' });
  if (await demo.count()) await clickSemantics(demo);
  else await clickSemantics(page.getByRole('button', { name: /InkMind Demo/ }));
  await page.getByRole('button', { name: 'Next page' }).waitFor({ timeout: 20000 });
}

async function screenshot(page, name) {
  await page.screenshot({ path: path.join(captureDir, `${name}.png`) });
}

async function lassoPendulum(page) {
  await clickReal(page, page.getByRole('button', { name: 'Lasso / select' }));
  stamp('select-tool', 'User chose Lasso / select');
  const points = [
    [735, 235], [800, 228], [874, 239], [887, 333],
    [882, 429], [876, 530], [811, 545], [733, 526],
    [723, 407], [727, 295], [735, 235],
  ];
  await moveMouse(page, ...points[0]);
  await downMouse(page);
  for (const point of points.slice(1)) {
    await moveMouse(page, ...point, { steps: 4 });
    await page.waitForTimeout(35);
  }
  await upMouse(page);
  await page.waitForTimeout(350);
  const selected = await page.getByRole('button', { name: 'Selection options' }).count();
  stamp('selection', selected ? 'Selection options appeared; three pendulum strokes highlighted' : 'Selection options missing');
  await screenshot(page, 'selected');
  if (!selected) throw new Error('Pendulum selection failed: Selection options did not appear.');
}

async function requestAnimateInk(page) {
  await clickReal(page, page.getByRole('button', { name: /Choose how AI should make it alive/ }));
  await clickReal(page, page.getByRole('menuitem', { name: /Animate my ink/i }));
  await page.getByRole('textbox').last().waitFor({ timeout: 10000 });
  stamp('animate-command', 'User chose Animate my ink; motion instruction dialog opened');
  await screenshot(page, 'animate-dialog');
  const field = page.getByRole('textbox').last();
  await clickReal(page, field);
  await field.pressSequentially('Swing like a pendulum. Keep the fixed pivot in place and move my original rod and bob strokes together. Include gravity control.', { delay: 12 });
  await page.waitForTimeout(450);
  stamp('instruction', 'Swing like a pendulum; preserve original strokes; expose gravity');
  await screenshot(page, 'animate-instruction');
  await clickReal(page, page.getByRole('button', { name: 'Done' }));
  stamp('animate-execute', 'User submitted Animate Ink');
  const play = page.getByRole('button', { name: 'Play motion' });
  const deadline = Date.now() + 300000;
  while (!(await play.count())) {
    if (Date.now() > deadline) throw new Error('Animate Ink did not produce motion within five minutes.');
    const body = await page.locator('body').innerText();
    if (/The model returned no motion plan|motion plan references invalid strokes|Browser AI failed/i.test(body.slice(-800))) {
      throw new Error(`Animate Ink failed: ${body.slice(-800)}`);
    }
    await page.waitForTimeout(450);
  }
  stamp('animate-ready', 'Play motion appeared after real AI response');
  await screenshot(page, 'animate-ready');
  await page.waitForTimeout(300);
  await clickReal(page, play);
  await page.getByRole('button', { name: 'Pause motion' }).waitFor({ timeout: 5000 });
  stamp('first-swing', 'Original selected stroke rig began moving after Play motion');
  await page.waitForTimeout(1250);
  await screenshot(page, 'moving');
}

async function dragMoon(page) {
  const moon = page.getByText('Moon', { exact: true }).first();
  const box = await moon.boundingBox();
  if (!box) throw new Error('Moon InkMatter label is not visible.');
  const x0 = box.x + box.width / 2;
  const y0 = box.y + box.height / 2;
  const x1 = 790;
  const y1 = 490;
  const before = await page.getByRole('slider').last().getAttribute('aria-valuetext');
  stamp('gravity-before', before || 'Gravity slider visible');
  await moveMouse(page, x0, y0);
  await downMouse(page);
  await page.waitForTimeout(300);
  stamp('moon-pickup', 'User held the handwritten Moon modifier');
  for (let i = 1; i <= 32; i++) {
    const fraction = i / 32;
    await moveMouse(page, x0 + (x1 - x0) * fraction, y0 + (y1 - y0) * fraction);
    await page.waitForTimeout(30);
  }
  await page.waitForTimeout(180);
  await upMouse(page);
  stamp('moon-drop', 'User dropped Moon onto the moving original pendulum');
  await page.waitForTimeout(250);
  const after = await page.getByRole('slider').last().getAttribute('aria-valuetext');
  stamp('gravity-after', after || '');
  await screenshot(page, 'moon-drop');
  const percent = Number.parseFloat(after || '');
  if (!(percent >= 7 && percent <= 9)) throw new Error(`Moon did not set gravity to 1.62 m/s²: ${after}`);
  await page.waitForTimeout(3000);
  await screenshot(page, 'moon-motion');
}

async function main() {
  fs.mkdirSync(captureDir, { recursive: true });
  fs.mkdirSync(path.dirname(footagePath), { recursive: true });
  const before = new Set(fs.readdirSync(captureDir).filter((name) => name.endsWith('.webm')));
  const context = await chromium.launchPersistentContext(profile, {
    channel: 'msedge',
    headless: true,
    viewport,
    deviceScaleFactor: 1,
    ...(inspectOnly ? {} : { recordVideo: { dir: captureDir, size: viewport } }),
  });
  const page = context.pages()[0] || await context.newPage();
  start = Date.now();
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  try {
    await openDemo(page);
    await installPointer(page);
    stamp('pendulum-page', 'InkMind Demo opened in Edge');
    await screenshot(page, 'initial');
    console.log(JSON.stringify({ name: 'initial-text', text: (await page.locator('body').innerText()).slice(0, 1200) }));
    if (inspectOnly) return;
    if (await page.getByRole('button', { name: 'Play motion' }).count()) {
      throw new Error('The capture profile already has a generated pendulum. Use a fresh capture profile for the input-to-result take.');
    }
    await page.waitForTimeout(500);
    await lassoPendulum(page);
    await page.waitForTimeout(500);
    await requestAnimateInk(page);
    await dragMoon(page);
    await page.waitForTimeout(500);
  } catch (error) {
    stamp('capture-error', String(error));
    await screenshot(page, 'error').catch(() => {});
    throw error;
  } finally {
    await context.close();
    if (!inspectOnly) {
      const after = fs.readdirSync(captureDir).filter((name) => name.endsWith('.webm') && !before.has(name));
      if (after.length === 1) fs.copyFileSync(path.join(captureDir, after[0]), footagePath);
      fs.writeFileSync(marksPath, JSON.stringify({ footagePath, marks, errors }, null, 2));
    }
  }
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
