"""BoxingVI: 펀치할 때 안 치는 손과 치는 쪽 어깨를 실제/인형에서 같은 지표로 비교.

usage: guard.py tool/boxingvi <데이터 폴더> <model_punches.json>
지표 (몸통 길이 단위, 2D):
  guard_nose0   시작 때 안 치는 손목~코 거리
  guard_noseI   임팩트 때 안 치는 손목~코 거리
  guard_drift   임팩트 때 안 치는 손목이 시작 위치에서 움직인 거리
  guard_drop    안 치는 손목이 내려간 양 (+ = 내려감)
  chin_gap0/I   코와 치는 쪽 어깨의 세로 간격 (작을수록 어깨가 턱을 가림)
  sh_raise      치는 쪽 어깨가 반대 어깨보다 올라간 양의 변화
"""
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, sys.argv[1])
import compare as C  # noqa: E402

data, model_path = Path(sys.argv[2]), Path(sys.argv[3])
clips = C.load_dataset(data)
by_video = {}
for c in clips:
    by_video.setdefault(c[0], []).append(c)
stance = {v: C.stance_of_video(cs) for v, cs in by_video.items()}


def metrics(f, punch_lead, lead_is_left, upper):
    mid_s = (f[:, C.LS] + f[:, C.RS]) / 2
    mid_h = (f[:, C.LH] + f[:, C.RH]) / 2
    torso = np.linalg.norm(mid_s - mid_h, axis=1).mean()
    if torso < 1e-4:
        return None
    f = f / torso
    left_punch = punch_lead == lead_is_left
    sh, wr = (C.LS, C.LW) if left_punch else (C.RS, C.RW)
    osh, owr = (C.RS, C.RW) if left_punch else (C.LS, C.LW)
    ext = np.linalg.norm(f[:, wr] - f[:, sh], axis=1)
    i = int(np.argmin(f[:, wr, 1])) if upper else int(np.argmax(ext))
    nose = f[:, C.NOSE]
    d = lambda k: float(np.linalg.norm(f[k, owr] - nose[k]))
    return {
        "guard_nose0": d(0),
        "guard_noseI": d(i),
        "guard_drift": float(np.linalg.norm(f[i, owr] - f[0, owr])),
        "guard_drop": float(f[i, owr, 1] - f[0, owr, 1]),
        "chin_gap0": float(f[0, sh, 1] - nose[0, 1]),
        "chin_gapI": float(f[i, sh, 1] - nose[i, 1]),
        "sh_raise": float((f[0, sh, 1] - f[0, osh, 1]) - (f[i, sh, 1] - f[i, osh, 1])),
    }


real = {c: [] for c in C.CLASSES}
for v, cls, f in clips:
    m = metrics(f, cls in C.LEAD_CLASSES, stance[v], "Uppercut" in cls)
    if m:
        real[cls].append(m)
model = json.loads(model_path.read_text(encoding="utf-8"))
sim = {c: [] for c in C.CLASSES}
for cls in C.CLASSES:
    frames = np.array(model[cls]["frames"])
    for yaw in [-90, -60, -30, 0, 30, 60, 90]:
        m = metrics(C.project(frames, yaw), cls in C.LEAD_CLASSES, True, "Uppercut" in cls)
        if m:
            sim[cls].append(m)
keys = list(real["Jab"][0].keys())
print(f"{'':14}" + "".join(f"{k:>22}" for k in keys))
for cls in C.CLASSES:
    for name, src in (("real", real), ("model", sim)):
        meds = [np.median([m[k] for m in src[cls]]) for k in keys]
        print(f"{cls[:9]:9} {name:5}" + "".join(f"{x:22.2f}" for x in meds))
