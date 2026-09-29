const {chromium}=require('playwright');
(async()=>{
  const browser=await chromium.launch({channel:'msedge',headless:true});
  const page=await browser.newPage();
  const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8080/?v=native-directml-1',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>window.InkMindBrowserAI);
  await page.waitForTimeout(1000);
  const result=await page.evaluate(async()=>{
    const connected=await window.InkMindBrowserAI.probeNative();
    const answer=await window.InkMindBrowserAI.generate('explain','Explain y = 3x^2 - 1 in one sentence.','{}','qwen-2.5-coder-0.5b','Q4F16');
    return {connected,answer,status:window.InkMindBrowserAI.status(),selection:window.InkMindBrowserAI.selection('Automatic','Auto')};
  });
  console.log(JSON.stringify({...result,errors},null,2));
  if(!result.connected||!result.answer.trim()||!result.status.includes('DirectML')||errors.length)process.exitCode=1;
  await browser.close();
})().catch(e=>{console.error(e);process.exitCode=1});
