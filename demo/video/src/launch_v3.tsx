import React from 'react';
import {AbsoluteFill,Audio,Sequence,staticFile,useCurrentFrame,interpolate} from 'remotion';
import {SourceShot,TextHit,ClosingCard,CaptionLayer,type Shot} from './video';
import edit from '../launch-v3-cut.json';
import voice from '../launch-v3-voice.json';
const f=(s:number)=>Math.round(s*30);
export const LAUNCH_FRAMES=f(edit.duration);

const Pipeline:React.FC=()=>{
  const frame=useCurrentFrame();
  const opacity=interpolate(frame,[0,5,96,109],[0,1,1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
  return <div style={{position:'absolute',left:60,top:215,width:680,padding:28,background:'rgba(24,44,35,.96)',border:'1px solid #5c7568',borderRadius:10,color:'#f8f4ea',opacity,fontFamily:'Consolas, monospace'}}>
    <div style={{fontFamily:'Arial',fontSize:14,letterSpacing:2,color:'#e58b63',marginBottom:18}}>ACTUAL GENERATED INKSCRIPT</div>
    <pre style={{fontSize:19,lineHeight:1.8,whiteSpace:'pre-wrap',overflowWrap:'anywhere',margin:0}}>{edit.program}</pre>
    <div style={{marginTop:18,fontFamily:'Arial',fontSize:17,color:'#b2c9bb'}}>Same stroke IDs. Same ink. Executable motion.</div>
  </div>;
};
export const LaunchV3:React.FC<{showCaptions:boolean;pictureOnly?:boolean}>=({showCaptions,pictureOnly=false})=><AbsoluteFill style={{background:'#f8f4ea'}}>
  {(edit.shots as unknown as Shot[]).map((shot,i)=><Sequence key={i} from={f(shot.from)} durationInFrames={f(shot.to)-f(shot.from)}><SourceShot shot={shot}/></Sequence>)}
  {edit.hits.map((hit,i)=><Sequence key={i} from={f(hit.from)} durationInFrames={f(hit.to)-f(hit.from)}><TextHit hit={hit}/></Sequence>)}
  <Sequence from={f(56.36)} durationInFrames={110}><Pipeline/></Sequence>
  <Sequence from={f(edit.logo)}><ClosingCard/></Sequence>
  {!pictureOnly&&<Audio src={staticFile('audio/launch-v3-master.wav')}/>}
  {showCaptions&&<CaptionLayer captions={voice.cues.map(c=>({text:c.text,startMs:c.from*1000,endMs:c.to*1000,timestampMs:null,confidence:null}))}/>}
</AbsoluteFill>;
