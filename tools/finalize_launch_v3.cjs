const fs=require('node:fs');
const path=require('node:path');
const {execFileSync}=require('node:child_process');
const base=path.resolve(__dirname,'../demo/video');
const kind=process.argv[2];
if(!['clean','captioned'].includes(kind))throw Error('Choose clean or captioned');
const name=`inkmind-launch-trailer-v3-${kind}`;
const input=path.join(base,'out',`${name}.mp4`);
const output=path.join(base,'out',`${name}-synced.mp4`);
const ffmpeg=path.join(base,'node_modules/@remotion/compositor-win32-x64-msvc/ffmpeg.exe');
// Encode the aligned PCM once: the render's intermediate AAC adds ~43 ms.
execFileSync(ffmpeg,['-hide_banner','-loglevel','error','-y','-i',input,'-i',path.join(base,'public/audio/launch-v3-master.wav'),'-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','aac','-b:a','320k','-t','81.166667','-movflags','+faststart',output],{stdio:'inherit'});
if(fs.statSync(output).size<1000000)throw Error('Unexpectedly small final export');
fs.copyFileSync(output,input);
execFileSync(ffmpeg,['-hide_banner','-loglevel','error','-y','-i',input,'-vn','-ar','44100','-ac','2',path.join(base,'out',`v3-${kind}-encoded-audio.wav`)],{stdio:'inherit'});
console.log(JSON.stringify({output:input,bytes:fs.statSync(input).size,masterAudioReplaced:true}));
