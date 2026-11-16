"""Render snapshots exported by test_modern_ui.lua from actual addon widgets.

Sample records are test fixtures. Built-in game icons/fonts are represented by
placeholders because they belong to the WoW client, not this addon.
"""
import json
import sys
from functools import lru_cache
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageChops

BASE=Path(__file__).resolve().parents[1]
FIELDS='id parent kind shown width height points full color vertex alpha texture text font textColor justify layer level coords masked'.split()
FACTORS={'TOPLEFT':(0,0),'TOP':(.5,0),'TOPRIGHT':(1,0),'LEFT':(0,.5),'CENTER':(.5,.5),'RIGHT':(1,.5),'BOTTOMLEFT':(0,1),'BOTTOM':(.5,1),'BOTTOMRIGHT':(1,1)}

def render(source,target):
    data=json.loads(Path(source).read_text())
    nodes={a[0]:dict(zip(FIELDS,a)) for a in data['widgets']}
    root=data['root']
    @lru_cache(None)
    def font(size,serif=False):
        return ImageFont.truetype('C:/Windows/Fonts/'+('georgia.ttf' if serif else 'arial.ttf'),max(8,round(size)))
    @lru_cache(None)
    def rect(i):
        n=nodes[i]
        if not n['parent']:
            return (0,0,n['width'] or 1600,n['height'] or 1000)
        parent=rect(n['parent'])
        if n['full']: return parent
        w,h=n['width'],n['height']
        if n['kind']=='FontString':
            size=n['font'][1] if len(n['font'])>1 else 13
            if not w: w=font(size,size>=17).getlength(n['text'])+1
            if not h: h=size*1.3
        constraints=[]
        for p in n['points'] or [['TOPLEFT']]:
            anchor=p[0] if p else 'TOPLEFT'
            rel=n['parent']; rp=anchor; x=y=0
            if len(p)>1 and isinstance(p[1],str) and p[1].startswith('@'):
                rel=int(p[1][1:]);rp=p[2] if len(p)>2 else anchor
                x=p[3] if len(p)>3 else 0;y=p[4] if len(p)>4 else 0
            elif len(p)>2:
                x,y=p[1],p[2]
            rx,ry,rw,rh=rect(rel)
            ax,ay=FACTORS.get(anchor,(0,0)); bx,by=FACTORS.get(rp,(0,0))
            constraints.append((ax,ay,rx+rw*bx+x,ry+rh*by-y))
        def solve(axis,size):
            factor=axis;offset=axis+2
            first=constraints[0]
            for c in constraints[1:]:
                if c[factor]!=first[factor]:
                    size=(c[offset]-first[offset])/(c[factor]-first[factor]);break
            return first[offset]-first[factor]*size,max(0,size)
        x,w=solve(0,w);y,h=solve(1,h)
        return x,y,w,h
    @lru_cache(None)
    def visible(i):
        n=nodes[i]
        return n['shown'] and (not n['parent'] or visible(n['parent']))
    def frame(i):
        n=nodes[i]
        return i if n['kind'] not in ('Texture','FontString') else frame(n['parent'])
    def tint(v,default=(1,1,1,1)):
        v=(list(v)+list(default[len(v):])) if v else default
        return tuple(max(0,min(255,round(x*255))) for x in v[:4])
    ox,oy,width,height=rect(root)
    canvas=Image.new('RGBA',(round(width),round(height)+36),(6,12,22,255))
    layers={'BACKGROUND':0,'BORDER':1,'ARTWORK':2,'OVERLAY':3,'HIGHLIGHT':4}
    def depth(i):
        n=nodes[i]
        return 0 if not n['parent'] else 1+depth(n['parent'])
    regions=[n for n in nodes.values() if n['kind'] in ('Texture','FontString') and visible(n['id'])]
    regions.sort(key=lambda n:(nodes[frame(n['id'])]['level'],depth(frame(n['id'])),layers.get(n['layer'],2),n['id']))
    for n in regions:
        x,y,w,h=rect(n['id']);x-=ox;y-=oy
        if w<.1 or h<.1: continue
        box=(round(x),round(y),round(x+w),round(y+h))
        if n['kind']=='Texture':
            tile=Image.new('RGBA',(max(1,round(w)),max(1,round(h))),(0,0,0,0))
            texture=n['texture']
            if n['color']:
                tile.paste(tint(n['color']),(0,0,tile.width,tile.height))
            elif 'AddOns\\ForeverLootJournal\\Media\\' in texture:
                name=texture.split('\\')[-1]
                path=BASE/'Media'/(name if '.' in name else name+'.tga')
                if path.exists():
                    source=Image.open(path).convert('RGBA')
                    coords=n['coords']
                    if len(coords)==4:
                        l,r,t,b=coords
                        source=source.crop((round(l*source.width),round(t*source.height),round(r*source.width),round(b*source.height)))
                    tile=source.resize(tile.size,Image.Resampling.LANCZOS)
            elif 'WHITE8X8' in texture:
                tile.paste((255,255,255,255),(0,0,tile.width,tile.height))
            elif texture:
                d=ImageDraw.Draw(tile)
                if 'UI-CheckBox-Check' in texture:
                    d.line([(w*.2,h*.5),(w*.43,h*.73),(w*.82,h*.22)],fill=(230,230,230),width=3)
                elif 'Searchbox' in texture:
                    d.ellipse((2,2,w-6,h-6),outline=(159,177,202),width=2)
                    d.line((w-7,h-7,w-1,h-1),fill=(159,177,202),width=2)
                else:
                    d.rectangle((0,0,w-1,h-1),fill=(35,48,65),outline=(120,109,76))
                    symbol='?' if 'QuestionMark' in texture else 'B' if 'Book' in texture else '+' if 'Engineering' in texture else '*'
                    f=font(min(w,h)*.55,True)
                    d.text((w/2,h/2),symbol,font=f,anchor='mm',fill=(223,190,110))
            if n['vertex']:
                tile=ImageChops.multiply(tile,Image.new('RGBA',tile.size,tint(n['vertex'])))
            if n['alpha']<1: tile.putalpha(tile.getchannel('A').point(lambda a:round(a*n['alpha'])))
            if n['masked']:
                circle=Image.new('L',tile.size)
                ImageDraw.Draw(circle).ellipse((0,0,tile.width-1,tile.height-1),fill=255)
                tile.putalpha(ImageChops.multiply(tile.getchannel('A'),circle))
            canvas.alpha_composite(tile,(box[0],box[1]))
        else:
            text=n['text']
            if not text: continue
            size=n['font'][1] if len(n['font'])>1 else 13
            f=font(size,size>=17)
            # WoW truncates single-line font strings to the assigned width.
            while text and f.getlength(text)>w:
                text=text[:-1]
            draw=ImageDraw.Draw(canvas)
            align=n['justify']
            tx=x if align=='LEFT' else x+w if align=='RIGHT' else x+w/2
            anchor='lm' if align=='LEFT' else 'rm' if align=='RIGHT' else 'mm'
            draw.text((tx,y+h/2),text,font=f,anchor=anchor,fill=tint(n['textColor']))
    d=ImageDraw.Draw(canvas)
    d.text((14,height+18),'Layout rendered from addon code with sample loot. Game icons and fonts may differ.',font=font(12),anchor='lm',fill=(155,170,192))
    canvas.convert('RGB').save(target)
    print(target)

if __name__=='__main__':
    render(sys.argv[1],sys.argv[2])
