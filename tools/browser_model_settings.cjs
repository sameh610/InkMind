const {chromium}=require('playwright');
(async()=>{
  const browser=await chromium.launch({channel:'msedge',headless:true});
  const page=await browser.newPage({viewport:{width:1440,height:1000}});
  page.setDefaultTimeout(10000);
  const errors=[];
  page.on('pageerror',error=>errors.push(error.message));
  page.on('console',message=>{if(message.type()==='error')errors.push(message.text())});
  await page.goto('http://127.0.0.1:8080/?v=models-and-cubic-2',{waitUntil:'domcontentloaded'});
  await page.waitForTimeout(5000);
  await page.getByRole('button',{name:'Notebook settings'}).click();
  await page.getByRole('menuitem',{name:'Settings & AI models'}).click();
  await page.waitForTimeout(500);
  const initial=await page.locator('body').innerText();
  await page.screenshot({path:'edge-model-settings-top.png',fullPage:true});
  await page.mouse.move(720,500);
  await page.mouse.wheel(0,600);
  await page.waitForTimeout(300);
  const middle=await page.locator('body').innerText();
  await page.screenshot({path:'edge-model-settings-middle.png',fullPage:true});
  await page.mouse.wheel(0,900);
  await page.waitForTimeout(500);
  const all=await page.locator('body').innerText();
  await page.screenshot({path:'edge-model-settings.png',fullPage:true});
  console.log(JSON.stringify({
    resolved:/AI Engine: .* · (QAT \/ mobile-optimized|Q4F16|Q4|Q8|FP16) · (WebGPU|WASM|Native GPU · DirectML)/.test(initial),
    automatic:initial.includes('Resolved now:'),
    gemmaE2:middle.includes('Gemma 4 E2B'),
    gemmaE4:middle.includes('Gemma 4 E4B'),
    spark17:all.includes('Spark-X2.5 1.7B'),
    spark4:all.includes('Spark-X2.5 4B'),
    bonsai:all.includes('Ternary Bonsai 2 27B'),
    quant:all.includes('Quantization'),
    gemmaQat:all.includes('QAT / mobile-optimized'),
    errors:errors.slice(0,10),
    initial:initial.slice(0,1800),
    text:all.slice(0,2600),
  },null,2));
  await browser.close();
})().catch(error=>{console.error(error);process.exitCode=1});
