// Shared by the browser worker and native companion. Memory numbers are
// conservative planning estimates, never measurements or download sizes.
export const Capability = Object.freeze({text:'TEXT_REASONING',script:'INKSCRIPT',vision:'VISION',ocr:'OCR',image:'IMAGE_GENERATION',animation:'ANIMATE_INK',web:'CUSTOM_WEB',tools:'TOOL_CALLING',deep:'DEEP_REASONING'});
const text = [Capability.text, Capability.script, Capability.animation];
export const modelProfiles = Object.freeze({
  'qwen-2.5-coder-0.5b': {label:'Qwen 2.5 Coder 0.5B',id:'onnx-community/Qwen2.5-Coder-0.5B-Instruct',runtime:'transformers',tier:'Lite',capabilities:text,estimatedWorkingGB:1},
  'gemma-4-e2b': {label:'Gemma 4 E2B',id:'onnx-community/gemma-4-E2B-it-ONNX',qatId:'onnx-community/gemma-4-E2B-it-qat-mobile-ONNX',runtime:'transformers',tier:'Vision',capabilities:[...text,Capability.vision,Capability.ocr],estimatedWorkingGB:4},
  'gemma-4-e4b': {label:'Gemma 4 E4B',id:'onnx-community/gemma-4-E4B-it-ONNX',qatId:'onnx-community/gemma-4-E4B-it-qat-mobile-ONNX',runtime:'transformers',tier:'Smart',capabilities:[...text,Capability.vision,Capability.ocr],estimatedWorkingGB:8},
  'spark-x2.5-1.7b': {label:'Spark-X2.5 1.7B',runtime:'litert',tier:'Lite',capabilities:text},
  'spark-x2.5-4b': {label:'Spark-X2.5 4B',runtime:'litert',tier:'Smart',capabilities:text},
  'ternary-bonsai-2-27b': {label:'Ternary Bonsai 2 27B',runtime:'gguf',tier:'Ultra',capabilities:[...text,Capability.deep]},
});

export function routeModel({model='Automatic',capability=Capability.text,memoryGB=4,performance='balanced'}={}) {
  const explicit=model&&model!=='Automatic';
  const supports=p=>p.runtime==='transformers'&&p.capabilities.includes(capability);
  if(explicit) {
    const profile=modelProfiles[model];
    if(!profile) throw Error(`Unknown AI model: ${model}`);
    if(profile.runtime!=='transformers') throw Error(`${profile.label} requires a ${profile.runtime} backend that is not installed.`);
    if(!supports(profile)) throw Error(`${profile.label} cannot perform ${capability}. Choose a compatible model or Automatic.`);
    return {key:model,profile,reason:'Explicit model selection',estimatedMemory:true};
  }
  // Reserve room for the OS, notebook, image buffers and KV cache. Browser
  // deviceMemory is rounded and capped; it is only a conservative hint.
  const budget=Math.max(0,Number(memoryGB)*0.65-1);
  const candidates=Object.entries(modelProfiles).filter(([,p])=>supports(p)&&p.estimatedWorkingGB<=budget);
  if(!candidates.length) throw Error(`No compatible ${capability} model fits the estimated memory budget. Select a model explicitly if you have verified available memory.`);
  candidates.sort((a,b)=>a[1].estimatedWorkingGB-b[1].estimatedWorkingGB);
  const [key,profile]=performance==='quality'?candidates.at(-1):candidates[0];
  return {key,profile,reason:`${capability}: ${performance==='quality'?'highest capacity within':'lowest latency within'} estimated memory budget`,estimatedMemory:true};
}

export function modelCacheKey(choice) {
  return JSON.stringify([choice.modelId,choice.quant,choice.backend,choice.dtype]);
}

export function quantizationsFor(model) {
  const profile=modelProfiles[model];
  if(profile&&profile.runtime!=='transformers') return ['Auto'];
  return ['Auto',...(profile?.qatId?['QAT / mobile-optimized']:[]),'Q4F16','Q4','Q8','FP16'];
}

// Inference sessions are mutable. Requests must never dispose or overwrite a
// session while another request is using it. Rejections do not poison the queue.
export function serialExecutor() {
  let tail=Promise.resolve();
  return operation=> {
    const result=tail.then(operation);
    tail=result.catch(()=>{});
    return result;
  };
}
