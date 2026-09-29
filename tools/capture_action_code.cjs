const fs=require('node:fs');
const path=require('node:path');
const {chromium}=require('playwright');
const root=path.resolve(__dirname,'..');
const profile=path.join(root,'build','.edge-action-ink-capture');
const temp=path.join(root,'demo/video/action-code-temp');
const output=path.join(root,'demo/video/public/footage/inkmind-action-code.webm');
const marksFile=path.join(root,'demo/video/action-code-marks.json');
const marks=[];const start=Date.now();
const mark=(name,detail='')=>{const item={name,seconds:Number(((Date.now()-start)/1000).toFixed(2)),detail};marks.push(item);console.log(JSON.stringify(item))};
async function tap(locator){
  await locator.first().waitFor({timeout:20000});
  const box=await locator.first().boundingBox();
  if(box)await locator.page().mouse.click(box.x+box.width/2,box.y+box.height/2);
  else await locator.first().evaluate(el=>el.click());
}
async function main(){
  fs.mkdirSync(temp,{recursive:true});
  const context=await chromium.launchPersistentContext(profile,{channel:'msedge',headless:true,viewport:{width:1600,height:900},deviceScaleFactor:1,recordVideo:{dir:temp,size:{width:1600,height:900}}});
  const page=context.pages()[0]||await context.newPage();
  try{
    await page.addInitScript(()=>{
      window.addEventListener('DOMContentLoaded',()=>{
        const dot=document.createElement('div');dot.style.cssText='position:fixed;left:0;top:0;width:18px;height:18px;border:2px solid #c46a47;border-radius:50%;background:#c46a4733;pointer-events:none;z-index:2147483647;transform:translate(-50px,-50px)';
        document.body.append(dot);
        window.addEventListener('pointermove',e=>dot.style.transform=`translate(${e.clientX-9}px,${e.clientY-9}px)`,{passive:true});
      });
    });
    await page.goto('http://127.0.0.1:8080',{waitUntil:'domcontentloaded'});
    await page.waitForTimeout(1600);
    const back=page.getByRole('button',{name:'Back to library'});
    if(await back.count())await tap(back);
    await tap(page.getByRole('button',{name:'Open InkMind Demo'}));
    await page.getByRole('button',{name:'Edit InkScript'}).waitFor({timeout:16000});
    mark('motion-rig','Saved generated pendulum source is available');
    await page.waitForTimeout(500);
    await tap(page.getByRole('button',{name:'Edit InkScript'}));
    mark('code-open','Real app InkScript editor opened');
    await page.waitForTimeout(3300);
    await page.screenshot({path:path.join(temp,'code.png')});
  }catch(e){mark('capture-error',String(e));await page.screenshot({path:path.join(temp,'error.png')}).catch(()=>{});process.exitCode=1}
  finally{const video=page.video();await context.close();if(video)fs.copyFileSync(await video.path(),output);fs.writeFileSync(marksFile,JSON.stringify({marks},null,2))}
}
main().catch(e=>{console.error(e);process.exitCode=1});
