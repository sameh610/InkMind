const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const base=path.resolve(__dirname,'../demo/video');
const edit=JSON.parse(fs.readFileSync(path.join(base,'launch-v3-cut.json')));
const voice=JSON.parse(fs.readFileSync(path.join(base,'launch-v3-voice.json')));
let end=0;
for(const shot of edit.shots){
  assert(Math.abs(shot.from-end)<1/60,'Picture gap or overlap');
  assert(shot.to>shot.from&&shot.source>=0&&(shot.rate||1)>0,'Invalid source range');
  assert(fs.existsSync(path.join(base,'public',shot.clip)),`Missing ${shot.clip}`);
  end=shot.to;
}
assert(Math.abs(end-edit.logo)<1/60,'Logo must follow the final shot');
assert.equal(Math.round(edit.duration*30),2435);
let lastVoiceEnd=0;
for(const cue of voice.cues){
  assert(cue.from>=lastVoiceEnd&&cue.to>cue.from&&cue.to<edit.duration,'Overlapping or truncated speech');
  lastVoiceEnd=cue.to;
}
assert.equal(voice.cues.map(c=>c.text).join(' ').split(/\s+/).length,53);
for(const mode of ['pendulum','debug','graph','bird']){
  const runs=JSON.parse(fs.readFileSync(path.join(base,'launch-v3',`${mode}-report.json`)));
  assert.equal(runs.length,10,`${mode} requires ten runs`);
  assert(runs.every(r=>r.success&&r.errors.length===0),`${mode} has a failed run`);
}
const mix=JSON.parse(fs.readFileSync(path.join(base,'launch-v3/audio-validation.json')));
assert.equal(mix.clippedSamples,0);
console.log(JSON.stringify({frames:2435,shots:edit.shots.length,spokenWords:53,liveRuns:40,pictureContiguous:true,narrationOverlaps:false,clippedSamples:0}));
