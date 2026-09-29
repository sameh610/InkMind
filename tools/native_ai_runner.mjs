import { modelProfiles, routeModel, Capability, modelCacheKey, serialExecutor } from './model_router.js';
import http from 'node:http';
import os from 'node:os';
import { createHash } from 'node:crypto';
import { Worker, isMainThread, parentPort } from 'node:worker_threads';
import { verifiedLinearDebug, explicitProjectile } from './grounded_math.js';
import { pipeline, env, AutoProcessor, AutoModelForImageTextToText, RawImage } from '@huggingface/transformers';
import { skillFor } from './ai_skills.js';
import { planSkill, materializePlan, explicitGraphEquation, enrichMotionIntent, recognizePendulum, hasExactTextOnlySelection } from './ai_plan.js';
import { validateAiOutput, guaranteedFallback } from './ai_contract.js';

const HOST='127.0.0.1';
const PORT=Number(process.env.INKMIND_AI_PORT||8787);
const REQUEST_LIMIT=12*1024*1024;


env.allowLocalModels=false;
let generator=null,generatorKey='',vision=null,multimodal=null,visionDmlUnsupported=false;
const state={status:'Ready',model:'',quant:'',backend:'DirectML',progress:0,lastError:''};
const inspectionCache = new Map();

async function inspectCached(selection, action, intent, model, quant) {
  const key = createHash('sha256').update(JSON.stringify([selection.visionContent || selection.image, action, /graph|plot/i.test(intent), model, quant])).digest('hex');
  const cached = inspectionCache.get(key);
  if (cached) { Object.assign(state, cached.state, {status:'Reusing recognition of unchanged ink'}); return cached.text; }
  const text = await inspectSelection(selection, action, intent, model, quant);
  if (text.trim() && !/unclear|unable|cannot identify/i.test(text)) {
    if (inspectionCache.size >= 32) inspectionCache.delete(inspectionCache.keys().next().value);
    inspectionCache.set(key, {text, state:{model:state.model,quant:state.quant,backend:state.backend}});
  }
  return text;
}

function resolveChoice(model='Automatic',quant='Auto',performance='balanced') {
  let key=String(model||'Automatic');
  // Automatic prioritizes predictable latency. Larger models remain selectable.
  key=routeModel({model:key,memoryGB:os.totalmem()/1024**3,performance}).key;
  const profile=modelProfiles[key];
  if(!profile) throw Error(`Unknown AI model: ${key}`);
  if(profile.runtime!=='transformers') throw Error(`${profile.label} does not have a compatible ONNX DirectML build.`);
  let selected=String(quant||'Auto').toUpperCase();
  if(selected==='AUTO') selected=os.totalmem()>=12*1024**3?'Q4F16':'Q4';
  const mobileQat=selected==='QAT / MOBILE-OPTIMIZED';
  if(mobileQat&&!profile.qatId) throw Error('QAT / mobile-optimized is available only for Gemma E2B and E4B.');
  if(mobileQat) return {
    key,profile,modelId:profile.qatId,processorId:profile.id,quant:'QAT / mobile-optimized',
    dtype:{embed_tokens:'q2f16',decoder_model_merged:'q2f16',vision_encoder:'fp16',audio_encoder:'q2f16'},
    backend:'DirectML',
  };
  if(!new Set(['Q4F16','Q4','Q8','FP16']).has(selected)) throw Error(`Unsupported quantization: ${selected}`);
  return {key,profile,modelId:profile.id,quant:selected,dtype:selected.toLowerCase(),backend:'DirectML'};
}

async function loadGenerator(requestedModel,requestedQuant,performance='balanced') {
  const choice=resolveChoice(requestedModel,requestedQuant,performance);
  const key=`${choice.key}:${choice.quant}:dml`;
  if(generator&&generatorKey===key) {
    state.model=choice.profile.label; state.quant=choice.quant; state.backend=choice.backend;
    return {generator,...choice};
  }
  if(generator?.dispose) await generator.dispose();
  generator=null; generatorKey=''; state.status='Loading native GPU model';
  generator=await pipeline('text-generation',choice.modelId,{
    device:'dml',dtype:choice.dtype,
    progress_callback:p=>{if(p.status==='progress'){state.progress=Math.round(p.progress||0);state.status='Downloading native model';}},
  });
  generatorKey=key; state.status='Ready'; state.model=choice.profile.label; state.quant=choice.quant;
  state.backend=choice.backend; state.progress=100;
  return {generator,...choice};
}

async function inspectSelection(selection,action,intent,requestedModel='Automatic',requestedQuant='Auto') {
  if(!selection.image) return '';
  state.status='Inspecting selected ink with Gemma';
  const response=await fetch(selection.image);
  if(!response.ok) throw Error('The selected ink image could not be read.');
  const decodedImage=await RawImage.fromBlob(await response.blob());
  // Keep the CPU compatibility path practical on full-page selections while
  // retaining enough pixels to read handwriting. Animate Ink only needs
  // object identity, so it can use a smaller image than text transcription.
  const maxImageEdge=action==='animateInk'?224:512;
  const imageScale=Math.min(1,maxImageEdge/Math.max(decodedImage.width,decodedImage.height));
  const image=imageScale<1
    ? await decodedImage.resize(Math.max(1,Math.round(decodedImage.width*imageScale)),Math.max(1,Math.round(decodedImage.height*imageScale)))
    : decodedImage;
  const selected=modelProfiles[requestedModel];
  const modelKey=routeModel({model:selected?.capabilities.includes(Capability.vision)?requestedModel:'Automatic',capability:Capability.vision,memoryGB:os.totalmem()/1024**3}).key;
  const quantKey=String(requestedQuant||'Auto')==='Auto'?'QAT / mobile-optimized':String(requestedQuant);
  const choice=resolveChoice(modelKey,quantKey);
  // The mobile QAT export contains the quantized ONNX sessions but does not
  // duplicate Gemma's tokenizer/processor metadata. Reuse the matching full
  // Gemma processor while keeping the selected model weights.
  const processor=await AutoProcessor.from_pretrained(choice.processorId||choice.modelId);
  // Selected notebook regions are small handwriting crops. Keep the visual
  // token budget bounded so compatibility inference stays responsive instead
  // of padding every crop to Gemma's full 280-token image canvas.
  if(processor.image_processor?.max_soft_tokens) processor.image_processor.max_soft_tokens=action==='animateInk'?24:32;
  const request=/\b(graph|plot)\b/i.test(intent)
    ? 'Read the selected handwriting as a mathematical equation. Transcribe it exactly in plain text or LaTeX, preserving every coefficient, sign, variable, exponent, and equals side. Output only the equation, for example: 3x^{5}+2x-x^{3}=y. Do not invent or simplify anything.'
    : action==='animateInk'
    ? 'Classify the selected image. Answer with one word only: pendulum, bee, bird, butterfly, car, ball, flower, tree, plant, handwriting, diagram, other, or unclear.'
    : action==='debug'
    ? 'Transcribe the selected handwritten math exactly, line by line. Preserve every number, operator, sign, and equals side. Output only the transcription; if it is unreadable, say unclear.'
    : 'Identify the selected notebook object and its exact text. Answer concisely; if unclear, say "unclear".';
  const messages=[{role:'user',content:[{type:'image'},{type:'text',text:request}]}];
  const prompt=processor.apply_chat_template(messages,{add_generation_prompt:true});
  const inputs=await processor(prompt,[image],null,{do_image_splitting:false});
  const decode=ids=>processor.batch_decode(ids.slice(null,[inputs.input_ids.dims.at(-1),null]),{skip_special_tokens:true})[0].trim();
  const run=async(device,modelId,dtype,key,quantLabel)=>{
    state.model=choice.profile.label;
    state.quant=quantLabel;
    state.backend=device==='dml'?'DirectML':'CPU (Gemma multimodal)';
    if(!multimodal||multimodal.key!==key) {
      if(multimodal?.model?.dispose) await multimodal.model.dispose();
      multimodal=null;
      state.status=device==='dml'?'Loading Gemma multimodal vision':'Using Gemma multimodal compatibility mode';
      const model=await AutoModelForImageTextToText.from_pretrained(modelId,{
        device,dtype,
        session_options: device==='cpu'?{intraOpNumThreads:2,interOpNumThreads:1}:undefined,
        progress_callback:p=>{if(p.status==='progress'){state.progress=Math.round(p.progress||0);state.status=device==='dml'?'Downloading Gemma vision model':'Loading Gemma vision compatibility model';}},
      });
      multimodal={processor,model,key,choice:{...choice,quant:quantLabel},device};
    }
    state.status=device==='dml'?'Reading selected ink with Gemma · DirectML':'Reading selected ink with Gemma · CPU compatibility';
    const maxTokens=action==='animateInk'?8:/\b(graph|plot)\b/i.test(intent)?32:action==='debug'?40:24;
    const ids=await multimodal.model.generate({...inputs,max_new_tokens:maxTokens,do_sample:false});
    state.model=choice.profile.label; state.quant=quantLabel; state.backend=device==='dml'?'DirectML':'CPU (Gemma multimodal)'; state.progress=100; state.lastError='';
    return decode(ids);
  };
  if(!visionDmlUnsupported) try {
    return await run('dml',choice.modelId,choice.dtype,`${choice.key}:${choice.quant}:dml`,choice.quant);
  } catch (gpuError) {
    // DirectML can reject Gemma's dynamic image reshape on some driver/model
    // combinations. Retry with the same vision-capable Gemma family on CPU so
    // a clean selection is still understood instead of becoming a fake graph.
    state.lastError=`DirectML vision retry: ${gpuError.message}`;
    visionDmlUnsupported=true;
  }
  const cpuChoice=choice.profile.qatId
    ? resolveChoice(choice.key,'QAT / mobile-optimized')
    : {...choice,modelId:choice.profile.id,dtype:'q4f16'};
  return await run('cpu',cpuChoice.modelId,cpuChoice.dtype,`${cpuChoice.key}:${cpuChoice.quant}:vision-cpu`,`${cpuChoice.quant} · CPU compatibility`);
}

async function generate(body) {
  let selection={};
  try { selection=typeof body.selection==='string'?JSON.parse(body.selection||'{}'):(body.selection||{}); } catch (_) {}
  const action=String(body.action||'explain'), intent=String(body.text||'');
  const isVisual=['makeAlive','createVisual','animateInk'].includes(action);
  // Read the selected object first. Visual actions can often be compiled from
  // the recognized equation or stroke geometry without waiting for an LLM.
  const observed=selection.image&&!hasExactTextOnlySelection(selection)
    ? await inspectCached(selection,action,intent,body.model,body.quant)
    : '';
  const motionIntent=action==='animateInk' ? enrichMotionIntent(intent,observed) : intent;
  const planSelection={...selection,objects:[...(selection.objects||[]),...(observed?[{kind:'vision',text:observed}]:[])]};
  const objectText=(selection.objects||[]).map(o=>`${o.kind}: ${o.text||''}${o.source?` source: ${o.source}`:''}${o.script?` script: ${o.script}`:''}`).join('\n').slice(0,1000);
  const context=`${intent.slice(0,1000)}\nSelected objects: ${objectText}\nVisual inspection: ${observed}`;
  const motionInput=JSON.stringify({intent:motionIntent,strokes:selection.strokes||[],objects:selection.objects||[],observed});
  if (action === 'debug' || action === 'check') {
    const verified = verifiedLinearDebug(hasExactTextOnlySelection(selection) ? (selection.objects||[]).map(o=>o.text).join('\n') : observed || intent);
    if (verified) {
      state.status='Ready'; state.lastError='';
      return {text:JSON.stringify(verified),model:observed ? state.model : 'Verified linear arithmetic',quant:observed ? state.quant : 'Not applicable',backend:observed ? state.backend : 'Local',observed,fallback:false};
    }
  }
  const projectile = ['makeAlive','createVisual'].includes(action) ? explicitProjectile(`${intent}\n${observed}`) : null;
  if (projectile) {
    const source = materializePlan(action,JSON.stringify(projectile),planSelection,intent);
    state.status='Ready'; state.lastError='';
    return {text:validateAiOutput(action,source,motionInput),model:observed ? state.model : 'Verified projectile physics',quant:observed ? state.quant : 'Not applicable',backend:observed ? state.backend : 'Local',observed,fallback:false};
  }
  if(action==='animateInk'&&selection.image&&observed.trim()) {
    const geometricPendulum=recognizePendulum(selection.strokes||[]);
    const recognized=!!geometricPendulum||/\b(pendulum|bee|bees|insect|bird|butterfly|animal|ball|car|plane|rocket|flower|tree|plant)\b/i.test(observed);
    const uncertain=/\b(?:unclear|cannot identify|can't identify|not sure|unable to tell)\b/i.test(observed);
    const actionable=/\b(?:animate|move|swing|bob|oscillat|fly|travel|patrol|back and forth|turn|return|go back|reveal|wave|float|slide|bounce|rotate|wind|sway|bend)\b/i.test(intent);
    if(recognized&&!uncertain&&actionable) {
      // Gemma has already inspected the selected image. For a confidently
      // recognized subject, compile its motion skill directly instead of
      // waiting minutes for the small text planner to describe familiar
      // movement. Ambiguous drawings still go through the planner below.
      state.status='Applying vision-grounded motion skill';
      const text=guaranteedFallback(action,motionIntent,planSelection,motionInput);
      state.status='Ready'; state.lastError='';
      return {text,model:state.model||'Gemma 4 multimodal',quant:state.quant||'Auto',backend:state.backend||'DirectML',observed,fallback:true};
    }
  }
  if(['makeAlive','createVisual'].includes(action)&&/\b(graph|plot)\b/i.test(intent)) {
    if(explicitGraphEquation(intent,planSelection)) {
      const source=materializePlan(action,'{"kind":"Graph"}',planSelection,intent);
      state.status='Ready'; state.lastError='';
      return {text:validateAiOutput(action,source,motionInput),model:state.model||'Gemma 4 multimodal',quant:state.quant||'Auto',backend:state.backend||'DirectML',observed,fallback:false};
    }
    throw Error('The selected equation could not be verified. Select the complete equation and try again. No visual was inserted.');
  }
  // Small Qwen is the fast planner for visual actions. Larger selected models
  // remain available for long-form text actions where their latency is useful.
  const routedModel=body.model||'Automatic';
  const routedQuant=body.quant;
  const loaded=await loadGenerator(routedModel,routedQuant,body.performance);
  const prompt=isVisual?`Design for this actual selection: ${context.slice(0,3000)}. Return only the compact JSON plan.`:intent.slice(0,18000);
  const skillInput=action==='animateInk'?motionInput:context;
  const messages=[{role:'system',content:isVisual?planSkill(action,planSelection,motionIntent):skillFor(action,skillInput)},{role:'user',content:prompt}];
  state.status='Generating on native GPU';
  for(let attempt=0;attempt<2;attempt++) {
    const result=await loaded.generator(messages,{max_new_tokens:['makeAlive','createVisual'].includes(action)?85:360,do_sample:false,return_full_text:false});
    const generated=result?.[0]?.generated_text;
    const raw=Array.isArray(generated)?generated.at(-1)?.content:generated;
    try {
      const candidate=isVisual?materializePlan(action,String(raw||''),planSelection,motionIntent):String(raw||'');
      const text=validateAiOutput(action,candidate,motionInput);
      state.status='Ready'; state.lastError='';
      return {text,model:loaded.profile.label,quant:loaded.quant,backend:'DirectML',observed,fallback:false};
    } catch(error) {
      if(attempt) throw error;
      state.status='Repairing native model output';
      messages.push({role:'assistant',content:String(raw||'')},{role:'user',content:`Your output was invalid: ${error.message}. Return a complete corrected answer only.`});
    }
  }
}

function cors(origin) {
  return /^https?:\/\/(127\.0\.0\.1|localhost)(:\d+)?$/i.test(origin||'')?origin:'http://127.0.0.1:8080';
}
function send(res,status,data,origin='') {
  res.writeHead(status,{'content-type':'application/json; charset=utf-8','access-control-allow-origin':cors(origin),'access-control-allow-methods':'GET, POST, OPTIONS','access-control-allow-headers':'content-type','cache-control':'no-store','vary':'Origin'});
  res.end(JSON.stringify(data));
}
async function readJson(req) {
  const chunks=[]; let size=0;
  for await(const chunk of req) { size+=chunk.length; if(size>REQUEST_LIMIT) throw Error('Request is too large.'); chunks.push(chunk); }
  return JSON.parse(Buffer.concat(chunks).toString('utf8')||'{}');
}
async function deadline(task,ms) {
  let timer;
  try {
    return await Promise.race([task,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Native generation exceeded the response deadline.')),ms);})]);
  } finally { clearTimeout(timer); }
}

const enqueue=serialExecutor();
let dispatch;
const server=http.createServer(async(req,res)=>{
  const origin=String(req.headers.origin||'');
  if(req.method==='OPTIONS') return send(res,204,{},origin);
  if(req.method==='GET'&&req.url==='/health') {
    const backend=String(state.backend||'Unavailable');
    return send(res,200,{ok:true,service:'InkMind Native AI',...state,backend,gpu:/directml|gpu/i.test(backend)},origin);
  }
  if(req.method!=='POST'||req.url!=='/generate') return send(res,404,{error:'Not found'},origin);
  let body={},selection={};
  try {
    body=await readJson(req);
    try { selection=typeof body.selection==='string'?JSON.parse(body.selection||'{}'):(body.selection||{}); } catch (_) {}
    // Exact editable text does not need a shared inference session. Keep its
    // deterministic compiler responsive while another page is doing vision.
    if(hasExactTextOnlySelection(selection)) {
      const action=String(body.action||''), intent=String(body.text||'');
      const exact=(selection.objects||[]).map(o=>o.text||'').join('\n');
      let text;
      const checked=['debug','check'].includes(action)?verifiedLinearDebug(exact):null;
      if(checked) text=JSON.stringify(checked);
      if(['makeAlive','createVisual'].includes(action)) {
        const projectile=explicitProjectile(`${intent}\n${exact}`);
        const graph=/\b(graph|plot)\b/i.test(intent)&&explicitGraphEquation(intent,selection);
        if(projectile||graph) text=validateAiOutput(action,materializePlan(action,JSON.stringify(projectile||{kind:'Graph'}),selection,intent));
      }
      if(text) return send(res,200,{text,model:'Verified exact-text compiler',quant:'Not applicable',backend:'Local',observed:'',fallback:false},origin);
    }
    const expires=Date.now()+300000;
    const result=await deadline(enqueue(()=>{
      if(Date.now()>=expires||res.destroyed) throw Error('This queued request expired. Please retry.');
      return dispatch(body);
    }),300000);
    return send(res,200,result,origin);
  } catch(error) {
    state.lastError=String(error?.message||error); state.status='Generation failed';
    return send(res,422,{error:state.lastError},origin);
  }
});

if(!isMainThread) {
  setInterval(()=>parentPort.postMessage({state:{...state}}),250).unref();
  parentPort.on('message',({id,body})=>enqueue(async()=>{
    try { parentPort.postMessage({id,result:await generate(body),state:{...state}}); }
    catch(error) { parentPort.postMessage({id,error:String(error?.message||error),state:{...state}}); }
  }));
  // Load the small automatic model while the notebook opens so the first
  // text/visual request does not pay its cold-start cost.
  enqueue(async()=>{
    state.status='Preparing the automatic local model';
    try{await loadGenerator('Automatic','Auto','fast');state.status='Ready';}
    catch(error){state.lastError=String(error?.message||error);state.status='Model will load on first AI request';}
  });
} else {
  const pending=new Map();let requestId=0;
  const worker=new Worker(new URL(import.meta.url));
  worker.on('message',message=>{
    if(message.state)Object.assign(state,message.state);
    const request=pending.get(message.id);if(!request)return;
    pending.delete(message.id);
    if(message.error)request.reject(Error(message.error));else request.resolve(message.result);
  });
  worker.on('error',error=>{state.status='AI worker failed';state.lastError=error.message;for(const request of pending.values())request.reject(error);pending.clear();});
  dispatch=body=>new Promise((resolve,reject)=>{const id=++requestId;pending.set(id,{resolve,reject});worker.postMessage({id,body});});
  server.listen(PORT,HOST,()=>console.log(`InkMind native AI listening on http://${HOST}:${PORT} (isolated inference worker)`));
}
