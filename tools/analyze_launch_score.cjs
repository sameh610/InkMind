const fs=require('node:fs');
const b=fs.readFileSync('demo/video/out/score-v3-analysis.wav');
let offset=12,rate,channels,data;
while(offset+8<=b.length){const id=b.toString('ascii',offset,offset+4),n=b.readUInt32LE(offset+4);if(id==='fmt '){channels=b.readUInt16LE(offset+10);rate=b.readUInt32LE(offset+12);}if(id==='data')data=b.subarray(offset+8,offset+8+n);offset+=8+n+(n%2);}
const hop=Math.round(rate*.01),energy=[];let low=0;
for(let i=0;i<data.length/2;i+=hop){let sum=0;for(let j=i;j<Math.min(i+hop,data.length/2);j++){const s=data.readInt16LE(j*2)/32768;low+=(s-low)*.035;sum+=low*low;}energy.push(Math.sqrt(sum/hop));}
const onset=energy.map((v,i)=>Math.max(0,v-(energy[i-2]||0)));
const candidates=[];
for(let bpm=125;bpm<=138;bpm+=.1){const beat=60/bpm;for(let phase=0;phase<beat;phase+=.01){let score=0;for(let t=phase;t<70;t+=beat){const i=Math.round(t/.01);score+=Math.max(onset[i-1]||0,onset[i]||0,onset[i+1]||0);}candidates.push({bpm:+bpm.toFixed(1),phase:+phase.toFixed(2),score});}}
candidates.sort((a,b)=>b.score-a.score);
const sectionRms=Array.from({length:9},(_,i)=>{const slice=energy.slice(i*900,(i+1)*900);return{from:i*9,rms:Math.sqrt(slice.reduce((s,v)=>s+v*v,0)/slice.length)}});
const result={seconds:data.length/2/rate,candidates:candidates.slice(0,6),sectionRms};
fs.writeFileSync('demo/video/launch-v3/score-analysis.json',JSON.stringify(result,null,2));console.log(result);
