import { compileInkScript } from './inkscript/compiler.js';
import { materializePlan, explicitGraphEquation, enrichMotionIntent } from './ai_plan.js';

export function normalizeAnimation(code, input) {
  let source=String(code||'').replace(/export\s+default\s+function\s+[A-Za-z_$][\w$]*\s*\(/,'export default function Animation(')
    .replace(/\bink\.time\b/g,'time');
  let selected=[];
  try { selected=(JSON.parse(input).strokes||[]).slice(0,64); } catch (_) {}
  const ids=selected.map(s=>String(s.id));
  // Make every model response source-first. The drawing commands are a
  // bounded, immutable snapshot for editing/debugging; the renderer still
  // paints the original vector strokes from the page.
  if(selected.length&&!/\bdraw\s*\(/.test(source)) {
    const drawings=selected.map(s=>`draw(${JSON.stringify({id:String(s.id),points:(s.points||[]).slice(0,96),color:s.color,width:s.width})});`).join(' ');
    const open=source.indexOf('{');
    if(open>=0) source=`${source.slice(0,open+1)} ${drawings} ${source.slice(open+1)}`;
  }
  if(ids.length===1) source=source.replace(/ink\.stroke\(\s*(['"])[^'"]+\1\s*\)/g,`ink.stroke(${JSON.stringify(ids[0])})`);
  if(!/\banimate\s*\(/.test(source)) {
    const bindings=[...source.matchAll(/const\s+[A-Za-z_$][\w$]*\s*=\s*ink\.(?:selection|page|stroke|find)\([^;]*\)\s*;/g)].map(m=>m[0]);
    const assignments=[...source.matchAll(/[A-Za-z_$][\w$]*\.(?:x|y|rotation|bend|scaleX|scaleY|opacity|visible)\s*=\s*[^;]+;/g)].map(m=>m[0]);
    if(bindings.length && assignments.length) source=`export default function Animation() { ${bindings.join(' ')} animate(({ time }) => { ${assignments.join(' ')} }); }`;
  }
  return source;
}

export function validateAiOutput(action, text, input='') {
  if (!String(text||'').trim()) throw Error('Empty model response');
  let clean=String(text).replace(/^```[^\n]*\n/, '').replace(/\s*```$/, '').trim();
  if (['makeAlive','createVisual','animateInk'].includes(action)) {
    if(action==='animateInk') clean=normalizeAnimation(clean,input);
    const start=clean.search(/export\s+default\s+function\s+(?:Visual|Animation)\s*\(/);
    if(start>=0) {
      const open=clean.indexOf('{',start); let depth=0,quote='',escaped=false,end=-1;
      for(let i=open;i<clean.length;i++) {
        const ch=clean[i];
        if(quote) { if(escaped) escaped=false; else if(ch==='\\') escaped=true; else if(ch===quote) quote=''; continue; }
        if(ch==='"'||ch==="'"||ch==='`') {quote=ch;continue;}
        if(ch==='{') depth++;
        if(ch==='}'&&--depth===0) {end=i+1;break;}
      }
      if(end>open) clean=clean.slice(start,end);
    }
    const compiled=compileInkScript(clean,{capability:'BALANCED'});
    if (!compiled.ok) {
      const error=Error(compiled.errors[0].message); error.repairPrompt=compiled.repairPrompt; throw error;
    }
    const expected=action==='animateInk'?'animateInk':'visual';
    if (compiled.ir.mode!==expected) throw Error(`Expected ${expected} InkScript function`);
    if(action==='animateInk') {
      let ids=[]; try { ids=(JSON.parse(input).strokes||[]).map(s=>String(s.id)); } catch (_) {}
      for(const binding of compiled.ir.bindings) if(binding.selector==='stroke'&&!ids.includes(binding.arg)) {
        const error=Error(`Unknown stroke ID ${binding.arg}`);
        error.repairPrompt=`Use one of these actual stroke IDs: ${ids.join(', ')}. Return a complete Animation() function only.`;
        throw error;
      }
      for(const drawing of (compiled.ir.drawings||[])) if(!ids.includes(drawing.id)) {
        const error=Error(`Unknown drawn stroke ID ${drawing.id}`);
        error.repairPrompt=`Draw only these actual stroke IDs: ${ids.join(', ')}. Return a complete Animation() function only.`;
        throw error;
      }
      const drawn=new Set((compiled.ir.drawings||[]).map(d=>d.id));
      if(ids.some(id=>!drawn.has(id))) {
        const error=Error('Animation source did not draw every selected stroke first.');
        error.repairPrompt=`Start with draw({...}) for every selected stroke ID: ${ids.join(', ')}. Return a complete Animation() function only.`;
        throw error;
      }
      if(compiled.ir.rig?.parts.some(part=>!ids.includes(part.id))) throw Error('The ink rig referenced a stroke outside the selected drawing.');
    }
    return JSON.stringify({source:compiled.source||clean,ir:compiled.ir,ast:compiled.ast,warnings:compiled.warnings});
  }
  if (['quiz','flashcards','check','debug'].includes(action)) JSON.parse(clean);
  return clean;
}

function compactContext(text, selection={}) {
  const objects=(selection.objects||[]).map(o=>o.text||o.source||o.script||'').filter(Boolean).join(' ');
  return `${String(text||'')} ${objects}`.replace(/\s+/g,' ').trim().slice(0,500) || 'the selected notebook content';
}

export function guaranteedFallback(action, text, selection={}, motionInput='') {
  if(action==='animateInk') {
    let observed='';
    try { observed=JSON.parse(motionInput||'{}').observed||''; } catch (_) {}
    const intent=enrichMotionIntent(String(text||''),observed);
    return validateAiOutput(action,materializePlan(action,'{"subject":"selected ink","motion":"reveal"}',selection,intent),motionInput);
  }
  if(['makeAlive','createVisual'].includes(action)) {
    const exact=explicitGraphEquation(String(text||''),selection);
    const wantsGraph=/\b(graph|plot)\b/i.test(String(text||''));
    const plan=exact?'{"kind":"Graph"}':'{"kind":"Diagram","title":"Equation not recognized","summary":"Select the full equation and try again"}';
    // Do not let a graph instruction force a default quadratic when the
    // equation could not be read. A clear retry card is safer than fake math.
    const safeIntent=wantsGraph&&!exact?'':String(text||'');
    return validateAiOutput(action,materializePlan(action,plan,selection,safeIntent),motionInput);
  }
  const context=compactContext(text,selection);
  if(['quiz','flashcards'].includes(action)) return JSON.stringify({
    title:'Review the selected notes',
    questions:[
      {prompt:'Which option best matches the selected content?',choices:[context,'An unrelated topic','There is no selected content'],answer:0,explanation:'This answer uses the content that was supplied.'},
      {prompt:'What should you review first?',choices:['The exact selected statement','A random example','Nothing'],answer:0,explanation:'Start from the original statement before adding assumptions.'},
      {prompt:'Which study habit preserves accuracy?',choices:['Check each claim against the selection','Replace unclear symbols','Guess missing facts'],answer:0,explanation:'Grounding answers in the selection prevents invented details.'},
    ],
  });
  if(['check','debug'].includes(action)) return JSON.stringify({steps:[context],firstError:null,explanation:'The selected statement was preserved. There is not enough explicit working to identify a specific incorrect step.',corrected:[context]});
  const lead={explain:'Here is the selected idea in plain language:',hint:'Start with the exact information already present:',summarize:'Selected content:',continueIdea:'A useful next step is to test or expand this statement:',prerequisite:'First make sure you understand the terms in:',rewrite:'Clear rewrite:'}[action]||'Notebook response:';
  return `${lead}\n\n${context}`;
}
