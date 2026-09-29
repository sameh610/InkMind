const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text());
  });

  await page.goto('http://127.0.0.1:8080', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000);
  const initialText = await page.locator('body').innerText();
  console.log('INITIAL', initialText.slice(0, 700));
  const back = page.getByRole('button', { name: 'Back to library' });
  if (await back.count()) await back.click();
  await page.getByRole('button', { name: 'New notebook' }).click({ timeout: 10000 });
  await page.getByRole('button', { name: 'Create notebook' }).click();
  await page.getByRole('button', { name: 'Add text' }).click();
  await page.getByRole('textbox').last().fill('3x^2 - 1 = y');
  await page.getByRole('button', { name: 'Done' }).click();

  await page.evaluate(() => {
    window.InkMindBrowserAI.generate = async (action, text, selection) => {
      window.__probeSelection = { action, text, selection: JSON.parse(selection) };
      return window.InkMindBrowserAI.compile(
        'export default function Visual() { const a = state(3); return <App title="y = 3x² − 1"><Graph a={a}/><Controls><Slider label="x² coefficient" value={a} min={-5} max={5}/></Controls></App>; }',
      );
    };
  });

  await page.getByRole('button', { name: /Choose how AI should make it alive/ }).click();
  await page.getByRole('menuitem', { name: /Create a new visual/ }).click();
  await page.getByRole('textbox').last().fill('Graph this exact equation');
  await page.getByRole('button', { name: 'Done' }).click();
  await page.waitForFunction(() => !!window.__probeSelection, { timeout: 15000 });

  const data = await page.evaluate(() => {
    const { action, text, selection } = window.__probeSelection;
    return {
      action,
      text,
      objects: selection.objects?.map((object) => ({ kind: object.kind, text: object.text })),
      image: selection.image?.startsWith('data:image/png;base64,'),
      imageBytes: selection.image?.length,
    };
  });
  console.log(JSON.stringify({ data, errors }, null, 2));
  if (
    data.action !== 'createVisual' ||
    !data.image ||
    !data.objects?.some((object) => object.text.includes('3x^2 - 1 = y')) ||
    errors.length
  ) process.exitCode = 1;
  await browser.close();
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
