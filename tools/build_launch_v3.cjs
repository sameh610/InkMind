const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../demo/video');
const fps=30, beat=60/132, bar=beat*4;
const reports={};
for(const name of ['pendulum','debug','graph','projectile','bird','flower','billing']) {
  const runs=JSON.parse(fs.readFileSync(path.join(root,'launch-v3',`${name}-report.json`)));
  const first=runs.find(r=>r.success);
  if(!first)throw Error(`No verified ${name} take`);
  reports[name]=first;
}
const mark=(name,key)=>{
  const value=reports[name].marks.find(m=>m.name===key)?.seconds;
  if(value==null)throw Error(`Missing ${name}/${key}`);return value;
};
const shots=[], cues=[], hits=[];let cursor=0;
const round=n=>Math.round(n*fps)/fps;
function cut(to,name,source,rate=1,zoom=1.45,focus=[.5,.5],label){
  to=round(to);if(to<=cursor)throw Error('Empty shot');
  shots.push({from:cursor,to,clip:name==='models'?'footage/inkmind-action-models.webm':`footage/v3-${name}.webm`,source,rate,zoom,focus,...(label?{label}:{})});cursor=to;
}
function span(to,name,a,b,zoom,focus,label){cut(to,name,a,(b-a)/(round(to)-cursor),zoom,focus,label);}
function cue(kind,at=cursor){cues.push({at:round(at),kind});}
function hit(text,from,duration=.8){hits.push({text,from:round(from),to:round(from+duration)});}

// 0–8.18: selection, menu, instruction, execute, then the ORIGINAL ink moves.
cut(.6,'pendulum',mark('pendulum','input'),1,1.8,[.5,.41]);hit('DRAW IT.',0,.6);
span(2.3,'pendulum',mark('pendulum','select-start'),mark('pendulum','selected'),1.65,[.5,.43]);cue('select',.6);
span(3.5,'pendulum',mark('pendulum','selected'),mark('pendulum','command'),2,[.75,.75]);
span(5.7,'pendulum',mark('pendulum','command'),mark('pendulum','execute'),1.6,[.5,.43]);cue('click',5.55);
span(6.4,'pendulum',mark('pendulum','result'),mark('pendulum','motion'),1.4,[.5,.5],'Local vision · model wait shortened');
cue('activate');cut(bar*4.5,'pendulum',mark('pendulum','motion'),1,1.62,[.5,.49]);hit('MOVE IT.',6.4);

// Moon pickup → drag → drop: retain the physical interaction continuously.
const moon=mark('pendulum','moon-pickup'),drop=mark('pendulum','moon-drop');
cut(bar*5.25,'pendulum',moon-.7,1,1.45,[.43,.62]);cue('lift',bar*5.25);
span(bar*6.5,'pendulum',moon-.15,drop+.05,1.2,[.49,.55]);cue('drop');
cut(bar*7.5,'pendulum',drop+.05,1,1.35,[.5,.56],'g = 1.62 m/s²');cue('gravity',bar*6.5+.1);hit('CHANGE THE RULES.',bar*6.5+.25);
cut(bar*9,'pendulum',drop+1.8,1,1.6,[.5,.48]);

// Stored samples actually rewind. The branch is drawn by Flutter itself.
cut(bar*9+.6,'debug',mark('debug','input'),1,1.8,[.43,.34]);
span(bar*10.5,'debug',mark('debug','select-start'),mark('debug','selected'),1.6,[.43,.35]);
span(bar*11,'debug',mark('debug','selected'),mark('debug','execute')+.04,2,[.75,.75]);cue('click');
const replay=mark('debug','replay');
span(bar*12.5,'debug',replay+.35,replay+1.42,1.58,[.485,.65],'Original stroke order · rewind');cue('rewind',bar*11);
span(bar*13.5,'debug',replay+1.42,replay+1.9,1.9,[.442,.636],'First divergence: 3x = 25');cue('stop',bar*12.5);
span(bar*15,'debug',replay+1.9,replay+3.1,1.7,[.49,.66]);cue('branch',bar*13.5);
span(bar*16,'debug',replay+3.1,replay+3.4,1.6,[.49,.67]);hit('DEBUG YOUR THINKING.',bar*15);

// Graph creation and an actual coefficient crossing zero.
cut(bar*16+.55,'graph',mark('graph','input'),1,1.9,[.45,.32]);
span(bar*17.25,'graph',mark('graph','select-start'),mark('graph','selected'),1.55,[.47,.37]);
span(bar*18,'graph',mark('graph','selected'),mark('graph','command'),2,[.75,.75]);
span(bar*18.8,'graph',mark('graph','instruction')-.45,mark('graph','execute'),1.55,[.5,.44]);
span(bar*19.5,'graph',mark('graph','result')-.13,mark('graph','slider-positive'),1.35,[.49,.54]);cue('unfold',bar*18.8);
span(bar*21,'graph',mark('graph','slider-positive')-.3,mark('graph','slider-negative')+.75,1.48,[.495,.59]);cue('slider',bar*19.5);hit('TOUCH THE EQUATION.',bar*19.5);

// Second New Visual: exact supplied velocity and launch angle.
span(bar*21.7,'projectile',mark('projectile','select-start'),mark('projectile','selected'),1.6,[.48,.35]);
span(bar*22.3,'projectile',mark('projectile','make-alive'),mark('projectile','command'),2,[.75,.75]);
cut(bar*23,'projectile',mark('projectile','result')+.2,1,1.5,[.49,.57]);cue('unfold',bar*22.3);

// Generality: a bird flying, then a flower bending on its original root.
span(bar*24,'bird',mark('bird','select-start'),mark('bird','selected'),1.6,[.5,.46]);
span(bar*24.65,'bird',mark('bird','make-alive'),mark('bird','command'),2,[.75,.75]);
cut(bar*25.2,'bird',mark('bird','instruction')-.3,1,1.55,[.5,.44]);
cut(bar*26.5,'bird',mark('bird','motion')+.15,1,1.4,[.62,.5]);cue('air',bar*25.2);
span(bar*27.2,'flower',mark('flower','select-start'),mark('flower','selected'),1.55,[.5,.46]);
cut(bar*27.8,'flower',mark('flower','instruction')-.3,1,1.5,[.5,.43]);
cut(bar*29,'flower',mark('flower','motion')+.4,1,1.75,[.5,.49]);hit('YOUR INK. STILL YOUR INK.',bar*27.8);

// A short, source-backed overlay will identify the actual bound stroke IDs.
cut(bar*30,'pendulum',mark('pendulum','selected')-.2,1,1.7,[.5,.44],'INK · original vector strokes');
cut(bar*31,'pendulum',mark('pendulum','motion')+.1,1,1.7,[.5,.49],'UNDERSTAND · support / rod / bob');
cut(bar*32,'pendulum',mark('pendulum','motion')+.4,.6,1.55,[.5,.49],'PROGRAM · bound to original stroke IDs');
cut(bar*33,'pendulum',drop+.5,1.2,1.7,[.5,.49],'MOVE · deterministic runtime');
cut(bar*34,'models',.2,1,1.4,[.5,.42]);
cut(bar*35,'models',1.1,1,1.4,[.5,.42]);hit('YOUR MODEL. YOUR DEVICE.',bar*33);

// Genuine SDK checkout, genuine Test Store entitlement.
span(bar*36,'billing',mark('billing','paywall'),mark('billing','checkout'),1.48,[.5,.58]);
span(bar*37.5,'billing',mark('billing','checkout')+1,mark('billing','entitlement'),1.25,[.5,.5],'RevenueCat Test Store · no real charge');
cut(bar*39,'billing',mark('billing','entitlement'),.38,1.45,[.5,.65],'Subscriptions powered by RevenueCat');hit('A REAL PRODUCT.',bar*37.5);

// The peak: ten short cuts, then a three-second brand button.
const montage=[['pendulum','motion',0],['pendulum','moon-drop',-.1],['debug','replay',.3],['debug','replay',1.5],['debug','replay',2.4],['graph','slider-positive',0],['graph','slider-negative',-.2],['bird','motion',1],['flower','motion',2],['projectile','result',.7]];
for(let i=0;i<montage.length;i++){
  const [name,event,offset]=montage[i];cut(bar*39+(i+1)*(bar*4/10),name,mark(name,event)+offset,1.1,name==='debug'?1.7:1.5,name==='debug'?[.49,.65]:name==='bird'?[.6,.5]:[.5,.53]);
}
hit('DRAW.',bar*39,.6);hit('THINK.',bar*40.3,.6);hit('RUN.',bar*41.7,.6);cue('logo',bar*43);
const logo=round(bar*43),duration=round(logo+3);
const program=reports.pendulum.evidence.source.split('\n').filter(line=>/const (?:gravity|part_)|part_\d+\.rotation/.test(line)).join('\n');
const edit={fps,bpm:132,duration,logo,shots,hits,cues,program};
fs.writeFileSync(path.join(root,'launch-v3-cut.json'),JSON.stringify(edit,null,2));
fs.writeFileSync(path.join(root,'action-cues.json'),JSON.stringify(cues,null,2));
console.log(JSON.stringify({shots:shots.length,duration,logo,bpm:132}));
