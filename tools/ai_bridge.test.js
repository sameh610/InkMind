import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
const source=readFileSync(new URL('../web/inkmind_ai.js',import.meta.url),'utf8');

function bridge({native=true,fail=false}={}) {
  let workers=0;
  const context={window:{},navigator:{},AbortController,setTimeout,clearTimeout,setInterval,clearInterval,console,
    fetch:async url=>url.endsWith('/health')
      ? {json:async()=>({ok:native})}
      : {ok:!fail,json:async()=>fail?{error:'Could not validate selected ink'}:{text:'Verified response',model:'Actual model',quant:'Q4',backend:'CPU'}},
    Worker:class {
      constructor(){workers++;}
      postMessage(data){queueMicrotask(()=>this.onmessage({data:{type:'error',id:data.id,message:'Invalid output'}}));}
      terminate(){}
    }};
  vm.runInNewContext(source,context);
  return {api:context.window.InkMindBrowserAI,workers:()=>workers};
}
test('native validation failure does not download another model or fabricate an answer',async()=>{
  const b=bridge({fail:true}); await b.api.probeNative();
  await assert.rejects(b.api.generate('animateInk','animate this'),/validate selected ink/);
  assert.equal(b.workers(),0);
});
test('browser validation failure is visible, never an emergency placeholder',async()=>{
  const b=bridge({native:false}); await b.api.probeNative();
  await assert.rejects(b.api.generate('createVisual','graph'),/Invalid output/);
});
test('selector reports actual loaded model, quant and CPU fallback backend',async()=>{
  const b=bridge(); await b.api.probeNative();
  assert.equal(await b.api.generate('explain','test'),'Verified response');
  assert.equal(b.api.selection(),'Actual model · Q4 · CPU');
});
