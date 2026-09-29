import test from 'node:test';
import assert from 'node:assert/strict';
import {materializePlan,explicitGraphEquation,recognizePendulum,hasExactTextOnlySelection} from './ai_plan.js';
import {compileInkScript} from './inkscript/compiler.js';
import {guaranteedFallback,validateAiOutput} from './ai_contract.js';

test('AI graph plan compiles with interactive coefficients',()=>{
  const source=materializePlan('createVisual','{"kind":"Graph","title":"Parabola","a":1,"b":3,"c":-2}');
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ok,true,compiled.errors?.[0]?.message);
  assert.equal(compiled.ir.mode,'visual');
  assert.equal(compiled.ir.state.length,3);
});
test('typed equation overrides incorrect model coefficients and graph kind',()=>{
  const plan='{"kind":"Scene","title":"Something else","a":1,"b":4,"c":9}';
  const source=materializePlan('createVisual',plan,{},'Make 3x^2 -1 = y a graph');
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ok,true,compiled.errors?.[0]?.message);
  assert.deepEqual(compiled.ir.state.map(s=>s.value),[3,0,-1]);
  assert.equal(compiled.ir.root.children[1].type,'Graph');
  assert.match(source,/y = 3x² − 1/);
  assert.match(source,/x² coefficient/);
});
test('selected cubic equation is preserved instead of becoming a quadratic',()=>{
  const selection={objects:[{kind:'vision',text:'x^3 - x^2 + 1 = y'}]};
  assert.deepEqual(explicitGraphEquation('make this a graph',selection),{
    degree:3,coefficients:[1,-1,0,1],expression:'x^3-x^2+1',
  });
  const source=materializePlan('createVisual','{"kind":"Graph","a":1,"b":3,"c":-2}',selection,'make this a graph');
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ok,true,compiled.errors?.[0]?.message);
  assert.deepEqual(compiled.ir.state.map(s=>s.value),[1,-1,0,1]);
  assert.deepEqual(compiled.ir.root.children[1].props.coefficients.items.map(x=>x.name),['p3','p2','p1','p0']);
  assert.match(source,/y = x³ − x² \+ 1/);
});
test('math OCR LaTeX preserves reordered fifth-degree coefficients',()=>{
  const selection={objects:[{kind:'vision',text:'3 x^{5} + 2 x - x^{3} = y'}]};
  assert.deepEqual(explicitGraphEquation('make it a graph',selection),{
    degree:5,coefficients:[3,0,-1,0,2,0],expression:'3x^5+2x-x^3',
  });
});
test('selected typed equation remains authoritative when instruction is separate',()=>{
  const selection={objects:[{kind:'text',text:'y = -2x² + 0.5x + 7'}]};
  assert.deepEqual(explicitGraphEquation('make it a graph',selection),{a:-2,b:.5,c:7,expression:'-2x^2+0.5x+7'});
  const source=materializePlan('makeAlive','{"kind":"Graph","a":1,"b":1,"c":1}',selection,'make it a graph');
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.deepEqual(compiled.ir.state.map(s=>s.value),[-2,.5,7]);
});
test('editable text objects use exact text while ink and mixed selections stay vision-grounded',()=>{
  assert.equal(hasExactTextOnlySelection({objects:[{kind:'text',text:'3x^2 - 1 = y'}]}),true);
  assert.equal(hasExactTextOnlySelection({strokes:[{id:'ink'}],objects:[{kind:'text',text:'3x^2 - 1 = y'}]}),false);
  assert.equal(hasExactTextOnlySelection({objects:[{kind:'diagram',text:'3x^2 - 1 = y'}]}),false);
  assert.equal(hasExactTextOnlySelection({objects:[{kind:'text',text:'  '}]}),false);
});
test('a selected y equation produces a graph even when model suggests another visual',()=>{
  const source=materializePlan('makeAlive','{"kind":"Wave","frequency":5}',{objects:[{kind:'text',text:'3x^2 - 1 = y'}]},'3x^2 - 1 = y');
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ir.root.children[1].type,'Graph');
  assert.deepEqual(compiled.ir.state.map(s=>s.value),[3,0,-1]);
});
test('an explicit visual instruction overrides a mismatched model type',()=>{
  const source=materializePlan('createVisual','{"kind":"Chart"}',{},'Selected content: a sequence of events\nInstruction: Make a timeline');
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ir.root.children[1].type,'Timeline');
});
test('AI motion plan writes a source-first editable InkScript for selected ink',()=>{
  const selection={strokes:[
    {id:'rod',bounds:[90,20,110,145],points:[[100,20],[108,145]]},
    {id:'bob',bounds:[95,140,125,170],points:[[110,140],[125,155]]},
    {id:'guide',bounds:[120,155,220,175],points:[[120,160],[220,170]]},
  ]};
  const source=materializePlan('animateInk','{"motion":"pendulum","speed":2,"amount":0.3,"rod":[0],"bob":[1],"static":[2]}',selection);
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ok,true,compiled.errors?.[0]?.message);
  assert.equal(compiled.ir.mode,'animateInk');
  assert.equal(compiled.ir.drawings.length,3);
  assert.deepEqual(compiled.ir.drawings.map(p=>p.id),['rod','bob','guide']);
  assert.deepEqual(compiled.ir.bindings.map(p=>p.arg),['rod','bob']);
  assert.ok(compiled.ir.animations.every(a=>a.property==='rotation'));
  assert.deepEqual(compiled.ir.bindings.map(b=>[b.pivotX,b.pivotY]),[[100,20],[100,20]]);
});
test('vision-grounded pendulum fallback compiles a fast source-first rig with gravity',()=>{
  const selection={strokes:[
    {id:'bob',bounds:[89,134,141,186],points:[[115,134],[141,160],[115,186],[89,160],[115,134]]},
    {id:'rod',bounds:[116,22,225,138],points:[[116,138],[150,100],[190,58],[225,22]]},
    {id:'pivot',bounds:[223,20,227,24],points:[[225,22]]},
  ]};
  const input='Keep the pendulum strokes. Swing the bob from its fixed pivot and include a gravity control.';
  const motionInput=JSON.stringify({...selection,observed:'A hand-drawn pendulum with a rod and bob.'});
  const output=JSON.parse(guaranteedFallback('animateInk',input,selection,motionInput));
  const compiled=compileInkScript(output.source,{capability:'BALANCED'});
  assert.equal(compiled.ok,true,compiled.errors?.[0]?.message);
  assert.equal(compiled.ir.drawings.length,3);
  assert.deepEqual(compiled.ir.bindings.map(binding=>binding.arg),['bob','rod']);
  assert.equal(compiled.ir.state.find(state=>state.name==='gravity').value,9.81);
  assert.ok(output.source.indexOf('draw(')<output.source.indexOf('ink.stroke('));
});
test('vision-grounded generic bird motion becomes a return patrol, not reveal',()=>{
  const selection={strokes:[
    {id:'bird-body',bounds:[80,90,130,125],points:[[80,108],[100,90],[130,108],[100,125],[80,108]]},
    {id:'bird-wing',bounds:[98,64,130,96],points:[[100,94],[114,64],[130,90]]},
  ]};
  const motionInput=JSON.stringify({...selection,observed:'The selected drawing is a small bird with a body and wing.'});
  const output=JSON.parse(guaranteedFallback('animateInk','animate this',selection,motionInput));
  const compiled=compileInkScript(output.source,{capability:'BALANCED'});
  assert.equal(compiled.ok,true,compiled.errors?.[0]?.message);
  assert.deepEqual(compiled.ir.bindings.map(binding=>binding.arg),['bird-body','bird-wing']);
  assert.ok(compiled.ir.animations.some(animation=>animation.property==='x'));
  assert.equal(compiled.ir.state.find(state=>state.name==='speed').value,1.4);
});
test('bird flight keeps tail and beak moving and flaps its original wing',()=>{
  const selection={strokes:[
    {id:'body',bounds:[269,326,433,428],points:[[269,394],[360,349],[423,351],[385,407]]},
    {id:'wing',bounds:[314,297,365,382],points:[[341,382],[314,297],[365,376]]},
    {id:'beak',bounds:[421,352,450,370],points:[[421,352],[450,362],[423,370]]},
    {id:'tail',bounds:[217,356,277,405],points:[[272,388],[226,356],[277,404]]},
    {id:'eye',bounds:[399,345,405,351],points:[[402,348]]},
  ]};
  const source=materializePlan('animateInk',
    '{"subject":"bird","motion":"patrol","static":[2,3],"wing":[1]}',selection,
    'Make this bird fly across the page, turn around, fly back, and repeat. Keep the original bird strokes together; flap its wings.');
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ok,true,compiled.errors?.[0]?.message);
  assert.deepEqual(compiled.ir.bindings.map(binding=>binding.arg),['body','wing','beak','tail','eye']);
  assert.deepEqual(compiled.ir.animations.filter(animation=>animation.property==='x').map(animation=>animation.target),compiled.ir.bindings.map(binding=>binding.name));
  const wing=compiled.ir.bindings.find(binding=>binding.arg==='wing');
  assert.deepEqual([wing.pivotX,wing.pivotY],[341,382]);
  assert.ok(compiled.ir.animations.some(animation=>animation.target===wing.name&&animation.property==='rotation'));
});
test('generic animate request recognizes the recorded pendulum geometry and rejects wrong model roles',()=>{
  const selection={strokes:[
    {id:'bob',bounds:[842,675,913,757],points:[[900,688],[910,714],[899,744],[866,756],[846,730],[844,698],[869,677],[900,688]]},
    {id:'rod',bounds:[858,363,1089,692],points:[[858,692],[910,580],[968,470],[1031,397],[1089,363]]},
    {id:'pivot-mark',bounds:[1072,359,1078,365],points:[[1075,362]]},
  ]};
  const recognized=recognizePendulum(selection.strokes);
  assert.equal(recognized.rod,1);
  assert.equal(recognized.bob,0);
  assert.deepEqual(recognized.pivot,[1089,363]);
  const source=materializePlan('animateInk','{"subject":"graph","motion":"wave","rod":[0],"bob":[2]}',selection,'animate this');
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ok,true,compiled.errors?.[0]?.message);
  assert.equal(compiled.ir.drawings.length,3);
  assert.deepEqual(compiled.ir.bindings.map(p=>p.arg),['bob','rod']);
  assert.ok(compiled.ir.animations.every(a=>a.property==='rotation'));
  assert.deepEqual(compiled.ir.bindings.map(b=>[b.pivotX,b.pivotY]),[[1089,363],[1089,363]]);
});
test('a straight diagonal rod and closed bob are recognized at forty-five degrees',()=>{
  const strokes=[
    {id:'bob',bounds:[89,134,141,186],points:[[115,134],[141,160],[115,186],[89,160],[115,134]]},
    {id:'rod',bounds:[116,22,225,138],points:[[116,138],[150,100],[190,58],[225,22]]},
    {id:'pivot',bounds:[223,20,227,24],points:[[225,22]]},
  ];
  const recognized=recognizePendulum(strokes);
  assert.deepEqual({rod:recognized.rod,bob:recognized.bob,pivot:recognized.pivot},{rod:1,bob:0,pivot:[225,22]});
  const source=materializePlan('animateInk','{"motion":"j-animation"}',{strokes},'animate this');
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ir.drawings.length,3);
  assert.equal(compiled.ir.state.find(s=>s.name==='speed').value,2);
  assert.ok(compiled.ir.animations.length>0);
});
test('pendulum InkScript exposes gravity and changes its period with the Moon modifier',()=>{
  const source=materializePlan('animateInk','{"subject":"pendulum","motion":"pendulum"}',{strokes:[
    {id:'rod',bounds:[218,40,247,228],points:[[220,40],[245,225]]},
    {id:'bob',bounds:[220,200,270,250],points:[[245,200],[270,225],[245,250],[220,225],[245,200]]},
  ]},'animate this');
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ok,true,compiled.errors?.[0]?.message);
  assert.equal(compiled.ir.state.find(s=>s.name==='gravity').value,9.81);
  assert.match(source,/Math\.sqrt\(gravity \/ 9\.81\)/);
  assert.equal(compiled.ir.animations[0].property,'rotation');
});
test('bee instructions compile to source-first patrol InkScript with physics controls',()=>{
  const selection={strokes:[
    {id:'bee-body',bounds:[80,90,130,125],points:[[80,108],[100,90],[130,108],[100,125],[80,108]]},
    {id:'bee-wing',bounds:[98,64,130,96],points:[[100,94],[114,64],[130,90]]},
    {id:'guide',bounds:[40,145,420,150],points:[[40,148],[420,148]]},
  ]};
  const intent='Animate the bee to go to the other side, turn back, and go back and forth. Put boxes for gravity and speed under it.';
  const source=materializePlan('animateInk','{"subject":"bee","motion":"reveal"}',selection,intent);
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ok,true,compiled.errors?.[0]?.message);
  assert.equal(compiled.ir.drawings.length,3);
  assert.deepEqual(compiled.ir.state.map(s=>s.name),['speed','gravity']);
  assert.deepEqual(compiled.ir.bindings.map(p=>p.arg),['bee-body','bee-wing','guide']);
  assert.ok(compiled.ir.animations.some(a=>a.property==='x'));
});
test('bird patrol keeps a misclassified tail with the original moving ink',()=>{
  const strokes=[
    {id:'body',bounds:[264,347,416,433],points:[[416,390],[340,347],[264,390],[340,433],[416,390]]},
    {id:'wing',bounds:[279,324,342,407],points:[[325,378],[279,324],[342,407]]},
    {id:'beak',bounds:[408,386,448,405],points:[[408,386],[448,397],[409,405]]},
    {id:'tail',bounds:[230,367,274,414],points:[[270,386],[235,367],[251,395],[230,414],[274,405]]},
    {id:'eye',bounds:[388,375,394,381],points:[[391,375],[394,378],[391,381]]},
    {id:'feather',bounds:[315,414,350,449],points:[[315,414],[335,449],[350,416]]},
  ];
  const source=materializePlan('animateInk','{"subject":"bird","motion":"patrol","static":[3]}',{strokes},'Make this bird fly across the page, turn around, and fly back.');
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ok,true,compiled.errors?.[0]?.message);
  assert.deepEqual(compiled.ir.bindings.map(binding=>binding.arg),strokes.map(stroke=>stroke.id));
  assert.equal(compiled.ir.animations.filter(animation=>animation.property==='x').length,strokes.length);
});
test('patrol leaves a distinct ground guide fixed when the planner marks it static',()=>{
  const strokes=[
    {id:'ball',bounds:[290,340,390,440],points:[[390,390],[340,340],[290,390],[340,440],[390,390]]},
    {id:'seam',bounds:[320,345,355,435],points:[[340,345],[355,390],[340,435]]},
    {id:'ground',bounds:[180,510,520,510],points:[[180,510],[520,510]]},
  ];
  const source=materializePlan('animateInk','{"subject":"ball","motion":"patrol","static":[2]}',{strokes},'Move the ball across and back.');
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ok,true,compiled.errors?.[0]?.message);
  assert.deepEqual(compiled.ir.bindings.map(binding=>binding.arg),['ball','seam']);
});
test('AI can compose a distinct scene from shapes',()=>{
  const source=materializePlan('createVisual',JSON.stringify({kind:'Scene',title:'Orbit sketch',shapes:[{type:'Circle',x:80,y:95,radius:24},{type:'Arrow',x1:105,y1:95,x2:250,y2:95}]}));
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ok,true,compiled.errors?.[0]?.message);
  assert.equal(compiled.ir.root.children[1].type,'Scene');
  assert.equal(compiled.ir.root.children[1].children.length,2);
});
test('model animation output is normalized into draw-first InkScript',()=>{
  const input=JSON.stringify({strokes:[{id:'bee',points:[[1,2],[3,4]]}]});
  const output=JSON.parse(validateAiOutput('animateInk',
    'export default function Animation() { const part = ink.stroke("bee"); animate(({ time }) => { part.x = part.baseX + Math.abs(Math.sin(time * 1.4)) * 240; }); }',input));
  assert.equal(output.ir.drawings[0].id,'bee');
  assert.equal(output.ir.bindings[0].arg,'bee');
  assert.equal(output.ir.animations[0].property,'x');
  assert.ok(output.source.indexOf('draw(')<output.source.indexOf('ink.stroke('));
});

test('wind bends flower strokes around a shared root without replacing the ink',()=>{
  const strokes=[
    {id:'stem',bounds:[100,100,100,250],points:[[100,250],[100,100]]},
    {id:'petal',bounds:[80,80,120,100],points:[[100,100],[80,80],[120,80],[100,100]]},
  ];
  const source=materializePlan('animateInk','{"subject":"flower","motion":"bend"}',{strokes},'Make this flower bend and sway in the wind. Keep its roots anchored.');
  const compiled=compileInkScript(source,{capability:'BALANCED'});
  assert.equal(compiled.ok,true,JSON.stringify(compiled.errors));
  assert.deepEqual(compiled.ir.drawings.map(s=>s.id),['stem','petal']);
  assert.equal(compiled.ir.animations.filter(a=>a.property==='bend').length,2);
});
