const fs=require('node:fs');
const path=require('node:path');
const {chromium}=require('playwright');
const root=path.resolve(__dirname,'..');
const mode=process.argv[2]||'billing';
const runs=Number(process.argv[3]||1);
const folder=path.join(root,'demo/video/launch-v3');
fs.mkdirSync(folder,{recursive:true});
const url=process.env.INKMIND_DEMO_URL||'http://127.0.0.1:8084';
const report=[];
async function tap(page,locator){
  await locator.first().waitFor({timeout:30000});
  let b=await locator.first().boundingBox();
  if(!b)throw Error('No visible action bounds');
  // Wait out popup/route motion. CanvasKit semantics can overlap even when
  // the painted control is clickable, so use the settled screen position.
  for(let i=0;i<8;i++){
    await page.waitForTimeout(100);
    const next=await locator.first().boundingBox();
    if(!next)continue;
    const settled=Math.abs(next.x-b.x)+Math.abs(next.y-b.y)+Math.abs(next.width-b.width)+Math.abs(next.height-b.height)<.5;
    b=next;if(settled&&i>=2)break;
  }
  await page.mouse.move(b.x+b.width/2,b.y+b.height/2,{steps:8});
  await page.mouse.click(b.x+b.width/2,b.y+b.height/2);
}
async function bookData(page){
  await page.waitForTimeout(700);
  return page.evaluate(()=>new Promise((resolve,reject)=>{
    const request=indexedDB.open('inkmind-v1');request.onerror=()=>reject(request.error);
    request.onsuccess=()=>{const db=request.result;const tx=db.transaction('notebooks','readonly');const get=tx.objectStore('notebooks').getAll();get.onsuccess=()=>{resolve(get.result.find(b=>b.title==='InkMind Demo'));db.close();};get.onerror=()=>reject(get.error);};
  }));
}
async function select(page,rect,mark){
  await tap(page,page.getByRole('button',{name:'Lasso / select'}));mark('select-start');
  const [x,y,w,h]=rect;await page.mouse.move(x,y);await page.mouse.down();
  for(const p of [[x+w,y],[x+w,y+h],[x,y+h],[x,y]])await page.mouse.move(...p,{steps:12});
  await page.mouse.up();await page.waitForTimeout(250);
  await page.getByRole('button',{name:'Selection options'}).waitFor({timeout:5000});mark('selected');
}
async function instruction(page,type,text,mark){
  await tap(page,page.getByRole('button',{name:/Choose how AI should make it alive/}));mark('make-alive');
  await tap(page,page.getByRole('menuitem',{name:type==='ink'?/Animate my ink/i:/Create a new visual/i}));mark('command');
  const field=page.getByRole('textbox').last();await field.fill('');await field.pressSequentially(text,{delay:9});
  mark('instruction');await page.waitForTimeout(320);await tap(page,page.getByRole('button',{name:'Done'}));mark('execute');
}
async function capture(browser,run){
  const context=await browser.newContext({viewport:{width:1600,height:900},deviceScaleFactor:1,
    ...(run===0?{recordVideo:{dir:folder,size:{width:1600,height:900}}}:{})});
  const page=await context.newPage(),start=Date.now(),marks=[],errors=[];
  const mark=(name,detail)=>{const entry={name,seconds:Number(((Date.now()-start)/1000).toFixed(3)),detail};marks.push(entry);console.log(JSON.stringify({mode,run:run+1,...entry}));};
  page.on('pageerror',e=>errors.push(e.message));
  page.on('request',request=>{
    if(request.url().includes('8787/generate'))try {
      const body=request.postDataJSON(); const selection=typeof body.selection==='string'?JSON.parse(body.selection):body.selection;
      fs.writeFileSync(path.join(folder,`${mode}-${run+1}-request.json`),JSON.stringify(body,null,2));
      if(selection?.image?.startsWith('data:image/png;base64,'))fs.writeFileSync(path.join(folder,`${mode}-selection.png`),Buffer.from(selection.image.split(',')[1],'base64'));
    }catch(_){}
  });
  page.on('response',async response=>{
    if(response.url().includes('8787') && response.request().method()==='POST') {
      try { const result=await response.json();fs.writeFileSync(path.join(folder,`${mode}-native-response.json`),JSON.stringify(result,null,2)); } catch (_) {}
    }
  });
  if(mode==='billing') page.on('response',async response=>{
    if(response.url().includes('revenuecat')) {
      try { const data=await response.json(); if(data.subscriber || data.customer_info || data.entitlements) fs.writeFileSync(path.join(folder,'billing-customer.json'),JSON.stringify(data,null,2)); } catch (_) {}
    }
  });
  await page.addInitScript(()=>window.addEventListener('DOMContentLoaded',()=>{
    const dot=document.createElement('div');dot.style.cssText='position:fixed;width:18px;height:18px;border:2px solid #bd6744;border-radius:50%;background:#bd674426;box-shadow:0 0 0 4px #bd674416;z-index:2147483647;pointer-events:none;left:-50px;top:-50px;';document.body.append(dot);
    window.addEventListener('pointermove',e=>{dot.style.left=`${e.clientX-9}px`;dot.style.top=`${e.clientY-9}px`;dot.style.opacity='1';clearTimeout(window.pointerHide);window.pointerHide=setTimeout(()=>dot.style.opacity='0',850);});
  }));
  let success=false,evidence={};
  try{
    await page.goto(url+'/?native-ai=1',{waitUntil:'domcontentloaded'});
    await page.getByRole('button',{name:'Next page'}).waitFor({timeout:60000});
    mark('ready');
    const pages={pendulum:0,debug:1,graph:2,bird:3,flower:4,projectile:5};
    for(let i=0;i<(pages[mode]||0);i++)await tap(page,page.getByRole('button',{name:'Next page'}));
    await page.waitForTimeout(400);mark('input');
    if(mode==='billing'){
      await tap(page,page.getByRole('button',{name:'Notebook settings'}));
      await tap(page,page.getByRole('menuitem',{name:'InkMind Pro'}));mark('paywall');
      await page.screenshot({path:path.join(folder,'billing-before.png')});
      console.log((await page.locator('body').innerText()).slice(-2600));
      await page.mouse.move(720,603,{steps:12});await page.mouse.click(720,603);mark('annual');
      await tap(page,page.getByRole('button',{name:'Continue with Annual'}));mark('checkout');
      await page.waitForTimeout(2200);
      console.log('CHECKOUT '+(await page.locator('body').innerText()).slice(-3500));
      await page.screenshot({path:path.join(folder,'billing-checkout.png')});
      const purchase=page.getByRole('button',{name:'Test valid purchase',exact:true});
      await tap(page,purchase);
      await page.getByText('InkMind Pro is active.',{exact:true}).waitFor({timeout:45000});mark('entitlement');
      await page.waitForTimeout(900);
      await page.screenshot({path:path.join(folder,'billing-success.png')});
      evidence={entitlement:'inkmind_pro',source:'RevenueCat SDK Test Store',text:(await page.locator('body').innerText()).slice(-1100)};
    }else if(mode==='debug'){
      await select(page,[500,225,340,170],mark);
      await tap(page,page.getByRole('button',{name:'Debug',exact:true}));mark('execute');
      await page.getByRole('button',{name:'Replay reasoning'}).waitFor({timeout:240000});mark('result');
      await page.waitForTimeout(3700);
      const book=await bookData(page),obj=book.pages[1].objects.find(o=>o.kind==='debug');
      if(!obj||obj.data.firstError!==1||!obj.data.corrected.includes('x = 5')||!obj.data.strokeHistory?.length)throw Error('Debug did not preserve stroke history and identify the first divergence');
      evidence={firstError:obj.data.firstError,corrected:obj.data.corrected,recordedStrokes:obj.data.strokeHistory.length};
      await tap(page,page.getByRole('button',{name:'Replay reasoning'}));mark('replay');await page.waitForTimeout(3800);
    }else if(mode==='graph'||mode==='projectile'){
      await select(page,[510,248,330,90],mark);
      await instruction(page,'visual',mode==='graph'?'Graph this exact equation with an interactive coefficient slider.':'Make an interactive projectile simulation using the selected velocity and angle.',mark);
      const slider=page.getByRole('slider').first();await slider.waitFor({timeout:240000});mark('result');
      await page.waitForTimeout(500);
      const before=await slider.getAttribute('aria-valuetext');
      const b=await slider.boundingBox();
      const track=mode==='graph'?{x:592,y:611,width:398}:{x:b.x,y:b.y+b.height/2,width:b.width};
      await page.mouse.move(track.x+track.width*.8,track.y);await page.mouse.down();
      await page.mouse.move(track.x+track.width*.95,track.y,{steps:18});mark('slider-positive');
      await page.mouse.move(track.x+track.width*.2,track.y,{steps:28});await page.mouse.up();mark('slider-negative');await page.waitForTimeout(650);
      const after=await slider.getAttribute('aria-valuetext');
      const book=await bookData(page),obj=book.pages[pages[mode]].objects.find(o=>o.kind==='visual');
      if(!obj?.data?.ir||before===after||(mode==='graph'&&parseFloat(after)>=50))throw Error('Visual or interactive control failed');
      evidence={before,after,source:obj.data.script};
    }else{
      const rect=mode==='pendulum'?[723,228,170,310]:mode==='flower'?[672,270,230,280]:[622,315,320,220];
      await select(page,rect,mark);
      const prompt=mode==='pendulum'?'Swing like a pendulum. Keep the pivot fixed. Include gravity control.':mode==='bird'?'Make this bird fly across, turn back and repeat. Flap its original wing.':'Make this flower bend and sway in the wind. Keep its roots anchored.';
      await instruction(page,'ink',prompt,mark);
      await page.getByRole('button',{name:'Play motion'}).waitFor({timeout:315000});mark('result');
      await tap(page,page.getByRole('button',{name:'Play motion'}));mark('motion');await page.waitForTimeout(1200);
      const book=await bookData(page),objects=book.pages[pages[mode]].objects;
      const obj=objects.find(o=>o.data?.ir?.mode==='animateInk');
      if(!obj)throw Error('No executable original-stroke InkScript');
      const ids=book.pages[pages[mode]].strokes.map(s=>s.id);
      if(!obj.data.ir.drawings.every(s=>ids.includes(s.id)))throw Error('Animation replaced stroke identity');
      if(mode==='flower'&&!obj.data.ir.animations.some(a=>a.property==='bend'))throw Error('Wind did not bend original strokes');
      evidence={drawings:obj.data.ir.drawings.length,source:obj.data.source,properties:obj.data.ir.animations.map(a=>a.property)};
      if(mode==='pendulum'){
        const moon=await page.getByText('Moon',{exact:true}).first().boundingBox();
        await page.mouse.move(moon.x+moon.width/2,moon.y+moon.height/2);await page.mouse.down();mark('moon-pickup');
        await page.waitForTimeout(160);await page.mouse.move(790,490,{steps:38});mark('moon-approach');await page.mouse.up();mark('moon-drop');
        await page.waitForTimeout(300);const gravity=await page.getByRole('slider').last().getAttribute('aria-valuetext');
        if(!(parseFloat(gravity)>=7&&parseFloat(gravity)<=9))throw Error('Moon did not change gravity: '+gravity);
        evidence.gravity=gravity;
      }
      await page.waitForTimeout(run===0?5000:700);
    }
    await page.screenshot({path:path.join(folder,`${mode}-${run+1}-result.png`)});
    success=true;mark('verified',evidence);
  }catch(e){mark('failed',String(e));evidence={error:String(e),body:(await page.locator('body').innerText()).slice(-2000)};await page.screenshot({path:path.join(folder,`${mode}-${run+1}-error.png`)}).catch(()=>{});}
  finally{
    const video=page.video();await context.close();
    if(video&&success)fs.copyFileSync(await video.path(),path.join(root,'demo/video/public/footage',`v3-${mode}.webm`));
    report.push({run:run+1,success,marks,errors,evidence});fs.writeFileSync(path.join(folder,`${mode}-report.json`),JSON.stringify(report,null,2));
  }
  return success;
}
(async()=>{
  const browser=await chromium.launch({channel:'msedge',headless:true});
  try{for(let i=0;i<runs;i++){if(!await capture(browser,i)){process.exitCode=1;break;}}}
  finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1});
