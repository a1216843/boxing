"""몸통이 돌고 기울 때 머리가 얼마나 따라가는지 (MediaPipe world 좌표).

usage: head.py <poses.npz> <start> <end> [start end ...]
각 구간에서 1초 이동 중앙값을 기준으로 뺀 변화량끼리 회귀해 기울기(머리 변화 / 몸통 변화)를 낸다.
  roll  머리 귀선 기울기  vs 어깨선 기울기 / 몸통 옆 기울기
  yaw   머리 귀선 수평 방향 vs 어깨선 수평 방향
  pitch 머리 숙임(귀 중앙→코 벡터의 세로 각) vs 몸통 앞 숙임
1이면 머리가 몸통에 붙어 그대로 따라가고, 0이면 몸통과 상관없이 머리 방향이 고정.
"""
import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
from body import LEAR, LSH, NOSE, REAR, RSH, load, metrics, smooth, yaw_of  # noqa: E402

w, t, fps, _ = load(sys.argv[1])
m = metrics(w)
ear = (w[:, LEAR] + w[:, REAR]) / 2
v = w[:, LEAR] - w[:, REAR]
head = {
    "roll": np.degrees(np.arctan2(v[:, 1], np.hypot(v[:, 0], v[:, 2]))),
    "yaw": yaw_of(w[:, REAR], w[:, LEAR]),
    "pitch": np.degrees(np.arctan2(-(w[:, NOSE, 1] - ear[:, 1]), np.hypot(w[:, NOSE, 0] - ear[:, 0], w[:, NOSE, 2] - ear[:, 2]))),
}
sv = w[:, LSH] - w[:, RSH]
body = {
    "roll": np.degrees(np.arctan2(sv[:, 1], np.hypot(sv[:, 0], sv[:, 2]))),
    "trunkRoll": -m["roll"],  # 어깨선 기울기와 같은 부호가 되도록
    "yaw": m["shYaw"],
    "pitch": m["pitch"],
}
k = int(fps)
sel = np.zeros(len(t), bool)
args = [float(x) for x in sys.argv[2:]]
for a, b in zip(args[::2], args[1::2]):
    sel |= (t >= a) & (t <= b)


def detrend(x):
    x = smooth(x, 3)
    base = np.array([np.median(x[max(0, i - k):i + k]) for i in range(len(x))])
    return x - base


for hk, bk in [("roll", "roll"), ("roll", "trunkRoll"), ("yaw", "yaw"), ("pitch", "pitch")]:
    hx, bx = detrend(head[hk])[sel], detrend(body[bk])[sel]
    ok = ~(np.isnan(hx) | np.isnan(bx)) & (np.abs(bx) > 4)  # 몸통이 실제로 움직인 프레임만
    slope = np.sum(hx[ok] * bx[ok]) / np.sum(bx[ok] ** 2)
    r = np.corrcoef(hx[ok], bx[ok])[0, 1]
    print(f"head {hk:5} / body {bk:9}: slope {slope:+.2f}  r={r:+.2f}  n={ok.sum()}  body range p90={np.percentile(np.abs(bx[ok]), 90):.0f}°")
