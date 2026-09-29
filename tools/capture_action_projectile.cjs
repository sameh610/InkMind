const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require('playwright');

const root = path.resolve(__dirname, '..');
const url = process.env.INKMIND_DEMO_URL || 'http://127.0.0.1:8082';
const profile = path.join(root, 'build', '.edge-action-projectile');
const temp = path.join(root, 'demo/video/action-projectile-temp');
const output = path.join(root, 'demo/video/public/footage/inkmind-action-projectile.webm');
const marksFile = path.join(root, 'demo/video/action-projectile-marks.json');
const marks = [];
const start = Date.now();
const mark = (name, detail='') => {
  const event = {name, seconds: Number(((Date.now()-start)/1000).toFixed(2)), detail};
  marks.push(event); console.log(JSON.stringify(event));
};
async function tap(locator) {
  await locator.first().waitFor({timeout:20000});
  const box = await locator.first().boundingBox();
  if (box) await locator.page().mouse.click(box.x+box.width/2, box.y+box.height/2);
  else await locator.first().evaluate(el=>el.click());
}
async function main() {
  fs.mkdirSync(temp,{recursive:true});
  const context = await chromium.launchPersistentContext(profile,{
    channel:'msedge',headless:true,viewport:{width:1600,height:900},
    deviceScaleFactor:1,recordVideo:{dir:temp,size:{width:1600,height:900}},
  });
  const page=context.pages()[0]||await context.newPage();
  const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  try {
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
    for(let i=0;i<4;i++) await tap(next);
    await page.getByText('Projectile: 20 m/s, 45°',{exact:true}).waitFor({timeout:15000});
    mark('projectile-page','Prepared fifth page shows the actual launch idea');
    await page.waitForTimeout(550);
    await tap(page.getByRole('button',{name:'Lasso / select'}));
    await page.mouse.move(535,250);
    await page.mouse.down();
    for(const [x,y] of [[1025,250],[1025,350],[535,350],[535,250]]) await page.mouse.move(x,y,{steps:15});
    await page.mouse.up();
    await page.waitForTimeout(450);
    if(!(await page.getByRole('button',{name:'Selection options'}).count())) throw Error('Projectile text was not selected');
    mark('selected','Selected the projectile idea with a real lasso');
    await tap(page.getByRole('button',{name:/Choose how AI should make it alive/}));
    await tap(page.getByRole('menuitem',{name:/Create a new visual/i}));
    const field=page.getByRole('textbox').last();
    await field.waitFor({timeout:12000});
    await field.fill('Make an interactive projectile trajectory from the exact selected launch: 20 m/s at 45 degrees. Show live speed and angle controls.');
    mark('instruction','Exact 20 m/s, 45° projectile and live controls');
    await tap(page.getByRole('button',{name:'Done'}));
    mark('generate','New Visual requested through the real app UI');
    const slider=page.getByRole('slider').first();
    await slider.waitFor({timeout:300000});
    await page.waitForTimeout(1400);
    mark('visual-ready',(await page.locator('body').innerText()).slice(-500).replace(/\s+/g,' '));
    await slider.focus();
    for(let i=0;i<4;i++) await slider.press('ArrowRight');
    await page.waitForTimeout(1100);
    mark('control-changed',(await page.locator('body').innerText()).slice(-500).replace(/\s+/g,' '));
    await page.waitForTimeout(750);
  } catch(e) {
    mark('capture-error',String(e));
    await page.screenshot({path:path.join(temp,'error.png')}).catch(()=>{});
    process.exitCode=1;
  } finally {
    const video=page.video();
    await context.close();
    if(video) fs.copyFileSync(await video.path(),output);
    fs.writeFileSync(marksFile,JSON.stringify({marks,errors},null,2));
  }
}
main().catch(e=>{console.error(e);process.exitCode=1});
