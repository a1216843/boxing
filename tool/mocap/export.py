"""CMU 모션캡처 복싱 클립에서 펀치 종류별 움직임 곡선을 뽑아 lib/pose/mocap_data.dart를 만든다.

usage: export.py <CMU asf/amc 폴더> <출력 dart>

자세(가드, 임팩트 모양)는 앱의 정석 키 자세를 쓰고, 그 사이를 가는 방식만 실제 사람에게서 가져온다.
피험자가 복싱 선수가 아니라 자세는 엉성하지만(넓은 스탠스, 내려가는 가드), 가속·감속과 부위별 순서는 사람의 것이다.

1. 펀치 검출: 손목 속도 봉우리 (3m/s 이상). 주먹이 멈춘 순간이 임팩트, 손목이 머리 옆으로 돌아온 때가 끝.
2. 상대 방향: 가슴 정면과 뒷발→앞발 방향의 평균. 앞발 = 가슴 정면 쪽으로 더 나간 발.
3. 분류: 임팩트 때 팔꿈치 각도·높이와 주먹이 올라간 양으로 스트레이트(팔을 폄)/훅(90~130°로 굽혀 수평).
4. 곡선: 펀치마다 출발→임팩트, 임팩트→복귀 구간을 각각 시간 정규화해 부위별 진행도(0~1)를 재고,
   종류별로 중앙값을 낸다. 한 사람의 버릇이 아니라 여러 펀치의 공통 모양이 남는다.
   - 주먹: 출발 위치에서 멀어진 거리 / 임팩트 때 거리 (복귀는 끝 위치 기준)
   - 골반·어깨: 수평 회전각 변화 / 임팩트 때 변화 (회전이 6° 미만인 펀치는 제외)
   - 오르내림: 골반 높이 - 출발·끝을 잇는 직선 (앱 단위, 다리 길이 비율로 환산)
   구간 시간은 쓰지 않는다. 피험자의 복귀가 0.37~0.51초로 실제 선수(BoxingVI 펀치 전체 0.27~0.38초)보다 느려서,
   시간은 앱의 기존 값(BoxingVI)을 두고 곡선 모양만 쓴다.
"""
import json
import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
from amc import load  # noqa: E402

CLIPS = [("13", "13_17"), ("13", "13_18"), ("14", "14_01"), ("14", "14_02"), ("14", "14_03"), ("15", "15_13"), ("17", "17_10")]
SRC_FPS, OUT_FPS = 120, 60
UP = np.array([0.0, 1.0, 0.0])

# 앱 인형 치수 (lib/pose/poses.dart와 같게).
HIP_HALF, TRUNK, SH_HALF, SH_DROP = 0.12, 0.52, 0.17, 0.02
UPPER, FORE, THIGH, SHIN, FOOT, HEAD = 0.3, 0.3, 0.43, 0.40, 0.17, 0.103
J = ["head", "neck", "pelvis", "leadShoulder", "rearShoulder", "leadElbow", "rearElbow", "leadHand", "rearHand",
     "leadHip", "rearHip", "leadKnee", "rearKnee", "leadFoot", "rearFoot", "leadToe", "rearToe"]
# 바디 스트레이트는 데이터에 2개씩뿐이고 팔만 아래로 뻗어 쓰지 않는다 (코치 영상으로 맞춘 키 자세 유지).
MOVES = {"lead-straight": "jab", "rear-straight": "cross", "lead-hook": "leadHook", "rear-hook": "rearHook"}


def hz(v):
    v = np.array(v, float)
    v[..., 1] = 0
    return v / np.linalg.norm(v, axis=-1, keepdims=True)


def unit(v):
    return v / np.linalg.norm(v, axis=-1, keepdims=True)


def angle(a, b, c):
    u, v = a - b, c - b
    return float(np.degrees(np.arccos(u @ v / np.linalg.norm(u) / np.linalg.norm(v))))


def punches(base):
    """손목 속도 봉우리(3m/s 이상)마다 펀치 후보 하나. 주먹이 멈춘 순간(속도 최소)이 임팩트."""
    out = []
    for asf, amc in CLIPS:
        names, jt = load(f"{base}/{asf}.asf", f"{base}/{amc}.amc")
        ix = {n: i for i, n in enumerate(names)}

        def P(n):
            return jt[:, ix[n]]

        n = len(jt)
        speed = {h: np.linalg.norm(np.gradient(P(h + "wrist"), axis=0), axis=1) * SRC_FPS for h in "lr"}
        for h in "lr":
            o = "r" if h == "l" else "l"
            sp, win = speed[h], 30
            i = win
            while i < n - win:
                if not (sp[i] == sp[i - win:i + win + 1].max() and sp[i] > 3.0):
                    i += 1
                    continue
                on = i
                while on > 0 and sp[on] > 0.2 * sp[i]:
                    on -= 1
                hit = i + int(np.argmin(sp[i:i + 24]))  # 0.2초 안에 주먹이 멈춘 순간
                back = hit + int(np.argmin(np.linalg.norm(P(h + "wrist")[hit:hit + 72] - P("head")[hit:hit + 72], axis=1)))
                chest = hz(np.cross(P("rclavicle")[on] - P("lclavicle")[on], UP))
                guard = (P("lwrist")[on] + P("rwrist")[on] - P("lclavicle")[on] - P("rclavicle")[on]) / 2
                if chest @ guard < 0:
                    chest = -chest
                lf, rf = P("ltibia")[on], P("rtibia")[on]
                lead_left = bool((lf - rf) @ chest > 0)
                fwd = hz(hz((lf - rf) if lead_left else (rf - lf)) + chest)
                lat = np.cross(UP, fwd)
                s0 = P(h + "clavicle")[hit]
                v = P(h + "wrist")[hit] - s0
                start = max(0, on - int(0.15 * SRC_FPS))
                stop = min(n - 1, back + int(0.12 * SRC_FPS))
                head = P("head")
                tidy = sum(np.linalg.norm(P(k + "wrist")[f] - head[f]) for k in "lr" for f in (start, stop))
                other = float(speed[o][start:stop + 1].max())
                out.append(dict(clip=(asf, amc), hand=h, lead=(h == "l") == lead_left, lead_left=lead_left,
                                on=on, peak=hit, back=back, start=start, stop=stop, fwd=fwd.tolist(), lat=lat.tolist(),
                                f=float(v @ fwd), rise=float((P(h + "wrist")[hit] - P(h + "wrist")[on])[1]),
                                elbow=angle(s0, P(h + "humerus")[hit], P(h + "radius")[hit]),
                                elbowUp=float(P(h + "humerus")[hit][1] - s0[1]),
                                wristH=float(P(h + "wrist")[hit][1] - P("lowerneck")[hit][1]),
                                t=(hit - on) / SRC_FPS, tidy=float(tidy), other=other, speed=float(sp[i])))
                i += win
    return out


def classify(x):
    if x["t"] > 0.3:
        return None
    side = "lead" if x["lead"] else "rear"
    if x["wristH"] < -0.2:
        return None  # 바디샷은 쓰지 않는다
    # 훅: 팔꿈치를 90~130°로 굽힌 채 어깨 높이 근처로 들고 수평으로 휘두른다.
    if x["elbow"] < 130 and x["elbowUp"] > -0.12 and x["rise"] < 0.12:
        return side + "-hook"
    if x["elbow"] > 150 and x["f"] > 0.4:
        return side + "-straight"
    return None


PROFILE = {"lead-straight": "jab", "rear-straight": "cross", "lead-hook": "hook", "rear-hook": "hook"}
RISE_N, FALL_N = 20, 30


def yaw(v):
    return np.degrees(np.arctan2(v[..., 2], v[..., 0]))


def curves(base, group):
    """한 종류 펀치들의 정규화 곡선 중앙값과 구간 시간 중앙값."""
    rows = {k: [] for k in ("hand", "hip", "sh", "bob")}
    rise_t, fall_t = [], []
    cache = {}
    for x in group:
        asf, amc = x["clip"]
        if amc not in cache:
            names, jt = load(f"{base}/{asf}.asf", f"{base}/{amc}.amc")
            cache[amc] = ({n: i for i, n in enumerate(names)}, jt)
        ix, jt = cache[amc]

        def P(n):
            return jt[:, ix[n]]

        on, hit, back = x["on"], x["peak"], x["back"]
        if back - hit < 6 or hit - on < 4:
            continue
        rise_t.append((hit - on) / SRC_FPS)
        fall_t.append((back - hit) / SRC_FPS)
        w = P(x["hand"] + "wrist")
        hip = np.unwrap(np.radians(yaw(P("rfemur") - P("lfemur")))) * 180 / np.pi
        sh = np.unwrap(np.radians(yaw(P("rclavicle") - P("lclavicle")))) * 180 / np.pi
        leg = np.linalg.norm(P("lfemur")[on] - P("lhipjoint")[on]) + np.linalg.norm(P("ltibia")[on] - P("lfemur")[on])
        y = P("root")[:, 1] * (THIGH + SHIN) / leg

        def seg(a, b, n):
            return np.linspace(a, b, n + 1)

        def at(arr, ts):
            return np.interp(ts, np.arange(len(arr)), arr)

        r, f = seg(on, hit, RISE_N), seg(hit, back, FALL_N)
        dh = np.linalg.norm(w - w[on], axis=1)
        db = np.linalg.norm(w - w[back], axis=1)
        hand = np.concatenate([at(dh, r) / dh[hit], at(db, f)[1:] / db[hit]])
        rows["hand"].append(hand)
        for k, a in (("hip", hip), ("sh", sh)):
            if abs(a[hit] - a[on]) >= 6 and abs(a[hit] - a[back]) >= 6:
                rows[k].append(np.concatenate([(at(a, r) - a[on]) / (a[hit] - a[on]),
                                               (at(a, f)[1:] - a[back]) / (a[hit] - a[back])]))
        line = lambda ts: y[on] + (y[back] - y[on]) * (ts - on) / (back - on)  # noqa: E731
        ts = np.concatenate([r, f[1:]])
        rows["bob"].append(at(y, ts) - line(ts))
    # 회전이 작은 펀치가 많아 표본이 3개 미만이면 어깨(그것도 없으면 주먹) 곡선으로 대신한다.
    out = {k: np.median(np.array(v), 0) if len(v) >= 3 else None for k, v in rows.items()}
    out["sh"] = out["sh"] if out["sh"] is not None else out["hand"]
    out["hip"] = out["hip"] if out["hip"] is not None else out["sh"]
    out["n"] = {k: len(v) for k, v in rows.items()}
    out["rise"], out["fall"] = float(np.median(rise_t)), float(np.median(fall_t))
    return out


def main():
    base, dart = sys.argv[1], sys.argv[2]
    groups = {}
    for x in punches(base):
        c = classify(x)
        if c in PROFILE:
            groups.setdefault(PROFILE[c], []).append(x)
    profiles = {k: curves(base, g) for k, g in groups.items()}
    for k, p in profiles.items():
        print(f"{k}: n={p['n']} rise {p['rise']*1000:.0f}ms fall {p['fall']*1000:.0f}ms "
              f"bob min {p['bob'].min():+.3f} max {p['bob'].max():+.3f}")
        mid = RISE_N // 2
        print(f"   at half of rise: hand {p['hand'][mid]:.2f} hip {p['hip'][mid]:.2f} shoulder {p['sh'][mid]:.2f}")
    lines = [
        "// 생성 파일 - 직접 고치지 말 것. tool/mocap/export.py",
        "// 출처: CMU Graphics Lab Motion Capture Database (http://mocap.cs.cmu.edu), 복싱 클립 7개.",
        "// 이용 조건: The motion capture data may be copied, modified, or redistributed without permission.",
        "",
        "part of 'mocap.dart';",
        "",
        f"const _riseN = {RISE_N};",
        "",
        "const _profiles = <String, MotionProfile>{",
    ]

    def arr(v):
        return "[" + ", ".join(f"{x:.3f}" for x in v) + "]"

    for k, p in profiles.items():
        lines += [
            f"  // 펀치 {p['n']['hand']}개 (골반 {p['n']['hip']}, 어깨 {p['n']['sh']})",
            f"  '{k}': MotionProfile._({p['rise']:.3f}, {p['fall']:.3f},",
            f"      hand: {arr(p['hand'])},",
            f"      hip: {arr(p['hip'])},",
            f"      shoulder: {arr(p['sh'])},",
            f"      bob: {arr(p['bob'])}),",
        ]
    lines.append("};")
    with open(dart, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
