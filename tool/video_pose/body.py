"""MediaPipe world 좌표에서 몸 지표 시계열을 계산하는 공용 함수.

좌표: x 화면 오른쪽, y 위(뒤집음), z 카메라 쪽(뒤집음). 선수가 카메라를 대략 마주본다고 가정.
길이는 몸통 길이(어깨 중앙~골반 중앙) 단위로 나눈다.
"""
import numpy as np

NOSE, LSH, RSH, LEL, REL, LWR, RWR, LHIP, RHIP, LKN, RKN, LANK, RANK = 0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28
LEAR, REAR = 7, 8


def load(path):
    d = np.load(path)
    w = d["world"].copy()
    w[..., 1] *= -1
    w[..., 2] *= -1
    return w, d["t"], float(d["fps"]), d["img"]


def smooth(x, k=5):
    """NaN을 보간하고 이동 평균."""
    x = np.asarray(x, float).copy()
    n = np.isnan(x)
    if n.all():
        return x
    x[n] = np.interp(np.flatnonzero(n), np.flatnonzero(~n), x[~n])
    if k <= 1:
        return x
    pad = np.pad(x, k // 2, mode="edge")
    return np.convolve(pad, np.ones(k) / k, mode="valid")


def yaw_of(a, b):
    """a→b 선분의 수평 방향 각(도). 정면(카메라 쪽)을 보면 0."""
    v = b - a
    return np.degrees(np.arctan2(v[..., 2], v[..., 0]))


def metrics(w):
    sh = (w[:, LSH] + w[:, RSH]) / 2
    hip = (w[:, LHIP] + w[:, RHIP]) / 2
    ank = (w[:, LANK] + w[:, RANK]) / 2
    trunk = sh - hip
    L = np.nanmedian(np.linalg.norm(trunk, axis=1))
    m = {}
    m["roll"] = np.degrees(np.arctan2(trunk[:, 0], trunk[:, 1]))  # + = 화면 오른쪽으로 기울임
    m["pitch"] = np.degrees(np.arctan2(trunk[:, 2], trunk[:, 1]))  # + = 카메라 쪽(앞)으로 숙임
    m["height"] = (hip[:, 1] - ank[:, 1]) / L
    head = w[:, NOSE]
    m["headX"] = (head[:, 0] - ank[:, 0]) / L
    m["headZ"] = (head[:, 2] - ank[:, 2]) / L
    m["headY"] = (head[:, 1] - ank[:, 1]) / L
    m["shTilt"] = np.degrees(np.arctan2(w[:, LSH, 1] - w[:, RSH, 1], np.abs(w[:, LSH, 0] - w[:, RSH, 0])))
    m["shYaw"] = yaw_of(w[:, RSH], w[:, LSH])
    m["hipYaw"] = yaw_of(w[:, RHIP], w[:, LHIP])
    m["L"] = L
    return m
