"""Splice the verified Debug replacement and stream both final masters."""
from pathlib import Path
import subprocess, json, io, struct
from PIL import Image, ImageDraw, ImageFont

root=Path(__file__).resolve().parents[1]/'demo/video'
ffmpeg=str(root/'node_modules/@remotion/compositor-win32-x64-msvc/ffmpeg.exe')
out=root/'out'
base=out/'inkmind-launch-trailer-v3-clean-synced.mp4'
patch=out/'v3-debug-corrected.mp4'
audio=root/'public/audio/launch-v3-master.wav'
cues=json.loads((root/'launch-v3-voice.json').read_text())['cues']
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',32)
size=1920*1080*3
def decode(file):
    return subprocess.Popen([ffmpeg,'-hide_banner','-loglevel','error','-i',str(file),'-an','-threads','1','-f','image2pipe','-c:v','png','pipe:1'],stdout=subprocess.PIPE)
def read_png(stream):
    signature=stream.read(8)
    if signature!=b'\x89PNG\r\n\x1a\n':raise RuntimeError('Missing PNG frame')
    data=bytearray(signature)
    while True:
        header=stream.read(8)
        if len(header)!=8:raise RuntimeError('Incomplete PNG header')
        length=struct.unpack('>I',header[:4])[0]
        payload=stream.read(length+4)
        if len(payload)!=length+4:raise RuntimeError('Incomplete PNG chunk')
        data.extend(header);data.extend(payload)
        if header[4:]==b'IEND':return bytes(data)
def encode(kind):
    return subprocess.Popen([ffmpeg,'-hide_banner','-loglevel','error','-y','-f','image2pipe','-c:v','png','-framerate','30','-i','pipe:0','-i',str(audio),'-map','0:v:0','-map','1:a:0','-c:v','libx264','-preset','fast','-threads','2','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-b:a','320k','-t',str(2435/30),'-movflags','+faststart',str(out/f'inkmind-launch-trailer-v3-{kind}.mp4')],stdin=subprocess.PIPE)
original=decode(base);replacement=decode(patch)
clean=encode('clean');captioned=encode('captioned')
processes=[original,replacement,clean,captioned]
try:
    for frame in range(2435):
        data=read_png(original.stdout)
        if 600<=frame<873:
            data=read_png(replacement.stdout)
        clean.stdin.write(data)
        cue=next((c for c in cues if c['from']<=frame/30<c['to']),None)
        if cue:
            image=Image.open(io.BytesIO(data)).convert('RGB')
            draw=ImageDraw.Draw(image,'RGBA');b=draw.textbbox((0,0),cue['text'],font=font)
            w,h=b[2]-b[0],b[3]-b[1];left=(1920-w)/2;top=1080-70-h-20
            draw.rounded_rectangle((left-20,top-12,left+w+20,top+h+12),radius=7,fill=(10,26,20,226))
            draw.text((left,top-b[1]),cue['text'],font=font,fill=(248,244,234,255))
            encoded=io.BytesIO();image.save(encoded,format='PNG',compress_level=1);data=encoded.getvalue()
        captioned.stdin.write(data)
        if frame%300==0:print(f'Finished {frame}/2435 frames for both masters',flush=True)
    clean.stdin.close();captioned.stdin.close()
    original.stdout.close();replacement.stdout.close()
    for process in processes:
        if process.wait()!=0:raise RuntimeError('Video finishing failed')
    print('Both final masters exported.',flush=True)
except BaseException:
    for process in processes:process.kill()
    raise
