"""연속 방어 시범 구간에서 동작 하나하나를 잘라 지표 중앙값을 낸다.

usage: defense.py <poses.npz> <kind> <start> <end>
kind: slip  - |roll| 봉우리
      duck  - 낮춤(height 감소) 봉우리
      pull  - 머리가 뒤로(headZ 감소) 봉우리
기준값은 각 봉우리 앞뒤 0.6초 안에서 가장 가드에 가까운 값(지표가 가장 작은 쪽)의 중앙값.
"""
import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
from body import LANK, LHIP, RANK, RHIP, load, metrics, smooth  # noqa: E402

path, kind, a, b = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
w, t, fps, _ = load(path)
sel = (t >= a) & (t <= b)
w, t = w[sel], t[sel]
m = metrics(w)
L = m.pop("L")
s = {k: smooth(v, 3) for k, v in m.items()}
hip = (w[:, LHIP] + w[:, RHIP]) / 2
ank = (w[:, LANK] + w[:, RANK]) / 2
s["hipX"] = smooth((hip[:, 0] - ank[:, 0]) / L, 3)
s["hipZ"] = smooth((hip[:, 2] - ank[:, 2]) / L, 3)

sig = {"slip": np.abs(s["roll"] - np.median(s["roll"])), "duck": -s["height"], "pull": -s["headZ"]}[kind]
win = int(0.6 * fps)
rows = []
i = win
while i < len(t) - win:
    seg = sig[i - win:i + win + 1]
    if sig[i] == seg.max():
        lo = seg.min()
        if sig[i] - lo > {"slip": 10, "duck": 0.12, "pull": 0.2}[kind]:
            # 시작(가드 기준점): 봉우리 앞에서 sig가 최소인 곳, 끝: 뒤에서 최소인 곳
            a0 = i - win + int(np.argmin(sig[i - win:i + 1]))
            b0 = i + int(np.argmin(sig[i:i + win + 1]))
            r = {k: s[k][i] - (s[k][a0] + s[k][b0]) / 2 for k in s}
            r["t"] = t[i]
            r["out"] = t[i] - t[a0]
            r["back"] = t[b0] - t[i]
            rows.append(r)
            i += win
            continue
    i += 1

keys = ["roll", "pitch", "height", "headX", "headY", "headZ", "hipX", "hipZ", "shTilt", "shYaw", "hipYaw", "out", "back"]
print("t      " + " ".join(f"{k:>7}" for k in keys))
for r in rows:
    print(f"{r['t']:6.2f} " + " ".join(f"{r[k]:+7.2f}" for k in keys))
if kind == "slip":
    for sign, name in ((1, "roll+"), (-1, "roll-")):
        g = [r for r in rows if np.sign(r["roll"]) == sign]
        if g:
            print(f"median {name} n={len(g)} " + " ".join(f"{k}={np.median([abs(r[k]) if k in ('out','back') else r[k] for r in g]):+.2f}" for k in keys))
else:
    print(f"median n={len(rows)} " + " ".join(f"{k}={np.median([r[k] for r in rows]):+.2f}" for k in keys))
