import test from 'node:test';
import assert from 'node:assert/strict';
import {routeModel,Capability,modelCacheKey,serialExecutor} from './model_router.js';

test('automatic text stays on a small model even on a large device',()=>{
  assert.equal(routeModel({memoryGB:32}).key,'qwen-2.5-coder-0.5b');
});
test('vision selects a vision model and reserves device memory',()=>{
  assert.equal(routeModel({capability:Capability.vision,memoryGB:8}).key,'gemma-4-e2b');
  assert.throws(()=>routeModel({capability:Capability.vision,memoryGB:4}),/memory budget/);
  assert.throws(()=>routeModel({model:'qwen-2.5-coder-0.5b',capability:Capability.vision}),/cannot perform/);
});
test('explicit selection is respected, unsupported backends are rejected',()=>{
  assert.equal(routeModel({model:'gemma-4-e4b'}).key,'gemma-4-e4b');
  assert.throws(()=>routeModel({model:'spark-x2.5-4b'}),/not installed/);
  assert.throws(()=>routeModel({capability:Capability.image,memoryGB:64}),/No compatible/);
});
test('quality mode chooses largest fitting model, never exceeds estimate',()=>{
  assert.equal(routeModel({memoryGB:8,performance:'quality'}).key,'gemma-4-e2b');
  assert.equal(routeModel({memoryGB:32,performance:'quality'}).key,'gemma-4-e4b');
});
test('cache identity includes backend and structured quantization',()=>{
  const c={modelId:'test',quant:'QAT',backend:'webgpu',dtype:{decoder:'q2f16'}};
  assert.equal(modelCacheKey(c),modelCacheKey({...c,dtype:{decoder:'q2f16'}}));
  assert.notEqual(modelCacheKey(c),modelCacheKey({...c,backend:'wasm'}));
});
test('session work never overlaps and continues after a failed request',async()=>{
  const enqueue=serialExecutor(); let active=0; const order=[];
  const work=n=>enqueue(async()=>{
    assert.equal(active++,0);order.push(n);
    await new Promise(resolve=>setTimeout(resolve,5));active--;
    if(n===1) throw Error('invalid output');
    return n;
  });
  const results=await Promise.allSettled([work(1),work(2),work(3)]);
  assert.deepEqual(order,[1,2,3]);
  assert.equal(results[0].status,'rejected');assert.equal(results[2].value,3);
});
