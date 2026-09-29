const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error') errors.push(message.text());
  });
  await page.goto('http://127.0.0.1:8080', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(5000);
  console.log('TITLE', await page.title());
  console.log('TEXT', (await page.locator('body').innerText()).slice(0, 2500));
  console.log('ERRORS', errors.slice(0, 10));
  console.log('MAKE_ALIVE_VISIBLE', (await page.locator('body').innerText()).includes('Make Alive'));
  await page.screenshot({ path: 'edge-home.png', fullPage: true });
  await page.getByRole('button',{name:'Notebook settings'}).click();
  await page.getByRole('menuitem',{name:'Settings & AI models'}).click();
  await page.getByText('Automatic model preference').first().waitFor();
  console.log('PERFORMANCE_CONTROL',true);
  await page.screenshot({path:'edge-routing-desktop.png',fullPage:true});
  await page.setViewportSize({width:390,height:844});
  await page.waitForTimeout(500);
  await page.getByRole('button',{name:'Close settings'}).click();
  await page.getByRole('button',{name:'Notebook settings'}).waitFor();
  console.log('PHONE_CLOSE_SETTINGS',true);
  await page.screenshot({path:'edge-routing-phone.png',fullPage:true});
  if(errors.length) process.exitCode=1;
  await browser.close();
})().catch(error => { console.error(error); process.exitCode = 1; });
