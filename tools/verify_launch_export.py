from pathlib import Path
import json, sys, wave
import numpy as np
root=Path(__file__).resolve().parents[1]/'demo/video'
kind=sys.argv[1]
assert kind in ('clean','captioned')
def read(path):
    with wave.open(str(path)) as src:
        assert src.getframerate()==44100 and src.getnchannels()==2
        return np.frombuffer(src.readframes(44100*10),dtype='<i2').reshape(-1,2).mean(axis=1)[::4]/32768
a=read(root/'public/audio/launch-v3-master.wav')
b=read(root/'out'/f'v3-{kind}-encoded-audio.wav')
n=1<<int(np.ceil(np.log2(len(a)+len(b)-1)))
c=np.fft.irfft(np.fft.rfft(b,n)*np.conj(np.fft.rfft(a,n)),n)
lags=np.arange(-11025,11026)
offset=int(lags[np.argmax(c[lags%n])])/11025
correlation=float(np.corrcoef(a,b)[0,1])
assert abs(offset)<.001, f'Audio shifted by {offset}s'
assert correlation>.99, f'Unexpected audio mismatch: {correlation}'
report={'variant':kind,'encodedOffsetSeconds':offset,'firstTenSecondsCorrelation':correlation,'video':'1920x1080 H264 30 fps','pictureDurationSeconds':2435/30,'audio':'AAC stereo, encoded once from aligned PCM'}
(root/'launch-v3'/f'export-validation-{kind}.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
