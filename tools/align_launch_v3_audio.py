"""Place verified spoken phrases against the locked, 30 fps action edit."""
from pathlib import Path
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / 'demo/video'
RATE = 44100
edit = json.loads((ROOT / 'launch-v3-cut.json').read_text())
size = round(edit['duration'] * RATE)

def read(name):
    with wave.open(str(ROOT / 'public/audio' / name), 'rb') as src:
        assert src.getframerate() == RATE and src.getsampwidth() == 2
        return np.frombuffer(src.readframes(src.getnframes()), dtype='<i2').reshape(-1, src.getnchannels()).astype(np.float64) / 32768

def write(name, samples):
    with wave.open(str(ROOT / 'public/audio' / name), 'wb') as dest:
        dest.setnchannels(samples.shape[1]); dest.setsampwidth(2); dest.setframerate(RATE)
        dest.writeframes((np.clip(samples, -.999, .999) * 32767).astype('<i2').tobytes())

# Boundaries measured on the waveform (10 ms windows), with consonant/tail
# padding. The independently transcribed take matches all fourteen phrases.
phrases = [
    (.03,.78,.65,'Select your ink.'),
    (1.35,2.14,3.65,'Tell it how to move.'),
    (3,4.46,6.45,'The original strokes come alive.'),
    (5.32,6.46,11.9,'Drop in Moon gravity.'),
    (7.34,8.45,20.02,'Rewind your reasoning.'),
    (9.1,10.45,22.75,'Find the first wrong step.'),
    (11.25,12.11,24.58,'Draw a better branch.'),
    (12.81,15.27,34.25,'Turn an equation into something you can touch.'),
    (15.97,16.98,45.95,'Let your sketches move.'),
    (17.87,18.42,53,'Real ink.'),
    (19.06,19.73,56.45,'Real code.'),
    (20.37,20.78,60.15,'Your model.'),
    (21.45,21.96,78.3,'InkMind.'),
    (22.55,23.47,79.35,'Paper you can think with.'),
]
source = read('narration-v3-take2.wav')
voice = np.zeros((size, 2))
cues = []
for start,end,at,text in phrases:
    source_start=max(0,start-.06); source_end=end+.10
    clip=source[round(source_start*RATE):round(source_end*RATE)].copy()
    fade=min(220,len(clip)//2)
    clip[:fade]*=np.linspace(0,1,fade)[:,None]; clip[-fade:]*=np.linspace(1,0,fade)[:,None]
    destination=round((at-(start-source_start))*RATE)
    voice[destination:destination+len(clip)] += clip
    cues.append({'from':at,'to':round(at+end-start+.10,3),'text':text,'sourceFrom':source_start,'sourceTo':source_end})
voice *= .78 / max(abs(voice).max(), .0001)
write('narration-v3-aligned.wav', voice)
(ROOT/'launch-v3-voice.json').write_text(json.dumps({'voice':'Charlie','take':2,'cues':cues},indent=2)+'\n')

music=read('inkmind-score-v3-aligned.wav')[:size]
effects=read('sound-design-v3.wav')[:size]
t=np.arange(size)/RATE
gain=np.full(size,.72)
for cue in cues:
    enter=np.clip((t-cue['from']+.15)/.15,0,1)
    leave=np.clip((cue['to']+.2-t)/.2,0,1)
    gain=np.minimum(gain,.72-.47*np.minimum(enter,leave))
gain*=np.clip((edit['duration']-t)/.12,0,1)
mix=music*gain[:,None]+effects*.68+voice
peak=float(abs(mix).max()); master_gain=min(1,.95/max(peak,.0001));mix*=master_gain
write('launch-v3-master.wav',mix)

def timecode(t):
    ms=round(t*1000); return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}'
(ROOT/'out/inkmind-launch-trailer-v3.srt').write_text('\n\n'.join(f"{i+1}\n{timecode(c['from'])} --> {timecode(c['to'])}\n{c['text']}" for i,c in enumerate(cues))+'\n')
report={'duration':edit['duration'],'spokenWords':len(' '.join(c['text'] for c in cues).split()),'phrases':len(cues),'peakBeforeMasterGain':peak,'masterGain':master_gain,'peak':float(abs(mix).max()),'rms':float(np.sqrt(np.mean(mix**2))),'clippedSamples':int(np.count_nonzero(abs(mix)>=1))}
(ROOT/'launch-v3/audio-validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
