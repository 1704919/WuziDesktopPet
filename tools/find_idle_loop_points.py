 1 | from pathlib import Path
 2 | from PIL import Image
 3 | import numpy as np
 4 | import json
 5 | 
 6 | ROOT=Path(__file__).resolve().parents[1]
 7 | D=ROOT/"godot/assets_display/wuzi_chibi/video_idle/frames"
 8 | 
 9 | frames=[]
for p in sorted(D.glob("*.png")):
    frames.append(np.asarray(Image.open(p).convert("RGBA"), dtype=np.int16))

pairs=[]
for i in range(min(16,len(frames))):
    for j in range(max(0,len(frames)-16), len(frames)):
        if j <= i:
            continue
        a=frames[i]
        b=frames[j]
        mask=((a[...,3]>16)|(b[...,3]>16))[...,None]
        diff=np.abs(a-b)*mask
        denom=max(1,int(mask.sum())*4)
        score=float(diff.sum()/denom)
        pairs.append((score,i,j))
pairs.sort()
best=pairs[:10]
print(json.dumps([{"score":s,"start":i,"end":j,"duration_frames":j-i+1} for s,i,j in best], indent=2))
