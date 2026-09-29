// A compact AI-authored plan is expanded into restricted InkScript, then
// checked by the same compiler as hand-written programs.
const visualTypes = {
  Graph: {a:[1,-4,4],b:[0,-6,6],c:[0,-6,6]},
  Pendulum: {gravity:[9.81,1,25],length:[2,.5,5]},
  Projectile: {velocity:[22,2,60],angle:[45,5,85]},
  Orbit: {speed:[1,.2,3]},
  Wave: {frequency:[2,.2,8],amplitude:[1,.1,3]},
  Chart: {},Timeline: {},Flowchart: {},Diagram: {},
  NeuralNetwork: {},SortingVisualizer: {},Scene: {},
};
function safeText(value,fallback,max=60) {
  return String(value||fallback).replace(/[\u0000-\u001f]/g,' ').slice(0,max);
}
function parsePlan(text) {
  const clean=String(text).replace(/^```(?:json)?\s*/i,'').replace(/```\s*$/,'').trim();
  const start=clean.indexOf('{'),end=clean.lastIndexOf('}');
  if(start<0||end<=start) throw Error('The model did not return a plan.');
  const plan=JSON.parse(clean.slice(start,end+1));
  if(!plan||Array.isArray(plan)||typeof plan!=='object') throw Error('Invalid AI plan.');
  return plan;
}
function number(value,defaultValue,lo,hi) {
  if(value===undefined||value===null||value==='') return defaultValue;
  const n=Number(value);
  return Number.isFinite(n)?Math.max(lo,Math.min(hi,n)):defaultValue;
}
// Typed equations are authoritative. The model chooses the presentation, but
// never gets to silently change a coefficient that the user supplied.
export function explicitGraphEquation(intent='',selection={}) {
  const sources=[String(intent),...(selection.objects||[]).map(o=>String(o.text||''))];
  for(const source of sources) {
    const normalized=source
      .replace(/\\(?:left|right)/g,'')
      .replace(/\\(?:cdot|times)/g,'*')
      .replace(/\^\{([0-9]+)\}/g,'^$1')
      .replace(/[{}$]/g,'')
      .replace(/[−–]/g,'-')
      .replace(/²/g,'^2').replace(/³/g,'^3').replace(/⁴/g,'^4').replace(/⁵/g,'^5')
      .replace(/[×·]/g,'*');
    const equations=[...normalized.matchAll(/([+\-0-9.xX*^\s]+)\s*=\s*y\b|\by\s*=\s*([+\-0-9.xX*^\s]+)/gi)];
    for(const match of equations) {
      const expression=(match[1]||match[2]||'').replace(/\s+/g,'').replace(/\*/g,'').toLowerCase();
      if(!expression||!/^[-+0-9.x^]+$/.test(expression)) continue;
      const terms=expression.replace(/-/g,'+-').split('+').filter(Boolean);
      if(!terms.length) continue;
      const values=[0,0,0,0,0,0];
      let degree=0;
      let valid=true;
      for(const term of terms) {
        const matched=term.match(/^(-?(?:\d+(?:\.\d*)?|\.\d+)?)?(x(?:\^([0-9]+))?)?$/);
        if(!matched||(!matched[1]&&!matched[2])) {valid=false;break;}
        const raw=matched[1];
        const coefficient=raw===''||raw===undefined?1:raw==='-'?-1:Number(raw);
        if(!Number.isFinite(coefficient)) {valid=false;break;}
        const power=matched[2]?Number(matched[3]||1):0;
        if(!Number.isInteger(power)||power<0||power>5){valid=false;break;}
        values[power]+=coefficient;
        degree=Math.max(degree,power);
      }
      if(valid&&values.every(v=>Number.isFinite(v)&&Math.abs(v)<=10000)) {
        if(degree<=2)return {a:values[2],b:values[1],c:values[0],expression};
        return {degree,coefficients:Array.from({length:degree+1},(_,i)=>values[degree-i]),expression};
      }
    }
  }
  return null;
}
// Editable text objects already carry their exact source string. Avoid a slow
// multimodal OCR pass for that case, while keeping real strokes and mixed
// diagram selections on the vision path.
export function hasExactTextOnlySelection(selection={}) {
  const strokes=Array.isArray(selection.strokes)?selection.strokes:[];
  const objects=Array.isArray(selection.objects)?selection.objects:[];
  return strokes.length===0 && objects.length>0 && objects.every(object=>
    object && object.kind==='text' && typeof object.text==='string' && object.text.trim().length>0
  );
}
function requestedVisualKind(intent='') {
  const instruction=String(intent).split(/\bInstruction\s*:/i).at(-1);
  for(const [pattern,kind] of [
    [/\b(graph|plot|parabola)\b/i,'Graph'],
    [/\btimeline\b/i,'Timeline'],
    [/\bflow\s*chart\b|\bflowchart\b/i,'Flowchart'],
    [/\bchart\b/i,'Chart'],
    [/\bdiagram\b/i,'Diagram'],
    [/\bpendulum\b/i,'Pendulum'],
    [/\bprojectile\b/i,'Projectile'],
    [/\borbit\b/i,'Orbit'],
    [/\bwave\b/i,'Wave'],
    [/\bneural\s*network\b/i,'NeuralNetwork'],
    [/\bsorting\b/i,'SortingVisualizer'],
  ]) if(pattern.test(instruction)) return kind;
  return null;
}
// The vision model supplies a semantic motion plan, but its tiny text planner
// can swap indices. Verify connected geometry before moving original strokes.
export function recognizePendulum(strokes=[]) {
  const box=s=>Array.isArray(s.bounds)&&s.bounds.length===4?s.bounds.map(Number):[0,0,0,0];
  const endpoint=(s,upper)=>{
    const points=Array.isArray(s.points)?s.points.filter(p=>Array.isArray(p)&&p.length>=2):[];
    if(!points.length){const b=box(s);return [(b[0]+b[2])/2,upper?b[1]:b[3]];}
    return points.reduce((best,p)=>Number(p[1])*(upper?1:-1)<Number(best[1])*(upper?1:-1)?p:best);
  };
  const distance=(a,b)=>Math.hypot(Number(a[0])-Number(b[0]),Number(a[1])-Number(b[1]));
  let match=null;
  strokes.forEach((rod,i)=>{
    const b=box(rod),height=b[3]-b[1],width=b[2]-b[0];
    const linePoints=Array.isArray(rod.points)?rod.points:[];
    const chord=linePoints.length>1?distance(linePoints[0],linePoints.at(-1)):Math.hypot(width,height);
    const path=linePoints.slice(1).reduce((sum,p,index)=>sum+distance(linePoints[index],p),0);
    if(chord<65||(path>0&&path/chord>1.35)||height<Math.max(25,width*.45)) return;
    const top=endpoint(rod,true),bottom=endpoint(rod,false);
    strokes.forEach((candidate,j)=>{
      if(i===j)return;
      const c=box(candidate),w=c[2]-c[0],h=c[3]-c[1];
      if(w<12||h<12||Math.max(w,h)/Math.min(w,h)>2.1||Math.max(w,h)>chord*.65)return;
      const points=candidate.points||[];
      const closed=points.length>2&&distance(points[0],points.at(-1))<Math.max(18,Math.max(w,h)*.4);
      const lowerDistance=distance(bottom,[(c[0]+c[2])/2,(c[1]+c[3])/2]);
      if(lowerDistance>Math.max(90,chord*.4)||c[1]<b[1]+height*.48)return;
      const score=chord-lowerDistance+(closed?40:0);
      if(!match||score>match.score)match={rod:i,bob:j,pivot:[Number(top[0]),Number(top[1])],score};
    });
  });
  return match;
}
// Vision is completed before Animate Ink is materialized. If the user says
// only “animate this” and the vision pass identifies a mobile subject, give
// the deterministic compiler the same semantic clue a larger planner would
// have received instead of falling back to an arbitrary pendulum/reveal.
export function enrichMotionIntent(intent='', observed='') {
  const instruction=String(intent).split(/\bInstruction\s*:/i).at(-1);
  const generic=/^\s*(?:animate|make(?: it| this)? alive|move|bring(?: it| this)? to life)(?:\s+(?:this|it|the (?:drawing|ink|object)))?[.!?\s]*$/i.test(instruction);
  const identified=String(observed).match(/\b(bee|bees|insect|bird|butterfly|animal|ball|car|plane|rocket)\b/i)?.[1];
  if(generic&&identified) {
    return `${intent} The identified ${identified} must travel to the other side and back repeatedly.`;
  }
  return String(intent);
}
export function planSkill(action,selection={},intent='') {
  if(action==='animateInk') {
    const catalog=(selection.strokes||[]).slice(0,24).map((s,i)=>`${i}: ${s.label||'stroke'} ${JSON.stringify(s.bounds||[])}`).join('; ');
    return `Identify what the selected drawing depicts before choosing motion. Direct the ORIGINAL selected vector strokes, not a replacement illustration. Strokes by index and bounding box: ${catalog}. Return ONE compact JSON object only with subject, motion, moving parts, and optional controls. Pendulum example: {"subject":"pendulum","motion":"pendulum","rod":[0],"bob":[1],"static":[2]}. For an animal, bee, bird, ball, or object told to cross to the other side, turn back, return, patrol, or go back and forth, use motion:"patrol". Patrol is a horizontal rigid translation that reaches the far side, reverses, and comes back repeatedly; it is not a drawing/reveal animation and not a pendulum. Example: {"subject":"bee","motion":"patrol","speed":1.4,"amount":240,"controls":[{"name":"gravity","min":0,"max":20,"value":9.8},{"name":"speed","min":0.2,"max":4,"value":1.4}],"static":[2]}. If the user asks for boxes, sliders, gravity, speed, or parameters under the subject, include controls. Motion can be pendulum, patrol, reveal, wave, float, slide, bounce, pulse, or rotate. If a long rod joins a round bob, swing BOTH together about the fixed upper pivot. Keep only a support or guide static. For handwriting choose reveal or wave. If the drawing is unclear, choose reveal rather than inventing a different object. Use only actual stroke indices. No code or prose.`;
  }
  const sceneHelp=/scene|draw|shape|illustrat|freeform/i.test(intent)
    ? ' For Scene supply shapes, e.g. [{"type":"Circle","x":100,"y":90,"radius":25},{"type":"Arrow","x1":130,"y1":90,"x2":230,"y2":90}].'
    : '';
  return 'You are a visual designer for an interactive notebook. Follow the user Instruction exactly and use the visual inspection and selected text as source facts. Never change a number or equation. Return ONE compact JSON object only, such as {"kind":"Graph","title":"Quadratic Explorer","a":1,"b":3,"c":-2}. Choose kind from Graph, Pendulum, Projectile, Orbit, Wave, Chart, Timeline, Flowchart, Diagram, NeuralNetwork, SortingVisualizer, Scene. For Graph supply a,b,c; Pendulum gravity,length; Projectile velocity,angle; Orbit speed; Wave frequency,amplitude.'+sceneHelp+' No code or prose.';
}
export function materializePlan(action,text,selection={},intent='') {
  const exact=explicitGraphEquation(intent,selection);
  if(/^\s*(?:```[^\n]*\n)?export\s+default\s+function\b/.test(text)) {
    if(!exact) return String(text);
    text='{"kind":"Graph"}';
  }
  const plan=parsePlan(text);
  if(action==='animateInk') {
    const strokes=(selection.strokes||[]).slice(0,256);
    if(!strokes.length) throw Error('No selected strokes were supplied.');
    const indices=value=>Array.isArray(value)?[...new Set(value.map(Number).filter(n=>Number.isInteger(n)&&n>=0&&n<strokes.length))]:[];
    const bounds=s=>Array.isArray(s.bounds)&&s.bounds.length===4?s.bounds.map(Number):[0,0,0,0];
    const recognized=recognizePendulum(strokes);
    const instruction=String(intent).split(/\bInstruction\s*:/i).at(-1);
    const generic=/^\s*(?:animate|make(?: it| this)? alive|move|bring(?: it| this)? to life)(?:\s+(?:this|it|the (?:drawing|ink|object)))?[.!?\s]*$/i.test(instruction);
    const requested=String(plan.motion||'reveal').toLowerCase();
    const travelIntent=/\b(across|other side|go(?:es)? to|fly|flies|flying|travel|move|patrol|back and forth|turn back|return|go back)\b/i.test(instruction) &&
      /\b(back|return|again|forth|turn|other side|patrol)\b/i.test(instruction);
    const patrolIntent=(/\b(bee|bees|insect|bird|butterfly|animal|ball|car|plane|rocket|object)\b/i.test(instruction)&&travelIntent)||(!recognized&&travelIntent);
    const patrolByPlan=requested==='patrol' || requested==='flight' || requested==='fly';
    let kind=(patrolIntent||patrolByPlan)?'patrol':recognized&&(generic||/\b(pendulum|swing|bob|oscillat)/i.test(instruction))?'pendulum':requested==='swing'?'pendulum':requested;
    if (/\b(wind|sway|bend)\b/i.test(instruction) && /\b(tree|flower|plant|grass|stem)\b/i.test(`${instruction} ${plan.subject||''}`)) kind='bend';
    if(!['pendulum','patrol','reveal','wave','float','slide','bounce','pulse','rotate','bend'].includes(kind)) {
      if(generic) kind='reveal';
      else throw Error('Unknown ink motion.');
    }
    const staticSet=new Set(indices(plan.static));
    const animalPatrol=kind==='patrol'&&/\b(bird|bee|bees|butterfly|insect|animal)\b/i.test(`${instruction} ${plan.subject||''}`);
    if(kind==='patrol') {
      // A small vision planner may mistake a tail or wing for a stationary
      // guide. Patrol translates one connected subject, so only preserve a
      // static role for an unmistakable long, thin guide outside its drawing.
      // This still lets a baseline/arrow remain fixed beneath a bouncing ball.
      const allBounds=strokes.map(bounds);
      for(const i of staticSet) {
        const b=allBounds[i],w=b[2]-b[0],h=b[3]-b[1];
        const others=allBounds.filter((_,j)=>j!==i);
        const subject=[Math.min(...others.map(v=>v[0])),Math.min(...others.map(v=>v[1])),Math.max(...others.map(v=>v[2])),Math.max(...others.map(v=>v[3]))];
        const clearlySeparate=b[1]>subject[3]+12 || b[3]<subject[1]-12 || b[0]>subject[2]+12 || b[2]<subject[0]-12;
        const guideLike=w>120 && w>h*5 && (w>(subject[2]-subject[0])*1.2 || clearlySeparate);
        if(!guideLike) staticSet.delete(i);
      }
    }
    let rod=indices(plan.rod).filter(i=>!staticSet.has(i));
    if(kind==='pendulum'&&recognized){
      rod=[recognized.rod];
      // A recognized connected object is authoritative. Small pivot marks and
      // arrows are context, so an uncertain model cannot make them drift.
      strokes.forEach((_,i)=>{if(i!==recognized.rod&&i!==recognized.bob)staticSet.add(i);});
      staticSet.delete(recognized.rod);
      staticSet.delete(recognized.bob);
    }
    if(kind==='pendulum'&&!rod.length) {
      let best=-Infinity,chosen=-1;
      strokes.forEach((s,i)=>{if(staticSet.has(i))return;const b=bounds(s),height=b[3]-b[1];if(height>best){best=height;chosen=i;}});
      if(chosen>=0)rod=[chosen];
    }
    const rodBounds=rod.length?bounds(strokes[rod[0]]):bounds(strokes[0]);
    const rodPoints=rod.length?(strokes[rod[0]].points||[]):[];
    const upper=rodPoints.length?rodPoints.reduce((a,b)=>Number(b[1])<Number(a[1])?b:a):[(rodBounds[0]+rodBounds[2])/2,rodBounds[1]];
    const pivot=recognized&&kind==='pendulum'?recognized.pivot:Array.isArray(plan.pivot)&&plan.pivot.length===2?plan.pivot:upper;
    const pivotX=number(pivot[0],Number(upper[0])||0,-10000,10000),pivotY=number(pivot[1],Number(upper[1])||0,-10000,10000);
    if(kind==='pendulum') strokes.forEach((s,i)=>{
      if(staticSet.has(i)||rod.includes(i))return;
      const b=bounds(s),width=b[2]-b[0],height=b[3]-b[1],cy=(b[1]+b[3])/2;
      if(width>50&&width>height*2&&cy>pivotY+25)staticSet.add(i);
    });
    const bob=new Set(recognized&&kind==='pendulum'?[recognized.bob]:indices(plan.bob).filter(i=>!staticSet.has(i)&&!rod.includes(i)));
    const parts=strokes.map((s,i)=>({id:String(s.id),role:staticSet.has(i)?'static':kind==='pendulum'?(rod.includes(i)?'rod':bob.size?(bob.has(i)?'bob':'ink'):'bob'):'ink'}));
    if(!parts.some(p=>p.role!=='static')) throw Error('No moving ink remains after excluding guides.');
    // A hand-drawn rod is often already leaning to one side. A tiny default
    // arc then produces the broken-looking left-center-left motion because it
    // never crosses the neutral axis. Give pendulums a visible, symmetric arc
    // while still honoring an explicit model amount.
    const amountBase=number(plan.amount,kind==='bend'?30:kind==='pendulum'?.95:kind==='rotate'?.3:kind==='pulse'?.12:10,
      kind==='pendulum'||kind==='rotate'?.03:kind==='pulse'?.02:.5,
      kind==='pendulum'||kind==='rotate'?1.2:kind==='pulse'?.5:60);
    // Generic animate requests should cross the neutral axis even when the
    // handwritten rod starts with a strong left lean. Otherwise the visual
    // reads as left-center-left instead of a real back-and-forth swing.
    let amount=kind==='pendulum'&&generic?Math.max(amountBase,.95):amountBase;
    const semanticSubject=instruction.match(/\b(bee|bees|insect|bird|butterfly|animal|ball|car|plane|rocket)\b/i)?.[1];
    const subject=safeText(semanticSubject||(recognized&&kind==='pendulum'?'pendulum':plan.subject||kind),'selected ink',40);
    const controls=[];
    const rawControls=Array.isArray(plan.controls)?plan.controls:[];
    const controlRequested=/\b(control|slider|box(?:es)?|parameter|gravity|speed)\b/i.test(instruction);
    const addControl=(name,min,max,value,unit='')=>{
      if(controls.some(c=>c.name===name))return;
      controls.push({name,min,max,value,unit});
    };
    if(kind==='patrol') {
      const patrolSpeed=number(plan.speed,1.4,.2,4);
      const travel=number(plan.amount,240,40,900);
      // A patrol always exposes the two useful physics knobs when the prompt
      // asks for controls. They are applied at runtime without changing ink.
      if(controlRequested||rawControls.length) {
        addControl('gravity',0,20,number(rawControls.find(c=>String(c?.name).toLowerCase()==='gravity')?.value,9.8,0,20),'m/s²');
        addControl('speed',.2,4,patrolSpeed,'x');
      }
      rawControls.slice(0,4).forEach(c=>{
        const name=safeText(c?.name,'control',24).toLowerCase().replace(/[^a-z0-9 _-]/g,'').trim();
        if(!name||name==='gravity'||name==='speed')return;
        const min=number(c?.min,0,-100,100),max=number(c?.max,1,min+0.01,100),value=number(c?.value,(min+max)/2,min,max);
        addControl(name,min,max,value,safeText(c?.unit,'',12));
      });
      plan.speed=patrolSpeed;
      amount=travel;
    }
    // Materialize every motion as ordinary, editable InkScript. The source
    // begins with bounded draw snapshots, then state controls, ink bindings,
    // and a normal animate() callback. The original page vectors remain the
    // render source; draw() makes the generated script self-describing.
    const pointPairs=s=>(Array.isArray(s.points)?s.points:[]).slice(0,96)
      .map(p=>Array.isArray(p)&&p.length>=2?[Number(p[0]),Number(p[1])]:null)
      .filter(p=>p&&p.every(Number.isFinite));
    const drawings=strokes.map(s=>`draw(${JSON.stringify({id:String(s.id),points:pointPairs(s),color:s.color,width:s.width})});`).join('\n  ');
    const movingParts=parts.filter(p=>p.role!=='static'&&p.role!=='anchor');
    const nameFor=id=>`part_${Math.max(0,strokes.findIndex(s=>String(s.id)===id))}`;
    const bodyIndex=strokes.reduce((best,s,i)=>{
      const b=bounds(s),prev=bounds(strokes[best]);
      return (b[2]-b[0])*(b[3]-b[1])>(prev[2]-prev[0])*(prev[3]-prev[1])?i:best;
    },0);
    const bodyBox=bounds(strokes[bodyIndex]);
    const flapRequested=kind==='patrol'&&/\b(flap|wing|wings|flying|fly)\b/i.test(`${instruction} ${plan.motion||''}`)&&animalPatrol;
    const explicitWings=indices(plan.wings??plan.wing).filter(i=>i!==bodyIndex&&!staticSet.has(i));
    const inferredWings=strokes.map((s,i)=>i).filter(i=>{
      if(i===bodyIndex||staticSet.has(i))return false;
      const b=bounds(strokes[i]),center=(b[0]+b[2])/2;
      return b[1]<bodyBox[1]-8&&center>bodyBox[0]+(bodyBox[2]-bodyBox[0])*.15&&center<bodyBox[2]-(bodyBox[2]-bodyBox[0])*.15;
    });
    const wingIndices=new Set(flapRequested?(explicitWings.length?explicitWings:inferredWings):[]);
    const speedValue=number(plan.speed,kind==='patrol'?1.4:2,.2,12);
    const stateLines=[`const speed = state(${speedValue});`];
    const hasGravity=kind==='pendulum'||controls.some(c=>c.name==='gravity');
    if(hasGravity)stateLines.push('const gravity = state(9.81);');
    const trig=kind==='pendulum'
      ? `Math.sin(time * speed * Math.sqrt(gravity / 9.81))`
      : `Math.sin(time * speed)`;
    const absTrig=`Math.abs(${trig})`;
    const angle=`${trig} * ${amount}`;
    const animation=[];
    for(const part of movingParts) {
      const index=strokes.findIndex(s=>String(s.id)===part.id);
      const stroke=strokes[index]||strokes[0], b=bounds(stroke), cx=(b[0]+b[2])/2, cy=(b[1]+b[3])/2;
      const variable=nameFor(part.id);
      switch(kind) {
        case 'patrol':
          animation.push(`${variable}.x = ${variable}.baseX + ${absTrig} * ${amount};`);
          if(hasGravity) animation.push(`${variable}.y = ${variable}.baseY + (gravity - 9.8) * 0.8 * Math.sin(${absTrig} * Math.PI);`);
          if(wingIndices.has(index)) animation.push(`${variable}.rotation = Math.sin(time * speed * 5) * 0.36;`);
          break;
        case 'pendulum': {
          animation.push(`${variable}.rotation = ${angle};`);
          break;
        }
        case 'rotate': animation.push(`${variable}.rotation = ${angle};`); break;
        case 'float': animation.push(`${variable}.y = ${variable}.baseY + ${trig} * ${amount};`); break;
        case 'slide': animation.push(`${variable}.x = ${variable}.baseX + ${trig} * ${amount};`); break;
        case 'bounce': animation.push(`${variable}.y = ${variable}.baseY - ${absTrig} * ${amount};`); break;
        case 'pulse': animation.push(`${variable}.scaleX = 1 + ${trig} * ${amount}; ${variable}.scaleY = 1 + ${trig} * ${amount};`); break;
        case 'wave': animation.push(`${variable}.y = ${variable}.baseY + ${trig} * ${amount};`); break;
        case 'bend': animation.push(`${variable}.bend = ${trig} * ${amount};`); break;
        case 'reveal': default: animation.push(`${variable}.opacity = Math.min(1, time * speed);`); break;
      }
    }
    const bindings=movingParts.map(part=>{
      const index=strokes.findIndex(s=>String(s.id)===part.id);
      const first=strokes[index]?.points?.[0];
      const pivotOptions=kind==='bend'?`, {pivotX:${(Math.min(...strokes.map(s=>bounds(s)[0]))+Math.max(...strokes.map(s=>bounds(s)[2])))/2},pivotY:${Math.max(...strokes.map(s=>bounds(s)[3]))}}`:kind==='pendulum'?`, {pivotX:${pivotX},pivotY:${pivotY}}`:wingIndices.has(index)&&Array.isArray(first)?`, {pivotX:${number(first[0],0,-10000,10000)},pivotY:${number(first[1],0,-10000,10000)}}`:'';
      return `const ${nameFor(part.id)} = ink.stroke(${JSON.stringify(part.id)}${pivotOptions});`;
    }).join('\n  ');
    return `export default function Animation() {\n  ${drawings}\n  ${stateLines.join('\n  ')}\n  ${bindings}\n  animate(({ time }) => {\n    ${animation.join('\n    ')}\n  });\n}`;
  }
  const kind=requestedVisualKind(intent)||(exact?'Graph':Object.keys(visualTypes).find(k=>k.toLowerCase()===String(plan.kind||'').toLowerCase()));
  if(!kind) throw Error('Visual kind is not supported.');
  const prettyEquation=exact?.expression.replace(/\^2/g,'²').replace(/\^3/g,'³').replace(/\^4/g,'⁴').replace(/\^5/g,'⁵').replace(/(?!^)-/g,' − ').replace(/(?!^)\+/g,' + ').replace(/^-/, '−');
  const title=kind==='Graph'&&exact?`y = ${prettyEquation}`:safeText(plan.title,`${kind} Explorer`,48);
  const caption=kind==='Graph'&&exact?'Drag the coefficients to explore this equation.':safeText(plan.caption,'Explore the selected idea.',100);
  const polynomial=kind==='Graph'&&exact?.degree>=3;
  const params=polynomial?Object.fromEntries(exact.coefficients.map((value,index)=>{
    const power=exact.degree-index,limit=Math.max(4,Math.ceil(Math.abs(value)*1.5));
    return [`p${power}`,[value,-limit,limit]];
  })):kind==='Graph'&&exact?Object.fromEntries(['a','b','c'].map(name=>{
    const value=exact[name], limit=Math.max(name==='a'?4:6,Math.ceil(Math.abs(value)*1.5));
    return [name,[value,-limit,limit]];
  })):visualTypes[kind];
  const state=Object.entries(params).map(([name,[defaultValue,lo,hi]])=>`const ${name} = state(${number(kind==='Graph'&&exact?exact[name]:plan[name],defaultValue,lo,hi)});`).join(' ');
  const props=polynomial?`coefficients={[${Object.keys(params).join(',')}]}`:Object.keys(params).map(name=>`${name}={${name}}`).join(' ');
  const controls=Object.entries(params).map(([name,[,lo,hi]])=>`<Slider label=${JSON.stringify(kind==='Graph'?(name.startsWith('p')?`${name.slice(1)==='0'?'constant':`x^${name.slice(1)} coefficient`}`:({a:'x² coefficient',b:'x coefficient',c:'constant'}[name]||name)):name)} value={${name}} min={${lo}} max={${hi}}/>`).join('');
  let visual=`<${kind}${props?' '+props:''}/>`;
  if(kind==='Scene') {
    const shapes=(Array.isArray(plan.shapes)?plan.shapes:[]).slice(0,8).map(shape=>{
      const type=['Circle','Rect','Line','Arrow'].find(t=>t.toLowerCase()===String(shape.type||'').toLowerCase());
      if(!type) return '';
      const keys=type==='Circle'?['x','y','radius']:type==='Rect'?['x','y','width','height']:['x1','y1','x2','y2'];
      const attrs=keys.map(key=>`${key}={${number(shape[key]??(key==='radius'?shape.r:undefined),key==='radius'?15:0,0,500)}}`).join(' ');
      return `<${type} ${attrs}/>`;
    }).join('');
    if(!shapes) throw Error('Scene needs shapes that describe the selected idea.');
    visual=`<Scene height={220}>${shapes}</Scene>`;
  }
  return `export default function Visual() { ${state} return <App title=${JSON.stringify(title)}><Text>${caption.replace(/[<>{}]/g,'')}</Text>${visual}${controls?`<Controls>${controls}</Controls>`:''}</App>; }`;
}
