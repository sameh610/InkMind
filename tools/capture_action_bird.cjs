const fs=require('node:fs');
const path=require('node:path');
const {chromium}=require('playwright');
const root=path.resolve(__dirname,'..');
const url=process.env.INKMIND_DEMO_URL||'http://127.0.0.1:8082';
const profile=path.join(root,'build',`.edge-action-bird-${Date.now()}`);
const temp=path.join(root,'demo/video/action-bird-temp');
const output=path.join(root,'demo/video/public/footage/inkmind-action-bird.webm');
const marksFile=path.join(root,'demo/video/action-bird-marks.json');
const marks=[];const start=Date.now();
const mark=(name,detail='')=>{const item={name,seconds:Number(((Date.now()-start)/1000).toFixed(2)),detail};marks.push(item);console.log(JSON.stringify(item))};
async function tap(locator) {
  await locator.first().waitFor({timeout:20000});
  const box=await locator.first().boundingBox();
  if(box) await locator.page().mouse.click(box.x+box.width/2,box.y+box.height/2);
  else await locator.first().evaluate(el=>el.click());
}
async function main(){
  fs.mkdirSync(temp,{recursive:true});
  const context=await chromium.launchPersistentContext(profile,{
    channel:'msedge',headless:true,viewport:{width:1600,height:900},deviceScaleFactor:1,
    recordVideo:{dir:temp,size:{width:1600,height:900}},
  });
  const page=context.pages()[0]||await context.newPage();
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  try{
    await page.addInitScript(()=>{
      window.addEventListener('DOMContentLoaded',()=>{
        const dot=document.createElement('div');
        dot.style.cssText='position:fixed;left:0;top:0;width:18px;height:18px;border:2px solid #c46a47;border-radius:50%;background:#c46a4733;box-shadow:0 0 0 4px #c46a4720;pointer-events:none;z-index:2147483647;transform:translate(-50px,-50px)';
        document.body.append(dot);
        window.addEventListener('pointermove',e=>dot.style.transform=`translate(${e.clientX-9}px,${e.clientY-9}px)`,{passive:true});
      });
    });
    await page.goto(url,{waitUntil:'domcontentloaded'});
    await page.waitForTimeout(2000);
    const back=page.getByRole('button',{name:'Back to library'});
    if(await back.count()) await tap(back);
    await tap(page.getByRole('button',{name:'Open InkMind Demo'}));
    const next=page.getByRole('button',{name:'Next page'});
    await next.waitFor({timeout:20000});
    for(let i=0;i<3;i++) await tap(next);
    await page.getByText('04 / GENERALITY',{exact:false}).first().waitFor({timeout:15000});
    mark('bird-page','Original vector bird visible on fourth demo page');
    await page.waitForTimeout(550);
    await tap(page.getByRole('button',{name:'Lasso / select'}));
    await page.mouse.move(627,318);await page.mouse.down();
    for(const [x,y] of [[938,318],[938,535],[627,535],[627,318]])await page.mouse.move(x,y,{steps:14});
    await page.mouse.up();await page.waitForTimeout(400);
    const selected=await page.getByRole('button',{name:'Selection options'}).count()>0;
    mark('bird-selected',String(selected));
    if(!selected)throw Error('The bird strokes were not selected');
    await tap(page.getByRole('button',{name:/Choose how AI should make it alive/}));
    await tap(page.getByRole('menuitem',{name:/Animate my ink/i}));
    const field=page.getByRole('textbox').last();
    await field.waitFor({timeout:10000});
    await field.fill('Make this bird fly across the page, turn around, fly back, and repeat. Keep the original bird strokes together; flap its wings.');
    mark('instruction','Fly across, turn back, original strokes, flap wings');
    await tap(page.getByRole('button',{name:'Done'}));
    mark('animate-execute','Animate Ink submitted through the real app');
    const play=page.getByRole('button',{name:'Play motion'});
    await play.waitFor({timeout:180000});
    mark('bird-ready','Original selected bird got playable motion');
    await tap(play);
    mark('bird-takeoff','Bird motion playback started');
    await page.waitForTimeout(5200);
    await page.screenshot({path:path.join(temp,'bird-moving.png')});
  }catch(e){
    mark('capture-error',String(e));
    await page.screenshot({path:path.join(temp,'error.png')}).catch(()=>{});
    process.exitCode=1;
  }finally{
    const video=page.video();
    await context.close();
    if(!process.exitCode&&video)fs.copyFileSync(await video.path(),output);
    fs.writeFileSync(marksFile,JSON.stringify({marks,errors},null,2));
  }
}
main().catch(e=>{console.error(e);process.exitCode=1});
