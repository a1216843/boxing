"""임팩트 순간 치는 손목의 위치: 코 기준 높이(dy, +아래), 어깨 기준 높이, 시작 대비 상승 (몸통 단위, 2D).
usage: impact.py tool/boxingvi <데이터 폴더> <model_punches.json>"""
import json, sys
from pathlib import Path
import numpy as np
sys.path.insert(0, sys.argv[1])
import compare as C
def run(clips, st):
    out = {}
    for v, cls, f in clips:
        left = (cls in C.LEAD_CLASSES) == st[v]
        sh, wr = (C.LS, C.LW) if left else (C.RS, C.RW)
        ms=(f[:,C.LS]+f[:,C.RS])/2; mh=(f[:,C.LH]+f[:,C.RH])/2; L=np.linalg.norm(ms-mh,axis=1).mean()
        if L<1e-4: continue
        f=f/L
        ext=np.linalg.norm(f[:,wr]-f[:,sh],axis=1)
        i=int(np.argmin(f[:,wr,1])) if "Uppercut" in cls else int(np.argmax(ext))
        n=f[:,C.NOSE]
        out.setdefault(cls,[]).append([f[i,wr,1]-n[i,1], f[i,wr,1]-f[i,sh,1], f[0,wr,1]-f[i,wr,1], f[0,wr,1]-n[0,1]])
    return {k: np.median(np.array(v),0) for k,v in out.items()}
clips = C.load_dataset(Path(sys.argv[2]))
byv={}
for c in clips: byv.setdefault(c[0],[]).append(c)
real = run(clips, {v: C.stance_of_video(cs) for v,cs in byv.items()})
m=json.loads(Path(sys.argv[3]).read_text())
mc=[("M",cls,C.project(np.array(m[cls]["frames"]),y)) for cls in C.CLASSES for y in (-60,-30,0,30,60)]
model = run(mc, {"M":True})
print(f"{'':22}{'wr-nose@imp':>12}{'wr-sh@imp':>12}{'rise':>8}{'wr-nose@0':>12}")
for cls in C.CLASSES:
    for nm,src in (("real",real),("model",model)):
        print(f"{cls:15}{nm:7}"+"".join(f"{x:12.2f}" for x in src[cls]))
