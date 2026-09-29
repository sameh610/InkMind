const path = require('node:path');
const fs = require('node:fs');
const base = path.resolve(__dirname, '../demo/video');
const {bundle} = require(path.join(base, 'node_modules/@remotion/bundler'));
const {selectComposition, renderStill, openBrowser} = require(path.join(base, 'node_modules/@remotion/renderer'));
(async () => {
  const serveUrl = await bundle({entryPoint:path.join(base,'src/launch_v3_index.tsx'),publicDir:path.join(base,'public')});
  const inputProps={pictureOnly:true,showCaptions:false};
  const browser=await openBrowser('chrome');
  try {
    const composition=await selectComposition({serveUrl,id:'InkMindLaunchV3Clean',inputProps,puppeteerInstance:browser});
    const output=path.join(base,'out/v3-review');fs.mkdirSync(output,{recursive:true});
    const requested=process.argv.slice(2).map(Number);
    for(const seconds of requested.length?requested:[1.4,3,4.7,7,10.8,13,19,21.5,23.5,25.8,28,32,35.5,37.5,40.7,44,47,51.5,57,62,65,68,70,76,79.5]){
      await renderStill({serveUrl,composition,inputProps,puppeteerInstance:browser,frame:Math.round(seconds*30),scale:.5,output:path.join(output,`${seconds.toFixed(1)}.png`)});
      console.log(`Reviewed frame ${seconds}s`);
    }
  } finally {await browser.close({silent:true});}
})().catch(error=>{console.error(error);process.exitCode=1;});
