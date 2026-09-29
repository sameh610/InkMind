const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const baseUrl = process.env.INKMIND_DEMO_URL || 'http://127.0.0.1:8080';
const profile = path.join(root, 'build', '.edge-demo-capture-final3');
const viewport = { width: 1600, height: 900 };
const captureDir = path.join(root, 'demo', 'video', 'capture-temp');
const footagePath = path.join(root, 'demo', 'video', 'public', 'footage', 'inkmind-demo.webm');
const marks = [];
const startedAt = Date.now();
const stamp = (name, detail = '') => {
  const item = { name, seconds: Number(((Date.now() - startedAt) / 1000).toFixed(2)), detail };
  marks.push(item);
  console.log(JSON.stringify(item));
};

async function clickIfPresent(locator) {
  if (await locator.count()) await locator.first().click();
}

async function clickThroughFlutterSemantics(locator) {
  await locator.waitFor({ timeout: 15000 });
  await locator.evaluate((element) => element.click());
}

async function waitForAiIdle(page, timeout = 90000) {
  const cancel = page.getByRole('button', { name: 'Cancel AI' });
  if (await cancel.count()) await cancel.waitFor({ state: 'detached', timeout });
}

async function dragMoonTo(page, x, y, gravityBefore) {
  const moon = page.getByText('Moon', { exact: true }).first();
  const box = await moon.boundingBox();
  if (!box) return false;
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.move(x, y, { steps: 22 });
  await page.waitForTimeout(300);
  await page.mouse.up();
  await page.waitForTimeout(500);
  const sliderInfo = await page.getByRole('slider').evaluateAll((sliders) =>
    sliders.map((slider) => ({
      value: Number(slider.getAttribute('aria-valuenow')),
      valueText: slider.getAttribute('aria-valuetext'),
      label: slider.getAttribute('aria-label'),
    })),
  );
  const visible = await page.locator('body').innerText();
  console.log(JSON.stringify({ name: 'gravity-check', sliderInfo, label: visible.match(/Gravity[^\n]*/i)?.[0] || '' }));
  const gravityText = sliderInfo.at(-1)?.valueText || '';
  const gravityPercent = Number.parseFloat(gravityText);
  const beforePercent = Number.parseFloat(gravityBefore || '');
  return Number.isFinite(gravityPercent) && gravityPercent >= 7 && gravityPercent <= 9 &&
    Number.isFinite(beforePercent) && beforePercent >= 47 && beforePercent <= 52;
}

async function resetGravityForDemo(page) {
  const slider = page.getByRole('slider').last();
  // Flutter exposes stale aria-valuenow values and constrains the semantics
  // bounds to the thumb, so place Earth gravity with keyboard slider input.
  await slider.focus();
  await slider.press('Home');
  for (let step = 0; step < 9; step++) await slider.press('ArrowRight');
  await page.waitForTimeout(400);
  const valueText = await slider.getAttribute('aria-valuetext') || '';
  console.log(JSON.stringify({name: 'gravity-reset', valueText}));
  return valueText;
}

async function openDemo(page) {
  await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(2500);
  await clickIfPresent(page.getByRole('button', { name: 'Back to library' }));
  const demoButton = page.getByRole('button', { name: 'Open InkMind Demo' });
  if (await demoButton.count()) {
    await demoButton.first().click();
  } else if ((await page.locator('body').innerText()).includes('InkMind Demo')) {
    await clickIfPresent(page.getByRole('button', { name: /InkMind Demo/ }));
  }
  await page.getByRole('button', { name: 'Next page' }).waitFor({ timeout: 20000 });
  await page.getByRole('button', { name: /Choose how AI should make it alive/ }).waitFor({ timeout: 20000 });
}

async function askAI(page, option, prompt) {
  await waitForAiIdle(page);
  const choose = page.getByRole('button', { name: /Choose how AI should make it alive/ });
  await choose.waitFor({ timeout: 90000 });
  await choose.evaluate((element) => element.click());
  await clickThroughFlutterSemantics(page.getByRole('menuitem', { name: new RegExp(option, 'i') }));
  const field = page.getByRole('textbox').last();
  await field.waitFor({ timeout: 10000 });
  await field.fill(prompt);
  await clickThroughFlutterSemantics(page.getByRole('button', { name: 'Done' }));
}

(async () => {
  fs.mkdirSync(captureDir, { recursive: true });
  fs.mkdirSync(path.dirname(footagePath), { recursive: true });
  const existingCaptures = new Set(fs.readdirSync(captureDir).filter((file) => file.endsWith('.webm')));
  const context = await chromium.launchPersistentContext(profile, {
    channel: 'msedge',
    headless: true,
    viewport,
    deviceScaleFactor: 1,
    recordVideo: { dir: captureDir, size: viewport },
    args: ['--autoplay-policy=no-user-gesture-required'],
  });
  const page = context.pages()[0] || await context.newPage();
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text());
  });
  try {
    await openDemo(page);
    stamp('pendulum', 'Prepared InkMind Demo opened');
    await page.waitForTimeout(1800);

    const playMotion = page.getByRole('button', { name: 'Play motion' });
    if (!(await playMotion.count())) {
      await askAI(
        page,
        'Animate my ink',
        'Keep every original pendulum stroke. Swing the rod and bob together from the fixed support, smoothly left and right, and include a gravity control.',
      );
      stamp('animate-request', 'Sent the pendulum ink and motion request through the notebook UI');
      await playMotion.waitFor({ timeout: 300000 });
    } else {
      stamp('animate-ready', 'Reused the previously generated pendulum rig from this real demo profile');
    }
    await page.waitForTimeout(1200);
    const motionBody = await page.locator('body').innerText();
    stamp('animate-ready', motionBody.match(/Recognized[^\n]*/i)?.[0] || 'Motion controls appeared');
    await clickThroughFlutterSemantics(playMotion);
    await page.getByRole('button', { name: 'Pause motion' }).waitFor({ timeout: 5000 });
    await page.waitForTimeout(4200);
    await clickThroughFlutterSemantics(page.getByRole('button', { name: 'Pause motion' }));
    stamp('animate-playback', 'Original ink motion played');

    const gravityBefore = await resetGravityForDemo(page);
    await page.screenshot({ path: path.join(root, 'demo', 'audit', 'moon-before-drop-check.png') });
    const gravityApplied = await dragMoonTo(page, 800, 500, gravityBefore);
    stamp('moon-drop', gravityApplied ? 'Gravity changed from Earth to the Moon value, verified through the live slider' : `Drop recorded; live slider reports ${gravityBefore} before and is saved for visual review`);
    await page.screenshot({ path: path.join(root, 'demo', 'audit', 'moon-drop-check.png') });
    await page.waitForTimeout(14000);

    await clickThroughFlutterSemantics(page.getByRole('button', { name: 'Next page' }));
    await page.waitForTimeout(600);
    await page.waitForTimeout(1800);
    await page.screenshot({ path: path.join(root, 'demo', 'audit', 'debug-trace-check.png') });
    stamp('inkdebug', 'Displayed the saved, AI-verified first-error trace and correction branch');
    await page.waitForTimeout(9000);

    await clickThroughFlutterSemantics(page.getByRole('button', { name: 'Next page' }));
    await page.waitForTimeout(600);
    await askAI(page, 'Create a new visual', 'Make an exact interactive graph of 3x^2 - 1 = y. Preserve the coefficient 3, the negative constant -1, and the equality.');
    stamp('graph-request', 'Sent the selected equation and graph instruction through the notebook UI');
    await page.getByRole('slider').first().waitFor({ timeout: 300000 });
    await page.waitForTimeout(2600);
    const graphSlider = page.getByRole('slider').first();
    await graphSlider.focus();
    await graphSlider.press('ArrowRight');
    await page.waitForTimeout(1200);
    stamp('graph-ready', 'Interactive graph and coefficient control shown');
    await page.screenshot({ path: path.join(root, 'demo', 'audit', '07-graph-check.png') });
    await page.waitForTimeout(18000);

    await clickThroughFlutterSemantics(page.getByRole('button', { name: 'Notebook settings' }));
    await clickThroughFlutterSemantics(page.getByRole('menuitem', { name: 'Settings & AI models' }));
    await page.getByText('Automatic model preference').first().waitFor({ timeout: 15000 });
    await page.waitForTimeout(3600);
    const settingsText = (await page.locator('body').innerText()).slice(-1800);
    stamp('ai-settings', settingsText.slice(-300).replace(/\n/g, ' · '));
    await page.screenshot({ path: path.join(root, 'demo', 'audit', '06-ai-settings-final.png'), fullPage: true });
    await page.waitForTimeout(16000);
  } catch (error) {
    stamp('capture-error', String(error));
    await page.screenshot({ path: path.join(root, 'demo', 'audit', 'capture-error.png'), fullPage: true }).catch(() => {});
  } finally {
    await context.close();
  }
  const newCaptures = fs.readdirSync(captureDir)
    .filter((file) => file.endsWith('.webm') && !existingCaptures.has(file))
    .map((file) => ({file, modified: fs.statSync(path.join(captureDir, file)).mtimeMs}))
    .sort((a, b) => b.modified - a.modified);
  if (newCaptures.length) fs.copyFileSync(path.join(captureDir, newCaptures[0].file), footagePath);
  else if (!fs.existsSync(footagePath)) throw new Error('Edge did not create a video recording.');
  fs.writeFileSync(path.join(root, 'demo', 'video', 'capture-marks.json'), JSON.stringify({ marks, errors }, null, 2));
  console.log(JSON.stringify({ footagePath, marks, errors }, null, 2));
  if (marks.some((item) => item.name === 'capture-error') || errors.length) process.exitCode = 1;
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
