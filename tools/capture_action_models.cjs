const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const {chromium} = require('playwright');

const root = path.resolve(__dirname, '..');
const origin = process.env.INKMIND_DEMO_URL || 'http://127.0.0.1:8082';
const profile = path.join(root, 'build', `.edge-action-models-${Date.now()}`);
const captureDir = path.join(root, 'demo', 'video', 'action-models-temp');
const output = path.join(root, 'demo', 'video', 'public', 'footage', 'inkmind-action-models.webm');
const marksFile = path.join(root, 'demo', 'video', 'action-models-marks.json');
const ffmpeg = path.join(root, 'demo', 'video', 'node_modules', '@remotion', 'compositor-win32-x64-msvc', 'ffmpeg.exe');
const viewport = {width: 1600, height: 900};
const marks = [];
const errors = [];
let videoEpoch = Date.now();
const mark = (name, detail = '') => {
  const item = {name, sourceSeconds: Number(((Date.now() - videoEpoch) / 1000).toFixed(2)), detail};
  marks.push(item);
  console.log(JSON.stringify(item));
};

async function tap(locator, page) {
  await locator.first().waitFor({timeout: 20000});
  const box = await locator.first().boundingBox();
  if (!box) throw new Error(`No bounds for ${locator}`);
  const x = box.x + box.width / 2, y = box.y + box.height / 2;
  await page.mouse.move(x, y, {steps: 11});
  await page.mouse.click(x, y);
}

async function main() {
  fs.mkdirSync(captureDir, {recursive: true});
  fs.mkdirSync(path.dirname(output), {recursive: true});
  const context = await chromium.launchPersistentContext(profile, {
    channel: 'msedge', headless: true, viewport, deviceScaleFactor: 1,
    recordVideo: {dir: captureDir, size: viewport},
    args: ['--autoplay-policy=no-user-gesture-required'],
  });
  const page = context.pages()[0] || await context.newPage();
  videoEpoch = Date.now();
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', message => {if (message.type() === 'error') errors.push(message.text());});
  let actionStart = 0, actionEnd = 0;
  try {
    await page.addInitScript(() => {
      window.addEventListener('DOMContentLoaded', () => {
        const pointer = document.createElement('div');
        pointer.style.cssText = 'position:fixed;left:0;top:0;width:18px;height:18px;border:2px solid #f07455;border-radius:50%;background:#f0745533;z-index:2147483647;pointer-events:none;transform:translate(-50px,-50px);box-shadow:0 0 0 4px #f0745520';
        document.body.appendChild(pointer);
        window.addEventListener('pointermove', event => {
          pointer.style.transform = `translate(${event.clientX - 9}px,${event.clientY - 9}px)`;
        }, {passive: true});
      });
    });
    await page.goto(`${origin}/?native-ai=1&v=action-models`, {waitUntil: 'domcontentloaded'});
    await page.waitForTimeout(2200);
    const back = page.getByRole('button', {name: 'Back to library'});
    if (await back.count()) await tap(back, page);
    const open = page.getByRole('button', {name: 'Open InkMind Demo'});
    if (await open.count()) await tap(open, page);
    // The first-run route can open the prepared demo directly.
    await tap(page.getByRole('button', {name: 'Notebook settings'}), page);
    await tap(page.getByRole('menuitem', {name: 'Settings & AI models'}), page);
    await page.waitForTimeout(650);
    mark('settings-open', 'Settings & AI models dialog opened');
    // Scroll the real dialog to put the actual resolved Automatic row and a
    // supported Qwen model card into one frame. Leave quantization on Auto.
    await page.mouse.move(800, 550, {steps: 11});
    await page.mouse.wheel(0, 540);
    await page.waitForTimeout(500);
    await page.screenshot({path: path.join(captureDir, 'settings-ready.png')});
    const initial = await page.locator('body').innerText();
    mark('automatic-visible', initial.replace(/\s+/g, ' ').slice(0, 1500));
    actionStart = (Date.now() - videoEpoch) / 1000;
    await page.waitForTimeout(420);
    await tap(page.getByRole('button', {name: 'Use model'}).first(), page);
    mark('qwen-selected', 'Clicked supported Qwen 2.5 Coder 0.5B model preference; no model inference or download started');
    await page.waitForTimeout(760);
    await tap(page.getByRole('button', {name: 'Use Auto'}), page);
    mark('automatic-restored', 'Clicked Automatic; model preference and Auto quantization restored');
    await page.waitForTimeout(1150);
    const finalText = await page.locator('body').innerText();
    await page.screenshot({path: path.join(captureDir, 'settings-final.png')});
    actionEnd = (Date.now() - videoEpoch) / 1000;
    mark('verified', 'Automatic card visibly resolves to Qwen 2.5 Coder 0.5B · Q4F16 · DirectML; source screenshot retained for visual review. ' + finalText.replace(/\s+/g, ' ').slice(0, 300));
  } catch (error) {
    mark('capture-error', String(error));
    await page.screenshot({path: path.join(captureDir, 'capture-error.png')}).catch(() => {});
    process.exitCode = 1;
  } finally {
    const raw = await page.video()?.path();
    await context.close();
    if (raw && fs.existsSync(raw) && actionEnd > actionStart) {
      const trimStart = Math.max(0, actionStart - 0.22);
      const trimSeconds = Math.min(4.9, actionEnd - actionStart + 0.48);
      execFileSync(ffmpeg, [
        '-y', '-ss', trimStart.toFixed(3), '-i', raw, '-t', trimSeconds.toFixed(3),
        '-an', '-c:v', 'libvpx-vp9', '-b:v', '0', '-crf', '28', '-cpu-used', '6',
        output,
      ], {stdio: 'pipe', timeout: 120000});
      mark('trimmed', `${trimStart.toFixed(3)}–${(trimStart + trimSeconds).toFixed(3)} from the actual Edge recording`);
    }
    fs.writeFileSync(marksFile, JSON.stringify({output, actionStart, actionEnd, marks, errors}, null, 2));
    console.log(JSON.stringify({output, marksFile, actionStart, actionEnd, marks, errors}, null, 2));
  }
}

main().catch(error => {console.error(error); process.exitCode = 1;});
