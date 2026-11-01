"""CMU ASF/AMC 파서: 프레임별 관절 월드 좌표(미터, y 위)."""
import numpy as np

SCALE = (1.0 / 0.45) * 2.54 / 100.0


def euler(x, y, z):
    x, y, z = np.deg2rad([x, y, z])
    cx, sx, cy, sy, cz, sz = np.cos(x), np.sin(x), np.cos(y), np.sin(y), np.cos(z), np.sin(z)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rz @ Ry @ Rx


def parse_asf(path):
    lines = [l.strip() for l in open(path)]
    bones = {"root": dict(name="root", dir=np.zeros(3), len=0.0, axis=np.zeros(3), dof=["rx", "ry", "rz"])}
    i = lines.index(":bonedata") + 1
    cur = None
    while i < len(lines) and not lines[i].startswith(":hierarchy"):
        t = lines[i].split()
        if t and t[0] == "begin":
            cur = dict(dof=[])
        elif t and t[0] == "end":
            bones[cur["name"]] = cur
        elif t and t[0] == "name":
            cur["name"] = t[1]
        elif t and t[0] == "direction":
            cur["dir"] = np.array(list(map(float, t[1:4])))
        elif t and t[0] == "length":
            cur["len"] = float(t[1]) * SCALE
        elif t and t[0] == "axis":
            cur["axis"] = np.array(list(map(float, t[1:4])))
        elif t and t[0] == "dof":
            cur["dof"] = t[1:]
        i += 1
    children = {}
    i += 2  # :hierarchy, begin
    while lines[i] != "end":
        t = lines[i].split()
        children[t[0]] = t[1:]
        i += 1
    return bones, children


def parse_amc(path):
    frames, cur = [], None
    for l in open(path):
        l = l.strip()
        if not l or l[0] in "#:":
            continue
        if l.isdigit():
            cur = {}
            frames.append(cur)
        else:
            t = l.split()
            cur[t[0]] = list(map(float, t[1:]))
    return frames


def fk(bones, children, frame):
    out = {}

    def go(name, parentR, parentP):
        b = bones[name]
        C = euler(*b["axis"])
        vals = frame.get(name, [])
        if name == "root":
            P = np.array(vals[:3]) * SCALE
            M = euler(*vals[3:6])
            R = C @ M @ C.T
        else:
            ang = {d: v for d, v in zip(b["dof"], vals)}
            M = euler(ang.get("rx", 0), ang.get("ry", 0), ang.get("rz", 0))
            R = parentR @ C @ M @ C.T
            P = parentP + b["len"] * (R @ b["dir"])
        out[name] = P
        for c in children.get(name, []):
            go(c, R, P)

    go("root", np.eye(3), np.zeros(3))
    return out


def load(asf, amc, step=1):
    bones, children = parse_asf(asf)
    frames = parse_amc(amc)[::step]
    names = None
    arr = []
    for f in frames:
        j = fk(bones, children, f)
        if names is None:
            names = list(j)
        arr.append([j[n] for n in names])
    return names, np.array(arr)
