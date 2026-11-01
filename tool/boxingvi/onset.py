"""BoxingVI: 펀치에서 각 부위가 움직이기 시작하는 시점(최대 변화의 20%·50%를 넘는 시각, 선형 보간)을 비교.

usage: onset.py tool/boxingvi <데이터 폴더> [model_punches.json]
세 번째 인자를 주면 데이터 대신 인형(7개 시점 투영)으로 계산한다.
부위:
  wrist  치는 손목의 어깨 기준 거리 변화
  ankle  앞발(잽) / 뒷발(나머지) 발목 이동
  sh     어깨선 벡터 변화 (회전)
  hip    골반선 벡터 변화 (회전)
출력: 임팩트(손목 최대 신전)까지 구간에서 각 부위 onset의 중앙값(ms)과
      부위 쌍의 차이 중앙값 + 부트스트랩 95% 구간.
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, sys.argv[1])
import compare as C  # noqa: E402

if len(sys.argv) > 3:
    import json
    _m = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))
    clips = [("M", cls, C.project(np.array(_m[cls]["frames"]), y)) for cls in C.CLASSES for y in (-90, -60, -30, 0, 30, 60, 90)]
else:
    clips = C.load_dataset(Path(sys.argv[2]))
byv = {}
for c in clips:
    byv.setdefault(c[0], []).append(c)
st = {v: (True if v == 'M' else C.stance_of_video(cs)) for v, cs in byv.items()}


def cross_time(x, frac):
    """x(0)=0에서 max까지 증가할 때 frac*max를 처음 넘는 시각(프레임, 보간)."""
    x = x - x[0]
    m = x.max()
    if m <= 1e-6:
        return None
    thr = frac * m
    for i in range(1, len(x)):
        if x[i] >= thr:
            return i - 1 + (thr - x[i - 1]) / (x[i] - x[i - 1] + 1e-12)
    return None


res = {}
for v, cls, f in clips:
    lead_left = st[v]
    punch_lead = cls in C.LEAD_CLASSES
    left = punch_lead == lead_left
    sh, wr = (C.LS, C.LW) if left else (C.RS, C.RW)
    la, ra = (C.LA, C.RA) if lead_left else (C.RA, C.LA)
    ms = (f[:, C.LS] + f[:, C.RS]) / 2
    mh = (f[:, C.LH] + f[:, C.RH]) / 2
    L = np.linalg.norm(ms - mh, axis=1).mean()
    if L < 1e-4 or len(f) < 6:
        continue
    f = f / L
    upper = "Uppercut" in cls
    ext = np.linalg.norm(f[:, wr] - f[:, sh], axis=1)
    imp = int(np.argmin(f[:, wr, 1])) if upper else int(np.argmax(ext))
    if imp < 3:
        continue
    g = slice(0, imp + 1)
    wristsig = (f[0, wr, 1] - f[:, wr, 1]) if upper else ext
    ank = la if cls == "Jab" else ra
    sig = {
        "wrist": wristsig[g],
        "ankle": np.linalg.norm(f[g, ank] - f[0, ank], axis=1),
        "sh": np.linalg.norm((f[g, C.LS] - f[g, C.RS]) - (f[0, C.LS] - f[0, C.RS]), axis=1),
        "hip": np.linalg.norm((f[g, C.LH] - f[g, C.RH]) - (f[0, C.LH] - f[0, C.RH]), axis=1),
    }
    # 움직임이 거의 없는 부위는 노이즈라 뺀다
    thr = {"wrist": 0.15, "ankle": 0.05, "sh": 0.05, "hip": 0.05}
    row = {}
    for k, x in sig.items():
        if x.max() - x[0] < thr[k]:
            continue
        for frac in (0.2, 0.5):
            tt = cross_time(x, frac)
            if tt is not None:
                row[f"{k}{int(frac * 100)}"] = tt * 1000 / C.FPS
    res.setdefault(cls, []).append(row)

rng = np.random.default_rng(0)


def ci(a):
    a = np.asarray(a)
    bs = [np.median(rng.choice(a, len(a))) for _ in range(400)]
    return np.median(a), np.percentile(bs, 2.5), np.percentile(bs, 97.5)


for cls in C.CLASSES:
    rows = res.get(cls, [])
    print(f"\n=== {cls} (n={len(rows)})")
    for k in ["wrist20", "ankle20", "sh20", "hip20", "wrist50", "ankle50", "sh50", "hip50"]:
        a = [r[k] for r in rows if k in r]
        if a:
            print(f"  {k:8} {np.median(a):6.0f} ms (n={len(a)})")
    for a_, b_ in [("hip", "sh"), ("sh", "wrist"), ("hip", "wrist"), ("ankle", "wrist")]:
        for p in ("20", "50"):
            d = [r[b_ + p] - r[a_ + p] for r in rows if a_ + p in r and b_ + p in r]
            if len(d) > 2:
                m, lo, hi = ci(d)
                print(f"  {b_}{p} - {a_}{p}: {m:+5.0f} ms [{lo:+.0f},{hi:+.0f}] n={len(d)}  (+ = {a_} 먼저)")
