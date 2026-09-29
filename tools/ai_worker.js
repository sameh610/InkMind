import { modelProfiles, routeModel, Capability, modelCacheKey, serialExecutor } from './model_router.js';
import { pipeline, env, AutoProcessor, AutoModelForVision2Seq, RawImage } from '@huggingface/transformers';
import { skillFor } from './ai_skills.js';
import { planSkill, materializePlan, explicitGraphEquation, enrichMotionIntent } from './ai_plan.js';
import { compileInkScript } from './inkscript/compiler.js';
import { validateAiOutput, guaranteedFallback } from './ai_contract.js';

env.allowLocalModels = false;
env.backends.onnx.wasm.numThreads = 1;
let generator;
let generatorKey='';
let gpuUnavailable=false;
let vision;
function resolveChoice(model='Automatic',quant='Auto',adapter=null,performance='balanced') {
  const memory=Number(navigator.deviceMemory||4);
  let key=String(model||'Automatic');
  key=routeModel({model:key,memoryGB:memory,performance}).key;
  const profile=modelProfiles[key];
  if(!profile) throw Error(`Unknown AI model: ${key}`);
  if(profile.runtime==='litert') throw Error(`${profile.label} is catalogued, but its LiteRT-LM web build does not support this model yet.`);
  if(profile.runtime==='gguf') throw Error(`${profile.label} needs a GGUF browser runtime with ternary quantization support, which is not available in this web build.`);
  let selected=String(quant||'Auto').toUpperCase();
  if(selected==='AUTO') selected=adapter?'Q4F16':'Q4';
  const mobileQat=selected==='QAT / MOBILE-OPTIMIZED';
  if(mobileQat&&!profile.qatId) throw Error('QAT / mobile-optimized is available only for Gemma E2B and E4B.');
  if(mobileQat) return {
    key,profile,modelId:profile.qatId,quant:'QAT / mobile-optimized',
    dtype:{embed_tokens:'q2f16',decoder_model_merged:'q2f16',vision_encoder:'fp16',audio_encoder:'q2f16'},
    backend:adapter?'webgpu':'wasm',
  };
  const allowed=new Set(['Q4F16','Q4','Q8','FP16']);
  if(!allowed.has(selected)) throw Error(`${selected} quantization is not available for ${profile.label}.`);
  if(!adapter&&selected==='Q4F16') selected='Q4';
  return {key,profile,modelId:profile.id,quant:selected,dtype:selected.toLowerCase(),backend:adapter?'webgpu':'wasm'};
}
async function inspectSelection(selection,action,intent) {
  if (!selection.image) return '';
  self.postMessage({type:'status',message:'Looking at selected ink and diagrams'});
  if (!vision) {
    const id='HuggingFaceTB/SmolVLM-256M-Instruct';
    const adapter=await navigator.gpu?.requestAdapter();
    const processor=await AutoProcessor.from_pretrained(id);
    const options={
      device:adapter?'webgpu':'wasm',
      dtype:{embed_tokens:adapter?'fp16':'q4',vision_encoder:'q4',decoder_model_merged:'q4'},
      progress_callback:p=>{if(p.status==='progress') self.postMessage({type:'progress',progress:Math.round(p.progress||0),file:p.file});},
    };
    let model;
    try {model=await AutoModelForVision2Seq.from_pretrained(id,options);}
    catch(e){
      if(!adapter) throw e;
      self.postMessage({type:'status',message:'Vision GPU unavailable; loading CPU model'});
      model=await AutoModelForVision2Seq.from_pretrained(id,{...options,device:'wasm',dtype:{embed_tokens:'q4',vision_encoder:'q4',decoder_model_merged:'q4'}});
    }
    vision={processor,model};
  }
  const image=await RawImage.fromBlob(await (await fetch(selection.image)).blob());
  const graphRequest=['makeAlive','createVisual'].includes(action)&&/\b(graph|plot)\b/i.test(intent);
  const request=graphRequest
    ? 'Transcribe the selected handwritten equation exactly, character by character, including every coefficient, sign, variable, exponent, and equals side. Then briefly name the object. Never replace it with an example equation. If any symbol is unreadable, explicitly say which symbol is uncertain.'
    : 'Identify the selected notebook object before planning anything. Describe its exact text or equation, connected diagram parts, their positions, and what the strokes represent. Keep it under 70 words. If unreadable, say so rather than inventing an object.';
  const messages=[{role:'user',content:[{type:'image'},{type:'text',text:request}]}];
  const prompt=vision.processor.apply_chat_template(messages,{add_generation_prompt:true});
  const inputs=await vision.processor(prompt,[image],{do_image_splitting:false});
  const ids=await vision.model.generate({...inputs,max_new_tokens:90,do_sample:false});
  return vision.processor.batch_decode(ids.slice(null,[inputs.input_ids.dims.at(-1),null]),{skip_special_tokens:true})[0].trim();
}
function instructions(action, input) { return skillFor(action, input); }
async function load(requestedModel='Automatic',requestedQuant='Auto',performance='balanced') {
  let adapter = null;
  try { adapter = await navigator.gpu?.requestAdapter(); } catch (_) {}
  if(gpuUnavailable) adapter=null;
  const choice=resolveChoice(requestedModel,requestedQuant,adapter,performance);
  const key=modelCacheKey(choice);
  if(generator&&generatorKey===key)return {generator,...choice};
  if(generator?.dispose) await generator.dispose();
  generator=null;generatorKey='';
  const options = {device: choice.backend, dtype: choice.dtype, progress_callback: p => {
    if (p.status === 'progress') self.postMessage({type:'progress', progress:Math.round(p.progress || 0), file:p.file});
  }};
  try { generator = await pipeline('text-generation', choice.modelId, options); }
  catch (e) {
    if (choice.backend !== 'webgpu') throw e;
    gpuUnavailable=true;
    self.postMessage({type:'status', message:'GPU unavailable; loading CPU model'});
    const mobileQat=choice.quant==='QAT / mobile-optimized';
    generator = await pipeline('text-generation', choice.modelId, {...options, device:'wasm',dtype:mobileQat?choice.dtype:'q4'});
    choice.backend='wasm';
    if(!mobileQat){choice.dtype='q4';choice.quant='Q4';}
  }
  generatorKey=modelCacheKey(choice);
  self.postMessage({type:'ready',backend:choice.backend,model:choice.profile.label,quant:choice.quant});
  return {generator,...choice};
}
const enqueue=serialExecutor();
self.onmessage = ({data}) => enqueue(async () => {
  if (data.type === 'compile') {
    self.postMessage({type:'compiled',id:data.id,result:compileInkScript(String(data.source||''),{capability:data.capability||'BALANCED'})});
    return;
  }
  if (data.type !== 'generate') return;
  try {
    let selection={};
    try { selection=JSON.parse(data.selection||'{}'); } catch (_) {}
    const isVisual=['makeAlive','createVisual','animateInk'].includes(data.action);
    if(isVisual && !selection.image && ((selection.strokes?.length||0)+(selection.objects?.length||0)>0))
      throw Error('Could not capture the selected drawing. Re-select it and retry.');
    // Both cached models can download and initialize together on first use.
    const [observed,loaded]=await Promise.all([inspectSelection(selection,data.action,String(data.text||'')),load(data.model,data.quant,data.performance)]);
    const model=loaded.generator;
    const motionIntent=data.action==='animateInk'
      ? enrichMotionIntent(String(data.text||''),observed)
      : String(data.text||'');
    const planSelection={...selection,objects:[...(selection.objects||[]),...(observed?[{kind:'vision',text:observed}]:[])]};
    const objectText=(selection.objects||[]).map(o=>`${o.kind}: ${o.text||''}${o.source?` source: ${o.source}`:''}${o.script?` script: ${o.script}`:''}`).join('\n').slice(0,800);
    const context=`${String(data.text).slice(0,600)}\nSelected objects: ${objectText}\nVisual inspection: ${observed}`;
    const motionInput=JSON.stringify({intent:motionIntent,strokes:selection.strokes||[],objects:selection.objects||[],observed});
    self.postMessage({type:'status', message:'Generating with local AI'});
    const prompt=isVisual
      ? `Design for this actual selection: ${context.slice(0,3000)}. Return only the compact JSON plan.`
      : String(data.text).slice(0,18000);
    const skillInput=data.action==='animateInk'?motionInput:context;
    const messages = [{role:'system',content:isVisual?planSkill(data.action,planSelection,motionIntent):instructions(data.action, skillInput)}, {role:'user',content:prompt}];
    const visual = ['makeAlive','createVisual'].includes(data.action);
    for (let attempt=0; attempt<2; attempt++) {
      const result = await model(messages,{max_new_tokens:visual ? 85 : data.action === 'animateInk' ? 72 : 360,do_sample:false,return_full_text:false});
      const generated = result?.[0]?.generated_text;
      const text = Array.isArray(generated) ? generated.at(-1)?.content : generated;
      try {
        const candidate=isVisual?materializePlan(data.action,String(text||''),planSelection,motionIntent):String(text||'');
        self.postMessage({type:'result',id:data.id,text:validateAiOutput(data.action,candidate,motionInput)});
        return;
      } catch (e) {
        if (attempt) {
          if (visual && explicitGraphEquation(String(data.text||''),planSelection)) {
            const source=materializePlan(data.action,'{"kind":"Graph"}',planSelection,String(data.text||''));
            self.postMessage({type:'result',id:data.id,text:validateAiOutput(data.action,source,motionInput)});
            return;
          }
          throw e;
        }
        self.postMessage({type:'status',message:'Repairing model output'});
        const repair=isVisual
          ? `Your plan was invalid: ${e.message}. Return one corrected JSON plan only, with the documented fields and no prose.`
          : e.repairPrompt || `Repair your output. Error: ${e.message}. Return the complete corrected output only.`;
        messages.push({role:'assistant',content:String(text)}, {role:'user',content:repair});
      }
    }
  } catch (error) {
    self.postMessage({type:'error',id:data.id,message:String(error?.message||error)});
  }
});
