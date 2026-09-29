const { chromium } = require('playwright');
(async () => {
  const mode = process.argv[2] || 'explain';
  const action = mode === 'createCubic' ? 'createVisual' : mode;
  const prompt = mode === 'createCubic'
    ? 'Selected content: x^3 - x^2 + 1 = y\nInstruction: Make this exact equation a graph'
    : action === 'createVisual'
    ? 'Make 3x^2 - 1 = y a graph'
    : action === 'animateInk'
      ? 'animate this'
      : 'Explain why 3x + 5 = 20 means x = 5 in two sentences.';
  const browser = await chromium.launchPersistentContext('build/.edge-ai-probe', { channel: 'msedge', headless: true });
  const page = await browser.newPage();
  page.on('console', m => { if (m.text().startsWith('AI probe:')) console.log(m.text()); });
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('requestfailed', r => errors.push(`${r.url()} ${r.failure()?.errorText}`));
  await page.goto('http://127.0.0.1:8080', { waitUntil: 'domcontentloaded' });
  if(action==='adapter') {
    console.log(await page.evaluate(async()=>{const adapter=await navigator.gpu?.requestAdapter();return JSON.stringify({available:!!adapter,fallback:adapter?.isFallbackAdapter,info:adapter?.info});}));
    await browser.close();return;
  }
  const result = await page.evaluate(async ({ action, prompt, mode }) => {
    const canvas=document.createElement('canvas');canvas.width=400;canvas.height=220;
    const ctx=canvas.getContext('2d');ctx.fillStyle='white';ctx.fillRect(0,0,400,220);ctx.fillStyle='#212c2c';ctx.strokeStyle='#212c2c';ctx.lineWidth=4;
    let selection={};
    if(action==='animateInk'){
      ctx.beginPath();ctx.arc(115,160,26,0,Math.PI*2);ctx.stroke();
      ctx.beginPath();ctx.moveTo(116,138);ctx.lineTo(225,22);ctx.stroke();
      ctx.beginPath();ctx.arc(225,22,2,0,Math.PI*2);ctx.fill();
      selection={strokes:[
        {id:'stroke_bob',bounds:[89,134,141,186],points:[[115,134],[141,160],[115,186],[89,160],[115,134]]},
        {id:'stroke_rod',bounds:[116,22,225,138],points:[[116,138],[150,100],[190,58],[225,22]]},
        {id:'stroke_pivot',bounds:[223,20,227,24],points:[[225,22]]},
      ]};
    } else if(action==='createVisual'){
      const equation=mode==='createCubic'?'x³ - x² + 1 = y':'3x² - 1 = y';
      const plain=mode==='createCubic'?'x^3 - x^2 + 1 = y':'3x^2 - 1 = y';
      ctx.font='28px Arial';ctx.fillText(equation,40,110);
      selection={objects:[{id:'text_abc',kind:'text',text:plain,bounds:[30,70,350,125]}]};
    }
    if(Object.keys(selection).length)selection.image=canvas.toDataURL('image/png');
    let status = '';
    const timer = setInterval(() => {status = window.InkMindBrowserAI.status();console.log('AI probe: '+status);}, 15000);
    try {
      return { output: await Promise.race([
        window.InkMindBrowserAI.generate(action, prompt, JSON.stringify(selection), 'qwen-2.5-coder-0.5b', 'Auto'),
        new Promise((_, reject) => setTimeout(() => reject(new Error(`Probe limit. ${status}`)), 600000)),
      ]), status: window.InkMindBrowserAI.status() };
    } catch (e) { return { error: String(e), status: window.InkMindBrowserAI.status() }; }
    finally { clearInterval(timer); }
  }, { action, prompt, mode });
  console.log(JSON.stringify({ result: { ...result, output: result.output?.slice(0, 600), tail: result.output?.slice(-1000), outputLength: result.output?.length }, errors: errors.slice(0, 15) }, null, 2));
  await browser.close();
})().catch(e => { console.error(e); process.exitCode = 1; });
