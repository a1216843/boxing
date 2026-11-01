"""BoxingVI: 임팩트 뒤 거둘 때 손목과 몸(어깨선·골반선) 중 무엇이 먼저 돌아오는지.
usage: retract.py tool/boxingvi <데이터 폴더> [model_punches.json]  (세 번째 인자: 인형으로 계산)
각 신호가 임팩트 때 값에서 클립 끝 값 쪽으로 50% 돌아온 시각(임팩트 기준 ms)."""
import sys
from pathlib import Path
import numpy as np
sys.path.insert(0, sys.argv[1])
import compare as C
if len(sys.argv) > 3:
    import json
    _m = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))
    clips = [("M", cls, C.project(np.array(_m[cls]["frames"]), y)) for cls in C.CLASSES for y in (-90, -60, -30, 0, 30, 60, 90)]
else:
    clips = C.load_dataset(Path(sys.argv[2]))
byv = {}
for c in clips: byv.setdefault(c[0], []).append(c)
st = {v: (True if v == 'M' else C.stance_of_video(cs)) for v, cs in byv.items()}
def back(x, frac=0.5):
    d = x - x[-1]
    if abs(d[0]) < 1e-6: return None
    r = d / d[0]
    for i in range(1, len(r)):
        if r[i] <= 1 - frac:
            return i - 1 + (r[i-1] - (1-frac)) / (r[i-1] - r[i] + 1e-12)
    return None
rng = np.random.default_rng(0)
for cls in C.CLASSES:
    diffs = {"sh-wrist": [], "hip-wrist": []}; tw = []
    for v, c, f in clips:
        if c != cls: continue
        left = (cls in C.LEAD_CLASSES) == st[v]
        sh, wr = (C.LS, C.LW) if left else (C.RS, C.RW)
        ms=(f[:,C.LS]+f[:,C.RS])/2; mh=(f[:,C.LH]+f[:,C.RH])/2; L=np.linalg.norm(ms-mh,axis=1).mean()
        if L<1e-4: continue
        f=f/L
        ext=np.linalg.norm(f[:,wr]-f[:,sh],axis=1)
        imp=int(np.argmin(f[:,wr,1])) if "Uppercut" in cls else int(np.argmax(ext))
        if len(f)-imp<4: continue
        g=slice(imp,len(f))
        w=(-f[g,wr,1]) if "Uppercut" in cls else ext[g]
        if w[0]-w[-1]<0.15: continue
        shv=f[g,C.LS]-f[g,C.RS]; hv=f[g,C.LH]-f[g,C.RH]
        s=np.linalg.norm(shv-shv[-1],axis=1); h=np.linalg.norm(hv-hv[-1],axis=1)
        bw=back(w)
        if bw is None: continue
        tw.append(bw*1000/C.FPS)
        for name,x in (("sh-wrist",s),("hip-wrist",h)):
            if x[0]>0.05:
                b=back(x)
                if b is not None: diffs[name].append((b-bw)*1000/C.FPS)
    out=f"{cls:14} wrist50 back {np.median(tw):4.0f}ms (n={len(tw)})"
    for k,d in diffs.items():
        if len(d)>2:
            bs=[np.median(rng.choice(d,len(d))) for _ in range(400)]
            out+=f"  {k}: {np.median(d):+4.0f}ms [{np.percentile(bs,2.5):+.0f},{np.percentile(bs,97.5):+.0f}]"
    print(out, " (+ = 손목이 먼저 돌아옴)")
