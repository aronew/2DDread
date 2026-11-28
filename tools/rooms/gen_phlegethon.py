# Generated the first Phlegethon map from the owner's layout sketch. The map in
# src/dungeon/layout_phlegethon.gd has since been edited to match the paintings: do not regenerate it.
# island rooms with ragged edges (seeded, so it is repeatable), causeways and props.
# python3 tools/rooms/gen_phlegethon.py  -> prints the map, writes phlegethon_map.txt (paste into MAP)
import random
random.seed(7)
W,H=86,68
g=[[' ']*W for _ in range(H)]
rooms={  # id: (i0,j0,i1,j1)
 'ashfall':(54,2,65,12),
 'ossuary':(52,16,67,29),
 'c_center':(54,34,64,44),
 'c_left':(44,36,51,43),
 'c_right':(68,35,81,44),
 'g_top':(30,16,43,26),
 'g_hall':(33,27,40,48),
 'vault':(31,52,42,63),
 'forgegate':(18,33,28,42),
 'throne':(2,30,14,45),
}
cause=[ (58,13,60,15), (58,30,60,33), (52,38,53,40), (65,38,67,40), (44,20,51,22), (35,49,37,51), (29,36,32,38), (15,36,17,38) ]
def fill(r,ch=':'):
    for j in range(r[1],r[3]+1):
        for i in range(r[0],r[2]+1): g[j][i]=ch
for r in rooms.values(): fill(r)
# jagged island edges: erode the rim, add bumps outside
protect=set()
for c in cause:
    for j in range(c[1]-1,c[3]+2):
        for i in range(c[0]-1,c[2]+2): protect.add((i,j))
for r in rooms.values():
    i0,j0,i1,j1=r
    for j in range(j0,j1+1):
        for i in range(i0,i1+1):
            rim=min(i-i0,i1-i,j-j0,j1-j)
            corner=min(i-i0,i1-i)+min(j-j0,j1-j)
            if (i,j) in protect: continue
            if corner<=1 and random.random()<0.9: g[j][i]=' '
            elif rim==0 and random.random()<0.35: g[j][i]=' '
    for j in range(j0-1,j1+2):
        for i in range(i0-1,i1+2):
            if 0<=i<W and 0<=j<H and (i in (i0-1,i1+1) or j in (j0-1,j1+1)) and (i,j) not in protect:
                if i0<=i<=i1 or j0<=j<=j1:
                    if random.random()<0.22: g[j][i]=':'
# erode lone stubs: remove floor cells with <2 orthogonal floor neighbours
for _ in range(2):
    for j in range(H):
        for i in range(W):
            if g[j][i]==':':
                n=sum(1 for di,dj in((1,0),(-1,0),(0,1),(0,-1)) if 0<=i+di<W and 0<=j+dj<H and g[j+dj][i+di]!=' ')
                if n<2: g[j][i]=' '
for c in cause: fill(c,":")
fill((34,25,39,29))
pass
def put(i,j,c):
    assert g[j][i]!=' ', (i,j,c); g[j][i]=c
P=[]
# 1 ashfall: landing
P+= [(59,5,'S'),(56,4,'*'),(63,4,'*'),(56,10,'k'),(64,9,'k'),(61,8,'w')]
# 2 ossuary: giant skull ruin at the back (walls), laurel plate, bone nests, braziers
P+= [(54,17,'Q'),(55,17,'O'),(56,17,'Q'),(54,18,'Q'),(60,22,'o'),(53,24,'e'),(66,19,'e'),(57,19,'*'),(64,26,'*'),(65,23,'k'),(53,28,'n'),(62,18,','),(56,26,'w')]
# sinkholes (lava under the floor)
P+= [(63,21,' '),(56,22,' ')]
# 3 crossroads: centre + wings
P+= [(56,36,'*'),(62,42,'*'),(59,39,'o'),(46,38,'e'),(49,42,'b'),(71,37,'b'),(78,42,'e'),(75,40,'Q'),(74,39,'k'),(80,37,'k'),(46,41,'k')]
# 4 gauntlet: top room + long hall, columns down the hall
P+= [(32,18,'*'),(41,18,'*'),(36,21,'o'),(35,30,'O'),(38,30,'O'),(35,36,'O'),(38,42,'O'),(35,45,'O'),(31,24,'k'),(42,25,'b'),(37,33,' ')]
# 5 vault: dead end, molten elite + chest
P+= [(33,54,'*'),(40,54,'*'),(36,58,'o'),(32,61,'k'),(41,61,'k'),(34,57,' ')]
# 6 forge gate
P+= [(20,35,'Q'),(26,40,'Q'),(23,37,'o'),(19,41,'*'),(27,34,'*'),(21,39,'b'),(25,35,'k')]
# 7 throne: finale + exit portal
P+= [(8,37,'X'),(4,33,'Q'),(12,33,'O'),(4,42,'O'),(12,42,'Q'),(8,31,'*'),(8,44,'*'),(6,38,'o'),(3,37,'k'),(13,39,'k')]
for i,j,c in P:
    if c==' ': g[j][i]=' '
    else: put(i,j,c)
rows=[''.join(r).rstrip() for r in g]
print('\n'.join('%2d %s'%(k,r) for k,r in enumerate(rows)))
open('phlegethon_map.txt','w').write('\n'.join('\t"%s",'%r for r in rows))
