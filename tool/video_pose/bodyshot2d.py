"""옆에 가까운 각도로 찍힌 바디샷을 2D 화면 좌표로 잰다 (깊이 오차가 큰 3D 대신).

usage: bodyshot2d.py <poses.npz> <aspect h/w> <ref_start> <ref_end> <t1,t2,...>
ref 구간 = 펀치 없이 가드로 선 구간 (기준 자세).
임팩트 시각은 프레임을 보고 직접 준다 (2D에서는 비스듬히 뻗은 팔이 짧아 보여 자동 검출이 틀린다).
치는 손 = 어깨보다 가로로 더 멀리 나간 손목.
지표 (길이는 기준 자세의 몸통 길이 단위, y 위 +):
  arm      어깨→손목이 수평에서 아래로 기운 각(도)
  lean     상체(골반→어깨)가 수직에서 기운 각(도, 펀치 방향 +)
  drop     엉덩이~발목 세로 길이 감소
  stance   두 발목 가로 거리 증가
  headFwd  코가 두 발목 중앙보다 펀치 방향으로 나간 정도 (기준 대비 증가)
  shY      치는 쪽 어깨 높이 변화 (+ = 올라감)
"""
import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
from body import LANK, LHIP, LSH, LWR, NOSE, RANK, RHIP, RSH, RWR, load, smooth  # noqa: E402

path, aspect = sys.argv[1], float(sys.argv[2])
_, t, fps, img = load(path)
p = img[..., :2].copy()
p[..., 1] = -p[..., 1] * aspect  # y 위 +, 가로세로 같은 단위
ra, rb = float(sys.argv[3]), float(sys.argv[4])
ref = (t >= ra) & (t <= rb)
impacts = [float(x) for x in sys.argv[5].split(",")]

S = lambda x: smooth(x, 3)
hip = (p[:, LHIP] + p[:, RHIP]) / 2
sh = (p[:, LSH] + p[:, RSH]) / 2
ank = (p[:, LANK] + p[:, RANK]) / 2
L = np.nanmedian(np.linalg.norm(sh[ref] - hip[ref], axis=1))
height = S(hip[:, 1] - ank[:, 1]) / L
stance = S(np.abs(p[:, LANK, 0] - p[:, RANK, 0])) / L
base = {k: np.nanmedian(v[ref]) for k, v in (("height", height), ("stance", stance))}

rows = []
for ti in impacts:
    i = int(np.argmin(np.abs(t - ti)))
    s_, w_ = max(((LSH, LWR), (RSH, RWR)), key=lambda k: abs(p[i, k[1], 0] - p[i, k[0], 0]))
    v = p[i, w_] - p[i, s_]
    d = np.sign(v[0])  # 펀치 방향(화면 좌/우)
    arm = np.degrees(np.arctan2(-v[1], abs(v[0])))
    tr = sh[i] - hip[i]
    lean = np.degrees(np.arctan2(d * tr[0], tr[1]))
    headF = d * (p[i, NOSE, 0] - ank[i, 0]) / L
    headF0 = np.nanmedian(d * (p[ref, NOSE, 0] - ank[ref, 0])) / L
    lean0 = np.nanmedian(np.degrees(np.arctan2(d * (sh[ref, 0] - hip[ref, 0]), sh[ref, 1] - hip[ref, 1])))
    rows.append([t[i], 0 if w_ == LWR else 1, arm, lean - lean0, base["height"] - height[i], stance[i] - base["stance"], headF - headF0])
rows = np.array(rows)
names = ["t", "R?", "arm", "lean", "drop", "stance", "headFwd"]
print(f"L={L:.3f} base height={base['height']:.2f} stance={base['stance']:.2f}")
print(" ".join(f"{n:>7}" for n in names))
for r in rows:
    print(" ".join(f"{x:7.2f}" for x in r))
for hand in (0, 1):
    g = rows[rows[:, 1] == hand]
    if len(g):
        print(f"median {'L' if hand == 0 else 'R'} n={len(g)} " + " ".join(f"{n}={np.median(g[:, k]):+.2f}" for k, n in enumerate(names) if k > 1))
