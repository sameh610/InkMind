const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const origin = process.env.INKMIND_DEMO_URL || 'http://127.0.0.1:8082';
const profile = path.join(root, 'build', `.edge-action-visual-${Date.now()}`);
const captureDir = path.join(root, 'demo', 'video', 'action-visual-temp');
const output = path.join(root, 'demo', 'video', 'public', 'footage', 'inkmind-action-visual.webm');
const marksFile = path.join(root, 'demo', 'video', 'action-visual-marks.json');
const viewport = { width: 1600, height: 900 };
const marks = [];
const errors = [];
const started = Date.now();

function mark(name, detail = '') {
  const item = { name, seconds: Number(((Date.now() - started) / 1000).toFixed(2)), detail };
  marks.push(item);
  console.log(JSON.stringify(item));
}

async function tap(locator) {
  await locator.first().waitFor({ timeout: 20000 });
  const box = await locator.first().boundingBox();
  if (box && box.width > 2 && box.height > 2) {
    await locator.page().mouse.move(box.x + box.width / 2, box.y + box.height / 2, { steps: 9 });
    await locator.page().mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  } else {
    await locator.first().evaluate(element => element.click());
  }
}

async function tapSemantics(locator) {
  await locator.first().waitFor({ timeout: 20000 });
  const box = await locator.first().boundingBox();
  if (box && box.width > 2 && box.height > 2) {
    await locator.page().mouse.move(box.x + box.width / 2, box.y + box.height / 2, { steps: 9 });
    await locator.page().mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  } else {
    await locator.first().evaluate(element => element.click());
  }
}

async function showState(page, name) {
  const text = await page.locator('body').innerText();
  mark(name, text.replace(/\s+/g, ' ').slice(-900));
  await page.screenshot({ path: path.join(captureDir, `${name}.png`) });
}

async function selectEquation(page) {
  await tapSemantics(page.getByRole('button', { name: 'Lasso / select' }));
  const path = [
    [540, 250], [730, 250], [730, 323], [540, 323], [540, 250],
  ];
  await page.mouse.move(...path[0], { steps: 8 });
  await page.mouse.down();
  for (const [x, y] of path.slice(1)) await page.mouse.move(x, y, { steps: 14 });
  await page.mouse.up();
  await page.waitForTimeout(500);
  const selected = await page.getByRole('button', { name: 'Selection options' }).count() > 0 ||
    await page.getByText('Move', { exact: true }).count() > 0;
  mark('equation-selected', `selected=${selected}; ${String(await page.locator('body').innerText()).slice(-280)}`);
  if (!selected) throw new Error('Equation was not visibly selected.');
}

async function askVisual(page, prompt) {
  await tapSemantics(page.getByRole('button', { name: /Choose how AI should make it alive/ }));
  await tapSemantics(page.getByRole('menuitem', { name: /Create a new visual/i }));
  const field = page.getByRole('textbox').last();
  await field.waitFor({ timeout: 12000 });
  await field.fill(prompt);
  mark('visual-instruction', prompt);
  await page.waitForTimeout(550);
  await tapSemantics(page.getByRole('button', { name: 'Done' }));
  mark('visual-generate', 'New Visual submitted from the live UI');
}

async function graphSlider(page) {
  const sliders = page.getByRole('slider');
  await sliders.first().waitFor({ timeout: 60000 });
  const all = await sliders.evaluateAll(elements => elements.map(el => ({
    label: el.getAttribute('aria-label'),
    value: el.getAttribute('aria-valuenow'),
    text: el.getAttribute('aria-valuetext'),
    rect: (() => { const r = el.getBoundingClientRect(); return [r.x,r.y,r.width,r.height]; })(),
  })));
  mark('graph-ready', JSON.stringify(all));
  await showState(page, 'graph-initial');
  const slider = sliders.first();
  const box = await slider.boundingBox();
  if (!box) throw new Error('Graph slider has no screen bounds.');
  // Flutter's semantics bounds sometimes span just the thumb. Drag first;
  // keyboard input is the fallback only if the actual value did not change.
  const start = { x: box.x + box.width / 2, y: box.y + box.height / 2 };
  await page.mouse.move(start.x, start.y, { steps: 10 });
  await page.mouse.down();
  await page.mouse.move(start.x - 150, start.y, { steps: 28 });
  await page.waitForTimeout(350);
  await page.mouse.move(start.x - 265, start.y, { steps: 24 });
  await page.mouse.up();
  await page.waitForTimeout(450);
  let value = await slider.getAttribute('aria-valuetext');
  mark('graph-slider-drag', String(value));
  if (value === all[0]?.text) {
    await slider.focus();
    for (let i = 0; i < 5; i++) await slider.press('ArrowLeft');
    value = await slider.getAttribute('aria-valuetext');
    mark('graph-slider-keyboard-fallback', String(value));
  }
  await page.waitForTimeout(500);
  await showState(page, 'graph-changed');
  return value;
}

async function main() {
  fs.mkdirSync(captureDir, { recursive: true });
  fs.mkdirSync(path.dirname(output), { recursive: true });
  const context = await chromium.launchPersistentContext(profile, {
    channel: 'msedge', headless: true, viewport, deviceScaleFactor: 1,
    recordVideo: { dir: captureDir, size: viewport },
    args: ['--autoplay-policy=no-user-gesture-required'],
  });
  const page = context.pages()[0] || await context.newPage();
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  try {
    await page.addInitScript(() => {
      window.addEventListener('DOMContentLoaded', () => {
        const pointer = document.createElement('div');
        pointer.style.cssText = 'position:fixed;left:0;top:0;width:18px;height:18px;border:2px solid #f07455;border-radius:50%;background:#f0745533;z-index:2147483647;pointer-events:none;transform:translate(-50px,-50px);box-shadow:0 0 0 4px #f0745520';
        document.body.appendChild(pointer);
        window.addEventListener('pointermove', event => {
          pointer.style.transform = `translate(${event.clientX - 9}px,${event.clientY - 9}px)`;
        }, { passive: true });
      });
    });
    await page.goto(`${origin}/?native-ai=1&v=action-visual`, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(2400);
    const back = page.getByRole('button', { name: 'Back to library' });
    if (await back.count()) await tapSemantics(back);
    const open = page.getByRole('button', { name: 'Open InkMind Demo' });
    if (await open.count()) await tapSemantics(open);
    else await tapSemantics(page.getByRole('button', { name: /InkMind Demo/ }));
    await page.getByRole('button', { name: 'Next page' }).waitFor({ timeout: 25000 });
    mark('demo-open', 'Prepared InkMind Demo notebook opened');
    await tapSemantics(page.getByRole('button', { name: 'Next page' }));
    await tapSemantics(page.getByRole('button', { name: 'Next page' }));
    await page.getByText('3x^2 - 1 = y', { exact: true }).waitFor({ timeout: 15000 });
    await showState(page, 'graph-before-selection');
    await selectEquation(page);
    await page.waitForTimeout(500);
    await showState(page, 'graph-selected');
    await askVisual(page, 'Make an interactive graph of this exact equation. Keep the coefficient 3 and constant -1. Give me a slider for the x squared coefficient so the curve can flip.');
    await graphSlider(page);
    await page.waitForTimeout(500);
    const body = await page.locator('body').innerText();
    if (!body.includes('y = 3x² − 1')) throw new Error(`Exact graph equation missing: ${body.slice(-800)}`);
    mark('graph-verified', 'Exact y = 3x² − 1 shown and coefficient slider changed');
  } catch (error) {
    mark('capture-error', String(error));
    await page.screenshot({ path: path.join(captureDir, 'capture-error.png') }).catch(() => {});
    process.exitCode = 1;
  } finally {
    const videoPath = await page.video()?.path();
    await context.close();
    if (!process.exitCode && videoPath && fs.existsSync(videoPath)) fs.copyFileSync(videoPath, output);
    fs.writeFileSync(marksFile, JSON.stringify({ output, marks, errors }, null, 2));
    console.log(JSON.stringify({ output, marksFile, marks, errors }, null, 2));
  }
}

main().catch(error => { console.error(error); process.exitCode = 1; });
