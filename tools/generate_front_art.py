"""Circular gilded icon chrome and restrained magical accents for live widgets."""
from pathlib import Path
import math,random
from PIL import Image,ImageDraw,ImageFilter
out=Path(__file__).resolve().parents[1]/'Media'
size=128
ring=Image.new('RGBA',(size,size))
pixels=ring.load()
for y in range(size):
    for x in range(size):
        dx,dy=x-63.5,y-63.5
        radius=math.hypot(dx,dy)
        if 44<=radius<=54:
            light=(1-math.cos((radius-44)/10*math.pi*2))*.34+.35
            light+=max(0,(-dx-dy)/100)*.25
            pixels[x,y]=(int(255*light),int(205*light),int(92*light),255)
        elif 54<radius<61:
            pixels[x,y]=(220,159,45,int(55*(61-radius)/7))
        elif 42<=radius<44:
            pixels[x,y]=(31,20,5,255)
d=ImageDraw.Draw(ring)
for i in range(4):
    a=i*math.pi/2
    x,y=63.5+math.cos(a)*50,63.5+math.sin(a)*50
    d.ellipse((x-1.7,y-1.7,x+1.7,y+1.7),fill=(255,228,150))
ring.save(out/'f_item_ring.tga',compression=None)
mask=Image.new('RGBA',(128,128))
ImageDraw.Draw(mask).ellipse((0,0,127,127),fill=(255,255,255,255))
mask.save(out/'f_circle_mask.tga',compression=None)
well=Image.new('RGBA',(128,128))
ImageDraw.Draw(well).ellipse((10,10,117,117),fill=(6,8,12,255))
well.save(out/'f_icon_well.tga',compression=None)
check=Image.new('RGBA',(128,128))
ImageDraw.Draw(check).line([(29,63),(54,87),(99,35)],fill=(255,255,255,255),width=12)
check.save(out/'f_check.tga',compression=None)
for name,alpha in [('f_row_selected',145),('f_row_hover',60)]:
    row=Image.new('RGBA',(256,64))
    px=row.load()
    for y in range(64):
        for x in range(256):
            a=int(alpha*(1-x/330)*(.72+.28*math.cos((y-32)*math.pi/64)))
            px[x,y]=(125,89,21,max(0,a))
    d=ImageDraw.Draw(row)
    d.line((0,1,255,1),fill=(199,155,58,100),width=1)
    d.line((0,62,255,62),fill=(199,155,58,100),width=1)
    d.line((1,2,1,61),fill=(255,211,100,230),width=2)
    row.save(out/(name+'.tga'),compression=None)
r=random.Random(124)
header=Image.new('RGBA',(1024,128))
px=header.load()
for y in range(128):
    for x in range(1024):
        halo=math.exp(-((x-400)/390)**2-((y-65)/100)**2)
        n=r.random()*1.3
        px[x,y]=(int(16+n+halo*15),int(20+n+halo*9),int(29+n+halo*3),255)
draw=ImageDraw.Draw(header)
for i in range(36):
    x=r.randrange(120,990);y=r.randrange(12,115)
    draw.ellipse((x,y,x+1,y+1),fill=(184,144,67,90))
draw.line((0,124,1023,124),fill=(148,116,52,255),width=1)
draw.line((0,126,1023,126),fill=(31,25,15,255),width=1)
header.save(out/'f_header.tga',compression=None)
print('Generated gilded item rings, circular mask, row effects and header')
