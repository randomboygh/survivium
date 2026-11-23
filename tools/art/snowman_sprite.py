## Draws the snowman's picture: 4 views (rows: front, back, facing left, facing right) by
## 4 stages of melting (columns), from the user's pixel circles (tools/art/pixel_circles.json).
##   python3 tools/art/snowman_sprite.py [sheet.png]   (default: the bundle's sprites/things/snowman.png)
## B (ball sizes bottom,middle,head), K (how deep each sits in the one under it), H (frame height) may be
## given in the environment to try other shapes.
import json, math, sys, os
from PIL import Image
HERE=os.path.dirname(os.path.abspath(__file__))
C=json.load(open(os.path.join(HERE,'pixel_circles.json')))
def hexc(h): return tuple(int(h[i:i+2],16) for i in (1,3,5))+(255,)
P={k:hexc(v) for k,v in dict(
 line='#3c4a72', deep='#8ea0c8', shade='#b4c4e2', body='#d8e2f2', light='#f0f5fc', shine='#ffffff',
 coal='#24202a', car='#e06a1c', card='#a43c10', carl='#f8a040', tw='#7c4a2c', twd='#42221a').items()}
TONES=['deep','shade','body','light','shine']
SNOW=[P[t] for t in TONES]
W,H=int(os.environ.get('W','24')),int(os.environ.get('H','27'))
# Stages: the balls' sizes (bottom, middle, head), how much of its height each keeps, how
# deep each sits in the one under it.
B=tuple(int(v) for v in os.environ.get('B','15,12,9').split(',')); K=tuple(int(v) for v in os.environ.get('K','5,4').split(','))
STAGES=[(B,1.0,K),(B,0.8,K),((B[0]+2,B[1],B[2]),0.62,K),((B[0]+4,B[1]+1,0),0.4,(K[0],0))]
def mask(d,k):
    m=C[str(d)]; hh=max(2,round(d*k)); out=[]
    if hh<d:
        # squashed: an ellipse d wide and hh high, its rows' ends stepping as the circles' do
        a,b=d/2,hh/2
        for j in range(hh):
            # the row's width at its middle line, widened a little at the flat top and bottom
            y=(j+0.5-b)/b; w=d*math.sqrt(max(0,1-y*y)); w=int(round(w/2-0.15))*2+(d%2)
            w=max(w,2+(d%2)); x0=(d-w)//2
            out.append('.'*x0+'#'*w+'.'*(d-x0-w))
        # like the circles, a mask holds only the ring: the filled pixels with an empty side
        f=lambda i,j: 0<=j<hh and 0<=i<d and out[j][i]=='#'
        return [''.join('#' if f(i,j) and not (f(i-1,j) and f(i+1,j) and f(i,j-1) and f(i,j+1)) else '.'
            for i in range(d)) for j in range(hh)]
    for j in range(hh):
        src=m[min(d-1,int((j+0.5)*d/hh))]
        out.append(src)
    return out
def draw(view,stage):
    sizes,k,sink=STAGES[stage]
    img={}; owner={}; rings={}; centers=[]
    L=(-0.55,-0.65,0.55); n=math.sqrt(sum(c*c for c in L)); L=[c/n for c in L]
    if view=='e': L[0]=-L[0]  # drawn as 'w' and mirrored, the light must stay on the left
    bottom=H
    for bi,d in enumerate(sizes):
        if d==0: centers.append(None); continue
        m=mask(d,k); hh=len(m); x0=(W-d)//2
        y0=bottom-hh
        cx=x0+d/2; cy=y0+hh/2; centers.append((cx,cy,d,hh))
        ring=set()
        for j,row in enumerate(m):
            xs=[i for i,c in enumerate(row) if c=='#']
            for i in range(min(xs),max(xs)+1):
                x,y=x0+i,y0+j
                nx=(x+0.5-cx)/(d/2); ny=(y+0.5-cy)/(hh/2); q=nx*nx+ny*ny
                nz=math.sqrt(max(0,1-q)); v=nx*L[0]+ny*L[1]+nz*L[2]
                t=0 if v<0.15 else 1 if v<0.42 else 2 if v<0.72 else 3 if v<0.9 else 4
                if i in xs: t=0; ring.add((x,y))
                img[(x,y)]=SNOW[t]; owner[(x,y)]=bi
        rings[bi]=ring
        # each next ball sits into this one
        bottom=y0+(max(1,round(sink[bi]*k)) if bi<2 else 0)
    for (x,y),bi in list(owner.items()):
        a1=owner.get((x,y-1)); a2=owner.get((x,y-2))
        if (a1 is not None and a1>bi) or (a2 is not None and a2>bi):
            c=img[(x,y)]
            if c in SNOW: img[(x,y)]=SNOW[max(0,SNOW.index(c)-1)]
    def at(ball,dx,dy,c):
        ctr=centers[ball]
        if ctr is None: ctr=centers[ball-1]
        x=int(math.floor(ctr[0]))+dx; y=int(math.floor(ctr[1]+dy*k))
        img[(x,y)]=P[c]; return (x,y)
    head=2 if sizes[2] else 1
    arms=[]
    if view in ('s','n'):
        if view=='s':
            for dx,dy,c in [(-1,-1,'coal'),(1,-1,'coal'),(-1,0,'carl'),(0,0,'car'),(-2,1,'coal'),(2,1,'coal'),(-1,2,'coal'),(0,2,'coal'),(1,2,'coal')]:
                if sizes[2] or dy<1: at(head,dx,dy,c)
            for dy in (-1,1): at(1,-1,dy,'coal')
            at(0,0,-1,'coal')
        arms=[[(-6,0),(-7,-1),(-8,-2),(-9,-3),(-10,-4),(-9,-4)],[(5,0),(6,-1),(7,-2),(8,-3),(9,-4),(8,-4)]]
    else:
        for dx,dy,c in [(-2,-1,'coal'),(-3,0,'car'),(-4,0,'carl'),(-5,0,'car'),(-3,1,'card'),(-2,2,'coal'),(-1,2,'coal')]:
            if sizes[2] or dy<1: at(head,dx,dy,c)
        at(1,-3,-1,'coal'); at(1,-3,1,'coal'); at(0,-4,-1,'coal')
        arms=[[(-2,0),(-3,-1),(-4,-2),(-5,-3),(-6,-4)],[(3,-1),(4,-2),(5,-3),(6,-4),(7,-5)]]
    mc=centers[1]
    for ai,a in enumerate(arms):
        for i,(dx,dy) in enumerate(a):
            # melting, the twigs sag: their ends drop
            sag=0 if stage<2 else (i*(stage-1))//2
            x=int(math.floor(mc[0]))+dx; y=int(math.floor(mc[1]+dy*k))+sag
            if view in ('w','e') and ai==1 and (x,y) in owner: continue
            img[(x,y)]=P['tw'] if i%2==0 else P['twd']
    allring=set().union(*rings.values())
    out={}
    for (x,y),c in img.items():
        edge=any((x+dx,y+dy) not in img for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)))
        out[(x,y)]=P['line'] if edge and c in SNOW else c
    im=Image.new('RGBA',(W,H),(0,0,0,0))
    for (x,y),c in out.items():
        if 0<=x<W and 0<=y<H: im.putpixel((x,y),c)
    if view=='e': im=im.transpose(Image.FLIP_LEFT_RIGHT)
    return im
sheet=Image.new('RGBA',(W*4,H*4),(0,0,0,0))
for r,v in enumerate('snwe'):
    for s in range(4):
        sheet.paste(draw(v,s),(s*W,r*H))
sheet.save(sys.argv[1] if len(sys.argv)>1 else os.path.join(HERE,'../../content/plants/snowman/sprites/things/snowman.png'))
