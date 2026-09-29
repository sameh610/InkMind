const {chromium}=require('playwright');
(async()=>{
  const dark=process.argv.includes('dark');
  const browser=await chromium.launchPersistentContext('build/.edge-ai-probe',{channel:'msedge',headless:true,viewport:{width:1440,height:900}});
  const page=await browser.newPage();
  const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  await page.goto('http://127.0.0.1:8080/?v=exact-graph-4',{waitUntil:'domcontentloaded'});
  await page.waitForTimeout(5000);
  console.log('INITIAL', (await page.locator('body').innerText()).slice(0,700));
  if(dark) {
    await page.getByRole('button',{name:'Settings'}).click();
    const darkPaper=page.getByRole('switch',{name:'Dark paper'});
    if(!(await darkPaper.isChecked())) await darkPaper.click();
    for(let i=0;i<5;i++) {
      const close=page.getByRole('button',{name:'Close settings'});
      if(!(await close.count())) break;
      await close.last().click();
    }
    console.log('AFTER SETTINGS', (await page.locator('body').innerText()).slice(0,500));
  }
  if(await page.getByRole('button',{name:'New notebook'}).count()) {
    await page.getByRole('button',{name:'New notebook'}).click();
    const titleInput=page.getByRole('textbox').last();
    if(await titleInput.count()) await titleInput.fill('Graph verification');
    await page.getByRole('button',{name:'Create notebook'}).click();
  }
  console.log('AFTER CREATE', (await page.locator('body').innerText()).slice(0,800));
  await page.getByRole('button',{name:'Add text'}).waitFor({timeout:20000});
  await page.getByRole('button',{name:'Add text'}).click();
  await page.getByRole('textbox').last().fill('3x^2 - 1 = y');
  await page.getByRole('button',{name:'Done'}).click();
  await page.getByRole('button',{name:/Choose how AI should make it alive/}).click();
  await page.getByRole('menuitem',{name:/Create a new visual/}).click();
  await page.getByRole('textbox').last().fill('Make it a graph and keep every coefficient exactly as written');
  await page.getByRole('button',{name:'Done'}).click();
  await page.getByText('y = 3x² − 1',{exact:true}).waitFor({timeout:180000});
  await page.screenshot({path:'edge-exact-graph.png',fullPage:true});
  const body=await page.locator('body').innerText();
  console.log(JSON.stringify({heading:body.includes('y = 3x² − 1'),value3:body.includes('3.0'),value0:body.includes('0.0'),minus1:body.includes('-1.0'),errors:errors.slice(0,10),text:body.slice(-1200)},null,2));
  await browser.close();
})().catch(e=>{console.error(e);process.exitCode=1});
