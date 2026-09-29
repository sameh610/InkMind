const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({channel:'msedge',headless:true});
  const page=await browser.newPage({viewport:{width:1440,height:900}});
  const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  await page.goto('http://127.0.0.1:8080',{waitUntil:'domcontentloaded'});
  await page.waitForTimeout(4000);
  console.log('BEFORE', (await page.locator('body').innerText()).slice(0,600));
  await page.getByRole('button',{name:'Notebook settings'}).click();
  await page.screenshot({path:'edge-inkscript-menu.png',fullPage:true});
  console.log('MENU', (await page.locator('body').innerText()).slice(-900));
  await page.mouse.click(1330,40);
  await page.waitForTimeout(2500);
  console.log('DIALOG', (await page.locator('body').innerText()).slice(-1000));
  console.log('SLIDERS',await page.getByRole('slider').count());
  await page.screenshot({path:'edge-inkscript-playground.png',fullPage:true});
  await page.mouse.click(1116,770);
  await page.waitForTimeout(1000);
  console.log('ADDED', (await page.locator('body').innerText()).includes('Pendulum Lab'));
  console.log('ERRORS',errors.slice(0,12));
  await browser.close();
})().catch(e=>{console.error(e);process.exitCode=1});

