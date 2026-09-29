from pathlib import Path
from PIL import Image, ImageDraw

source = Path('video-review')
dest = Path('demo/video/out/half-second-review')
dest.mkdir(parents=True, exist_ok=True)
files = sorted(source.glob('frame-*.png'),key=lambda p:int(p.stem.split('-')[1]))[:163]
for start in range(0,len(files),20):
    batch=files[start:start+20]
    sheet=Image.new('RGB',(1920,((len(batch)+4)//5)*238),'#e7e2d9')
    pen=ImageDraw.Draw(sheet)
    for index,file in enumerate(batch):
        x=index%5*384;y=index//5*238
        sheet.paste(Image.open(file).resize((384,216)),(x,y))
        pen.text((x+8,y+219),f'{(start+index)*.5:.1f} s',fill='#203a30')
    sheet.save(dest/f'page-{start//20+1:02}.png')
print(f'{len(files)} exported frames in {(len(files)+19)//20} review sheets')
