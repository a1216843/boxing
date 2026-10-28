"""BoxingVI 2D 포즈와 앱 인형을 같은 지표로 비교한다.

사용법은 같은 폴더의 README.md 참고.
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
import openpyxl

FPS = 30
ASPECT = 16 / 9  # 좌표가 영상 가로·세로로 따로 정규화돼 있어 가로를 되돌린다.
CLASSES = ["Jab", "Cross", "Lead Hook", "Rear Hook", "Lead Uppercut", "Rear Uppercut"]
LEAD_CLASSES = {"Jab", "Lead Hook", "Lead Uppercut"}

# COCO
NOSE, LS, RS, LE, RE, LW, RW, LH, RH, LK, RK, LA, RA = 0, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16


def load_rows(xlsx):
    ws = openpyxl.load_workbook(xlsx, read_only=True).active
    rows = []
    for r in ws.iter_rows(min_row=1, max_col=6, values_only=True):
        if not isinstance(r[0], (int, float)):
            continue
        if isinstance(r[2], str):
            start, end, cls = r[0], r[1], r[2]
        elif len(r) > 4 and isinstance(r[4], str):
            start, end, cls = r[0], r[2], r[4]
        else:
            continue
        if not isinstance(end, (int, float)):
            continue
        rows.append((int(start), int(end), cls.strip().title().replace("Uppercut", "Uppercut")))
    return rows


def norm_class(c):
    c = c.lower()
    for k in CLASSES:
        if c == k.lower():
            return k
    return None


def load_dataset(data):
    clips = []  # (video, class, frames[n,17,2])
    for i in range(1, 11):
        if i == 6:
            continue  # 프레임 단위 데이터라 클립 경계가 불확실
        v = f"V{i}"
        arr = np.load(data / "Skeleton_data" / f"{v}.npy", allow_pickle=False)
        rows = load_rows(data / "Annotation_files" / f"{v}.xlsx")
        if len(rows) != len(arr):
            print(f"  {v}: 주석 {len(rows)} / 클립 {len(arr)} 불일치 → 앞에서부터 맞춤", file=sys.stderr)
        for (start, end, cls), clip in zip(rows, arr):
            cls = norm_class(cls)
            if cls is None:
                continue
            valid = np.abs(clip).sum(axis=(1, 2)) > 0
            n = int(valid.sum())
            if n < 4:
                continue
            f = clip[:n].copy()
            f[..., 0] *= ASPECT
            clips.append((v, cls, f))
    return clips


def project(frames3d, yaw_deg, elev_deg=6):
    """3D(x 오른쪽, y 위, z 앞) → 이미지 2D(x 오른쪽, y 아래), 정사영."""
    p = np.asarray(frames3d)
    y, e = math.radians(yaw_deg), math.radians(elev_deg)
    x = p[..., 0] * math.cos(y) + p[..., 2] * math.sin(y)
    z = -p[..., 0] * math.sin(y) + p[..., 2] * math.cos(y)
    yy = p[..., 1] * math.cos(e) - z * math.sin(e)
    return np.stack([x, -yy], axis=-1)


def clip_metrics(f, punch_lead, lead_is_left, upper=False):
    n = len(f)
    mid_s = (f[:, LS] + f[:, RS]) / 2
    mid_h = (f[:, LH] + f[:, RH]) / 2
    torso = np.linalg.norm(mid_s - mid_h, axis=1).mean()
    if torso < 1e-4:
        return None
    f = f / torso

    left_punch = punch_lead == lead_is_left
    sh, wr = (LS, LW) if left_punch else (RS, RW)
    lead_ankle, rear_ankle = (LA, RA) if lead_is_left else (RA, LA)

    ext = np.linalg.norm(f[:, wr] - f[:, sh], axis=1)
    imp = int(np.argmin(f[:, wr, 1])) if upper else int(np.argmax(ext))
    out = {
        "dur_ms": n / FPS * 1000,
        "impact_frac": imp / max(1, n - 1),
        "ext_gain": ext[imp] - ext[0],
    }

    path = f[: imp + 1, wr]
    chord = path[-1] - path[0]
    cl = np.linalg.norm(chord)
    if cl > 0.1 and len(path) >= 3:
        d = path - path[0]
        perp = np.abs(d[:, 0] * chord[1] - d[:, 1] * chord[0]) / cl
        out["curvature"] = perp.max() / cl
    out["rise"] = f[0, wr, 1] - f[imp, wr, 1]

    def rotation_peak(a, b):
        v = f[:, a] - f[:, b]
        prog = np.linalg.norm(v - v[0], axis=1)
        if prog.max() < 0.08 or n < 4:
            return None
        return int(np.argmax(np.abs(np.diff(prog))))

    ts, th = rotation_peak(LS, RS), rotation_peak(LH, RH)
    if ts is not None and th is not None:
        out["hip_lead_ms"] = (ts - th) / FPS * 1000

    la = np.linalg.norm(f[:, lead_ankle] - f[0, lead_ankle], axis=1).max()
    ra = np.linalg.norm(f[:, rear_ankle] - f[0, rear_ankle], axis=1).max()
    out["lead_foot_move"] = la
    out["rear_foot_move"] = ra
    out["drop"] = (mid_h[:, 1] / torso - mid_h[0, 1] / torso).max()
    return out


def stance_of_video(clips):
    """잽에서 더 많이 뻗는 손 = 리드 손. 왼손이 리드면 오소독스."""
    votes = 0
    for _, cls, f in clips:
        if cls != "Jab":
            continue
        el = np.linalg.norm(f[:, LW] - f[:, LS], axis=1)
        er = np.linalg.norm(f[:, RW] - f[:, RS], axis=1)
        votes += 1 if (el.max() - el[0]) > (er.max() - er[0]) else -1
    return votes >= 0


def summarize(values):
    a = np.array([v for v in values if v is not None and not math.isnan(v)])
    if len(a) == 0:
        return "-"
    q1, med, q3 = np.percentile(a, [25, 50, 75])
    return f"{med:7.2f} [{q1:6.2f},{q3:6.2f}]"


def main():
    data, model_path = Path(sys.argv[1]), Path(sys.argv[2])
    clips = load_dataset(data)
    print(f"클립 {len(clips)}개 (V6 제외)")

    by_video = {}
    for c in clips:
        by_video.setdefault(c[0], []).append(c)
    stance = {v: stance_of_video(cs) for v, cs in by_video.items()}
    print("오소독스 판정:", {v: ("오소" if s else "사우스") for v, s in stance.items()})

    real = {c: [] for c in CLASSES}
    for v, cls, f in clips:
        m = clip_metrics(f, cls in LEAD_CLASSES, stance[v], "Uppercut" in cls)
        if m:
            real[cls].append(m)

    model = json.loads(model_path.read_text(encoding="utf-8"))
    yaws = [-90, -60, -30, 0, 30, 60, 90]
    sim = {c: [] for c in CLASSES}
    for cls in CLASSES:
        frames3d = np.array(model[cls]["frames"])
        for yaw in yaws:
            f2 = project(frames3d, yaw)
            m = clip_metrics(f2, cls in LEAD_CLASSES, True, "Uppercut" in cls)
            if m:
                sim[cls].append(m)

    keys = [
        ("dur_ms", "소요 시간(ms)"),
        ("impact_frac", "임팩트 시점(비율)"),
        ("ext_gain", "팔 뻗음(몸통 단위)"),
        ("curvature", "궤적 휨(휨/직선거리)"),
        ("rise", "주먹 상승(몸통 단위)"),
        ("hip_lead_ms", "골반이 어깨보다 먼저(ms)"),
        ("lead_foot_move", "앞발 이동(몸통 단위)"),
        ("rear_foot_move", "뒷발 이동(몸통 단위)"),
        ("drop", "골반 낮춤(몸통 단위)"),
    ]
    result = {}
    for cls in CLASSES:
        print(f"\n=== {cls}  (실제 {len(real[cls])}개, 인형 {len(sim[cls])}개 시점) ===")
        print(f"{'지표':<26}{'실제: 중앙값 [25%,75%]':<30}{'인형: 중앙값 [25%,75%]'}")
        result[cls] = {}
        for k, label in keys:
            rv = [m.get(k) for m in real[cls]]
            sv = [m.get(k) for m in sim[cls]]
            print(f"{label:<26}{summarize(rv):<30}{summarize(sv)}")
            ra = np.array([x for x in rv if x is not None])
            result[cls][k] = {
                "real_median": float(np.median(ra)) if len(ra) else None,
                "model_median": float(np.median([x for x in sv if x is not None])) if any(x is not None for x in sv) else None,
            }
        # 스텝 비율: 앞발이 몸통 길이의 25% 이상 움직인 클립
        lf = np.array([m["lead_foot_move"] for m in real[cls]])
        print(f"{'앞발 스텝 비율(>0.25)':<26}{(lf > 0.25).mean() * 100:6.1f}%")
        result[cls]["step_ratio"] = float((lf > 0.25).mean())
    (model_path.parent / "comparison.json").write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
