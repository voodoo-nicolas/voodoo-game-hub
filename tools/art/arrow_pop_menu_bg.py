# Arrow Pop menu backdrop: self-made, procedural (no third-party asset).
# Deep ink-blue felt grain + embossed bubble-wrap dots in a hex grid. 720x1280.
import random, math
from PIL import Image, ImageDraw, ImageFilter
random.seed(4242)
W,H=720,1280
img=Image.new("RGB",(W,H))
px=img.load()
top=(18,30,52); bot=(10,16,30)
for y in range(H):
    t=y/(H-1)
    for x in range(W):
        n=random.randint(-7,7)
        px[x,y]=tuple(max(0,min(255,int(top[i]*(1-t)+bot[i]*t)+n)) for i in range(3))
img=img.filter(ImageFilter.GaussianBlur(0.6))
# bubble-wrap: shadow below-right, highlight above-left, per bubble
hi=Image.new("L",(W,H),0); sh=Image.new("L",(W,H),0)
dh=ImageDraw.Draw(hi); ds=ImageDraw.Draw(sh)
r=22; step=60
for row,y in enumerate(range(-step, H+step, int(step*0.866))):
    off= step/2 if row%2 else 0
    for x in range(-step, W+step, step):
        cx,cy=x+off,y
        ds.ellipse([cx-r+3,cy-r+4,cx+r+3,cy+r+4],fill=90)
        dh.ellipse([cx-r,cy-r,cx+r-4,cy+r-5],fill=55)
        dh.ellipse([cx-r*0.55,cy-r*0.6,cx-r*0.1,cy-r*0.2],fill=120)
hi=hi.filter(ImageFilter.GaussianBlur(3)); sh=sh.filter(ImageFilter.GaussianBlur(4))
img=Image.composite(Image.new("RGB",(W,H),(4,7,14)),img,sh)
img=Image.composite(Image.new("RGB",(W,H),(70,110,150)),img,hi.point(lambda v:int(v*0.55)))
img.save("games/arrow_pop/menu_bg.jpg", quality=86, optimize=True)
print("saved", img.size)
