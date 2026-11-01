"""펀치를 치지 않는 구간의 가드 바운스(골반 오르내림) 주기와 크기를 잰다.

usage: bounce.py <CMU asf/amc 폴더>
구간: 두 손목 속도가 1.5m/s 미만으로 1초 이상 이어진 곳. 골반 높이를 앱 단위(다리 길이 비율)로 바꿔
주파수(영점 교차)와 크기(봉우리-골 절반)를 낸다.
"""
import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
from amc import load  # noqa: E402
from export import CLIPS, SHIN, SRC_FPS, THIGH  # noqa: E402

base = sys.argv[1]
freqs, amps = [], []
for asf, amc in CLIPS:
    names, jt = load(f"{base}/{asf}.asf", f"{base}/{amc}.amc")
    ix = {n: i for i, n in enumerate(names)}
    P = lambda n: jt[:, ix[n]]  # noqa: E731
    leg = np.median(np.linalg.norm(P("lfemur") - P("lhipjoint"), axis=1) + np.linalg.norm(P("ltibia") - P("lfemur"), axis=1))
    y = P("root")[:, 1] * (THIGH + SHIN) / leg
    calm = np.ones(len(y), bool)
    for h in "lr":
        calm &= np.linalg.norm(np.gradient(P(h + "wrist"), axis=0), axis=1) * SRC_FPS < 1.5
    i = 0
    while i < len(y):
        if not calm[i]:
            i += 1
            continue
        j = i
        while j < len(y) and calm[j]:
            j += 1
        if j - i >= SRC_FPS:
            # 느린 높이 변화(자세 낮춤 등)는 1초 이동평균으로 빼고, 끝은 가장자리 값으로 채운다.
            k = SRC_FPS
            pad = np.pad(y[i:j], k // 2, mode="edge")
            seg = y[i:j] - np.convolve(pad, np.ones(k) / k, mode="valid")[:j - i]
            if len(seg) >= SRC_FPS:
                zc = np.sum(np.diff(np.sign(seg)) != 0)
                freqs.append(zc / 2 / (len(seg) / SRC_FPS))
                amps.append((np.percentile(seg, 95) - np.percentile(seg, 5)) / 2)
        i = j
print(f"calm segments {len(freqs)}  bounce freq median {np.median(freqs):.2f}Hz (IQR {np.percentile(freqs, 25):.2f}-{np.percentile(freqs, 75):.2f})"
      f"  amplitude median {np.median(amps):.3f} (IQR {np.percentile(amps, 25):.3f}-{np.percentile(amps, 75):.3f})")
