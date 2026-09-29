(() => {
  const nativeBase='http://127.0.0.1:8787';
  let worker,timer,nativeAbort,nextId=0,nativeProbe;
  const pending=new Map();
  const state={status:'Checking local AI companion',progress:0,backend:'',model:'',quant:'',startedAt:0,native:false,fallbackReason:''};
  const labels={
    'qwen-2.5-coder-0.5b':'Qwen 2.5 Coder 0.5B','gemma-4-e2b':'Gemma 4 E2B','gemma-4-e4b':'Gemma 4 E4B',
    'spark-x2.5-1.7b':'Spark-X2.5 1.7B','spark-x2.5-4b':'Spark-X2.5 4B','ternary-bonsai-2-27b':'Ternary Bonsai 2 27B',
  };
  function resolved(model='Automatic',quant='Auto',native=state.native) {
    const gpu=!!navigator.gpu,memory=Number(navigator.deviceMemory||4); let id=model;
    if(!id||id==='Automatic') id='qwen-2.5-coder-0.5b';
    let q=quant;if(!q||q==='Auto') q=gpu?'Q4F16':'Q4';
    return {id,label:labels[id]||id,quant:q,backend:native?'Local companion':gpu?'WebGPU':'WASM'};
  }
  async function probeNative(force=false) {
    if(nativeProbe&&!force)return nativeProbe;
    nativeProbe=(async()=>{const controller=new AbortController(),timeout=setTimeout(()=>controller.abort(),700);
      try {const response=await fetch(`${nativeBase}/health`,{signal:controller.signal,cache:'no-store'});const info=await response.json();state.native=!!info.ok;
        if(state.native){state.backend=info.backend||'Local companion';state.model=info.model||state.model;state.quant=info.quant||state.quant;state.status=info.status||'Local AI companion ready';}
        return state.native;}
      catch(_){state.native=false;return false;} finally{clearTimeout(timeout);nativeProbe=null;}
    })();
    return nativeProbe;
  }
  function cancel(message='AI request cancelled.') {
    clearTimeout(timer);nativeAbort?.abort();nativeAbort=null;worker?.terminate();worker=null;state.startedAt=0;
    for(const request of pending.values())request.reject(new Error(message));pending.clear();state.status=message;
  }
  function connect() {
    if(worker)return worker;
    worker=new Worker('ai_worker.bundle.js?v=native-directml-1',{type:'module'});
    worker.onmessage=({data})=>{
      if(data.type==='progress'){state.status=`Downloading browser model${state.fallbackReason?` · ${state.fallbackReason}`:''}`;state.progress=data.progress;}
      else if(data.type==='status')state.status=data.message;
      else if(data.type==='ready'){state.status='Ready';state.backend=data.backend;state.model=data.model||state.model;state.quant=data.quant||state.quant;}
      else {const request=pending.get(data.id);if(!request)return;
        if(request.kind==='compile'){pending.delete(data.id);if(data.type==='compiled')request.resolve(JSON.stringify(data.result));else request.reject(new Error(data.message||'Compilation failed'));return;}
        clearTimeout(timer);pending.delete(data.id);state.startedAt=0;
        if(data.type==='result'){state.status=data.fallback?'Ready · safe fallback used':'Ready';request.resolve(data.text);}
        else{state.status='Browser AI failed: '+data.message;request.reject(new Error(state.status));}
      }
    };
    worker.onerror=e=>cancel('AI worker failed: '+e.message);return worker;
  }
  function browserGenerate(action,text,selection,model,quant,performance) {
    const id=++nextId,choice=resolved(model,quant,false);state.status=`${worker?'Generating with browser AI':'Loading browser model'}${state.fallbackReason?` · ${state.fallbackReason}`:''}`;state.model=choice.label;state.quant=choice.quant;state.backend=choice.backend;
    return new Promise((resolve,reject)=>{pending.set(id,{resolve,reject,kind:'generate'});timer=setTimeout(()=>cancel('Browser AI timed out.'),600000);
      try{connect().postMessage({type:'generate',id,action,text,selection,model,quant,performance});}catch(e){pending.delete(id);reject(e);}
    });
  }
  async function nativeGenerate(action,text,selection,model,quant,performance) {
    nativeAbort=new AbortController();const timeout=setTimeout(()=>nativeAbort.abort(),310000);
    const syncStatus=async()=>{try{
      const response=await fetch(`${nativeBase}/health`,{cache:'no-store'});
      if(!response.ok)return;const info=await response.json();if(!info.ok)return;
      if(info.status)state.status=info.status;
      if(Number.isFinite(info.progress))state.progress=info.progress;
      if(info.model)state.model=info.model;if(info.quant)state.quant=info.quant;
      if(info.backend)state.backend=info.backend;
    }catch(_){}};
    const statusPoll=setInterval(syncStatus,700);
    try {state.status='Connecting to local AI companion';state.backend='Local companion';void syncStatus();
      const response=await fetch(`${nativeBase}/generate`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({action,text,selection,model,quant,performance}),signal:nativeAbort.signal});
      const data=await response.json();if(!response.ok||!String(data.text||'').trim())throw Error(data.error||'Native AI returned no result.');
      state.model=data.model||state.model;state.quant=data.quant||state.quant;state.backend=data.backend||state.backend||'Local companion';state.status=data.fallback?'Ready · vision-grounded skill used':'Ready';return data.text;
    } finally{clearInterval(statusPoll);clearTimeout(timeout);nativeAbort=null;}
  }
  probeNative().then(ok=>{if(ok&&state.status==='Checking local AI companion')state.status='Local AI companion ready';else if(state.status==='Checking local AI companion')state.status='Browser AI ready';});
  window.InkMindBrowserAI={
    async generate(action,text,selection='{}',model='Automatic',quant='Auto',performance='balanced'){
      if(pending.size||state.startedAt)return Promise.reject(new Error('An AI request is already running.'));
      state.startedAt=Date.now();const choice=resolved(model,quant);state.model=choice.label;state.quant=choice.quant;
      try {
        if(state.native||await probeNative(true))try{return await nativeGenerate(action,text,selection,model,quant,performance);}catch(error){state.status='Native AI failed · retry available';throw error;}
        if(!state.native&&!state.fallbackReason)state.fallbackReason='native runner not running; using browser fallback';
        return await browserGenerate(action,text,selection,model,quant,performance);
      } finally{state.startedAt=0;}
    },
    compile(source,capability='BALANCED'){const id=++nextId;return new Promise((resolve,reject)=>{pending.set(id,{resolve,reject,kind:'compile'});try{connect().postMessage({type:'compile',id,source,capability});}catch(e){pending.delete(id);reject(e);}});},
    cancel(){cancel();},
      selection(model='Automatic',quant='Auto'){const c=resolved(model,quant);return state.model&&state.status.startsWith('Ready')?`${state.model} · ${state.quant} · ${state.backend}`:`${c.label} · ${c.quant} · ${c.backend} (estimated until loaded)`;},
      usesNative(){return !!state.native;},
    status(){return state.status+(state.status.includes('Downloading')?` ${state.progress}%`:'')+(state.model?` · ${state.model}`:'')+(state.quant?` · ${state.quant}`:'')+(state.backend?` · ${state.backend}`:'')+(state.startedAt?` · ${Math.floor((Date.now()-state.startedAt)/1000)}s`:'');},
    probeNative(){return probeNative(true);}
  };
})();
