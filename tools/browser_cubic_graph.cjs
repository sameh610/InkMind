const {chromium}=require('playwright');
(async()=>{
  const browser=await chromium.launch({channel:'msedge',headless:true});
  const page=await browser.newPage({viewport:{width:1440,height:1000}});
  page.setDefaultTimeout(20000);
  const errors=[];
  page.on('pageerror',error=>errors.push(error.message));
  page.on('console',message=>{if(message.type()==='error')errors.push(message.text())});
  await page.goto('http://127.0.0.1:8080/?v=cubic-browser-1',{waitUntil:'domcontentloaded'});
  await page.waitForTimeout(5000);

  // Pin the compact cached model so this regression test is fast and repeatable.
  await page.getByRole('button',{name:'Notebook settings'}).click();
  await page.getByRole('menuitem',{name:'Settings & AI models'}).click();
  await page.getByRole('button',{name:'Use model'}).first().click();
  await page.getByRole('button',{name:'Close settings'}).click();

  await page.getByRole('button',{name:'Add text'}).click();
  await page.getByRole('textbox').last().fill('x^3 - x^2 + 1 = y');
  await page.getByRole('button',{name:'Done'}).click();
  await page.getByRole('button',{name:/Choose how AI should make it alive/}).click();
  await page.getByRole('menuitem',{name:/Create a new visual/}).click();
  await page.getByRole('textbox').last().fill('Make this exact equation a graph');
  await page.getByRole('button',{name:'Done'}).click();
  await page.getByText('y = x³ − x² + 1',{exact:true}).waitFor({timeout:180000});
  await page.screenshot({path:'edge-cubic-graph.png',fullPage:true});
  const body=await page.locator('body').innerText();
  console.log(JSON.stringify({
    heading:body.includes('y = x³ − x² + 1'),
    cubic:body.includes('x^3 coefficient'),
    quadratic:body.includes('x^2 coefficient'),
    linear:body.includes('x^1 coefficient'),
    constant:body.includes('constant'),
    selected:body.includes('Qwen 2.5 Coder 0.5B')&&body.includes('Q4F16'),
    errors:errors.slice(0,10),
    text:body.slice(-1600),
  },null,2));
  await browser.close();
})().catch(error=>{console.error(error);process.exitCode=1});
