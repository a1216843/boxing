"""가드 자세(클립 첫 프레임)에서 손목·팔꿈치의 코 기준 위치 (몸통 단위, 2D, y 아래 +).
usage: guardpos.py tool/boxingvi <데이터 폴더> <model_punches.json>"""
import json, sys
from pathlib import Path
import numpy as np
sys.path.insert(0, sys.argv[1])
import compare as C
clips = C.load_dataset(Path(sys.argv[2]))
byv = {}
for c in clips: byv.setdefault(c[0], []).append(c)
st = {v: C.stance_of_video(cs) for v, cs in byv.items()}
def rel(f, lead_left):
    ms=(f[0,C.LS]+f[0,C.RS])/2; mh=(f[0,C.LH]+f[0,C.RH])/2; L=np.linalg.norm(ms-mh)
    lw,rw,le,re=(C.LW,C.RW,C.LE,C.RE) if lead_left else (C.RW,C.LW,C.RE,C.LE)
    n=f[0,C.NOSE]
    return [np.linalg.norm(f[0,lw]-n)/L,(f[0,lw,1]-n[1])/L,np.linalg.norm(f[0,rw]-n)/L,(f[0,rw,1]-n[1])/L,(f[0,le,1]-n[1])/L,(f[0,re,1]-n[1])/L,abs(f[0,lw,0]-f[0,rw,0])/L]
R=np.array([rel(f,st[v]) for v,_,f in clips])
model=json.loads(Path(sys.argv[3]).read_text())
fr=np.array(model['Jab']['frames'])
M=np.array([rel(C.project(fr,y),True) for y in [-90,-60,-30,0,30,60,90]])
names=['leadW-nose','leadW dy','rearW-nose','rearW dy','leadE dy','rearE dy','hands dx']
print(' '*7+''.join(f'{n:>12}' for n in names))
print('real  '+''.join(f'{x:12.2f}' for x in np.median(R,0)))
print('model '+''.join(f'{x:12.2f}' for x in np.median(M,0)))
