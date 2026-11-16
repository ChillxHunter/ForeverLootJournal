"""Deterministic, sliceable UI materials matching the supplied option D.

No labels or controls are baked into these assets: Lua renders all live text,
checks, numbers, selection state and interactions.
"""
from pathlib import Path
import math
import random
from PIL import Image,ImageDraw,ImageFilter,ImageFont

OUT=Path(__file__).resolve().parents[1]/'Media'
OUT.mkdir(exist_ok=True)
R=random.Random(184)

def material(name,top,bottom,edge,inner,radius=7,glow=None):
    im=Image.new('RGBA',(256,256))
    mask=Image.new('L',im.size)
    ImageDraw.Draw(mask).rounded_rectangle((2,2,253,253),radius,fill=255)
    pix=im.load()
    for y in range(256):
        k=y/255
        highlight=7*math.exp(-y/25)
        for x in range(256):
            noise=R.uniform(-1.2,1.2)
            rgb=[int(max(0,min(255,a*(1-k)+b*k+highlight+noise))) for a,b in zip(top,bottom)]
            pix[x,y]=tuple(rgb)+(255,)
    im.putalpha(mask)
    d=ImageDraw.Draw(im)
    d.rounded_rectangle((2,2,253,253),radius,outline=edge,width=1)
    d.rounded_rectangle((3,3,252,252),max(1,radius-1),outline=(9,10,13,255),width=1)
    d.rounded_rectangle((4,4,251,251),max(1,radius-2),outline=inner,width=1)
    d.line((radius+2,5,253-radius,5),fill=tuple(min(255,v+18) for v in inner[:3])+(200,))
    if glow:
        g=Image.new('RGBA',im.size)
        gd=ImageDraw.Draw(g)
        gd.rounded_rectangle((6,6,249,249),radius,outline=glow,width=3)
        im=Image.alpha_composite(im,g.filter(ImageFilter.GaussianBlur(4)))
        ImageDraw.Draw(im).rounded_rectangle((4,4,251,251),radius-2,outline=glow,width=1)
    im.save(OUT/(name+'.tga'),compression=None)

material('d_panel',(25,28,34),(11,13,18),(78,79,83,255),(33,36,43,255))
material('d_button',(43,46,51),(19,21,26),(113,111,103,255),(49,50,53,255))
material('d_active',(115,87,20),(65,46,7),(246,206,71,255),(147,108,22,255),glow=(225,170,32,140))
material('d_card',(33,38,47),(14,17,23),(72,83,101,255),(30,36,47,255))
material('d_glow',(36,36,36),(15,15,15),(245,245,245,255),(100,100,100,255),glow=(255,255,255,170))
material('d_window',(26,28,33),(12,14,18),(114,108,91,255),(69,59,37,255),radius=15)
im=Image.open(OUT/'d_window.tga').convert('RGBA')
d=ImageDraw.Draw(im)
for inset,color in [(6,(156,127,64,255)),(8,(8,10,14,255)),(10,(71,66,50,255))]:
    d.rounded_rectangle((inset,inset,255-inset,255-inset),max(2,15-inset),outline=color,width=1)
for cx,cy,sx,sy in [(0,0,1,1),(255,0,-1,1),(0,255,1,-1),(255,255,-1,-1)]:
    d.line([(cx+sx*6,cy+sy*24),(cx+sx*6,cy+sy*13),(cx+sx*13,cy+sy*6),(cx+sx*24,cy+sy*6)],fill=(189,167,111,255),width=1)
im.save(OUT/'d_window.tga',compression=None)

header=Image.new('RGBA',(1024,128))
dp=header.load()
for y in range(128):
    for x in range(1024):
        n=R.uniform(-1.5,1.5)
        light=7*math.exp(-((x-800)/250)**2)*math.exp(-y/100)
        dp[x,y]=(int(19+n+light*.4),int(22+n+light*.6),int(28+n+light),(255))
draw=ImageDraw.Draw(header)
draw.line((0,123,1023,123),fill=(113,96,54),width=1)
draw.line((0,125,1023,125),fill=(5,6,9),width=1)
header.save(OUT/'d_header.tga',compression=None)

def crest(name,gold=False):
    scale=3
    im=Image.new('RGBA',(128*scale,128*scale))
    dr=ImageDraw.Draw(im)
    pts=[(64,5),(78,15),(102,19),(105,55),(95,86),(64,118),(33,86),(23,55),(26,19),(50,15)]
    pts=[(x*scale,y*scale) for x,y in pts]
    dr.polygon(pts,fill=(15,20,29),outline=(219,184,86) if gold else (158,166,181),width=4*scale)
    inner=[(64,14),(78,22),(95,25),(97,55),(87,81),(64,106),(41,81),(31,55),(33,25),(50,22)]
    dr.polygon([(x*scale,y*scale) for x,y in inner],fill=(24,36,53),outline=(102,83,40) if gold else (68,77,94),width=2*scale)
    if gold:
        f=ImageFont.truetype('C:/Windows/Fonts/georgiab.ttf',65*scale)
        dr.text((65*scale,58*scale),'F',font=f,anchor='mm',fill=(242,202,76),stroke_width=scale,stroke_fill=(92,63,15))
    else:
        gear=[]
        for i in range(48):
            a=i*math.pi/24-math.pi/2
            r=32 if i%4 in (0,1) else 25
            gear.append(((64+math.cos(a)*r)*scale,(56+math.sin(a)*r)*scale))
        dr.polygon(gear,fill=(178,187,202),outline=(226,232,241),width=scale)
        dr.ellipse((48*scale,40*scale,80*scale,72*scale),fill=(24,34,48),outline=(87,100,121),width=2*scale)
        dr.ellipse((58*scale,50*scale,70*scale,62*scale),fill=(160,173,193))
    im.resize((128,128),Image.Resampling.LANCZOS).save(OUT/(name+'.tga'),compression=None)
crest('d_crest')
crest('d_journal_crest',True)
selected=Image.new('RGBA',(64,64))
d=ImageDraw.Draw(selected)
d.ellipse((4,4,59,59),fill=(99,70,13),outline=(249,214,94),width=3)
d.line([(17,32),(28,43),(48,20)],fill=(255,231,141),width=6)
selected.save(OUT/'d_selected.tga',compression=None)
for name,kind in [('d_monitor','screen'),('d_display','eye')]:
    icon=Image.new('RGBA',(64,64));d=ImageDraw.Draw(icon)
    if kind=='screen':
        d.rounded_rectangle((8,10,56,44),3,fill=(25,30,39),outline=(176,185,199),width=3)
        d.line((32,45,32,52),fill=(176,185,199),width=3)
        d.line((21,54,43,54),fill=(176,185,199),width=3)
    else:
        d.ellipse((6,18,58,49),outline=(176,185,199),width=4)
        d.ellipse((25,26,40,42),fill=(176,185,199))
    icon.save(OUT/(name+'.tga'),compression=None)
print('Generated nine option D theme assets')
