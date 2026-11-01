"""몸 지표 시계열 그래프. usage: plot.py <poses.npz> <out.png> <start> <end> [keys,comma]"""
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
from body import load, metrics, smooth  # noqa: E402

w, t, fps, _ = load(sys.argv[1])
a, b = float(sys.argv[3]), float(sys.argv[4])
keys = sys.argv[5].split(",") if len(sys.argv) > 5 else ["roll", "pitch", "height", "headX", "headZ", "shYaw", "hipYaw"]
sel = (t >= a) & (t <= b)
m = metrics(w[sel])
t = t[sel]
fig, axs = plt.subplots(len(keys), 1, figsize=(22, 2.0 * len(keys)), sharex=True)
for ax, k in zip(axs, keys):
    ax.plot(t, smooth(m[k], 3), lw=1)
    ax.set_ylabel(k)
    ax.grid(alpha=0.4)
    ax.set_xticks(np.arange(np.ceil(a), b, 1), minor=True)
    ax.set_xticks(np.arange(np.ceil(a / 5) * 5, b, 5))
    ax.grid(which="minor", alpha=0.15)
plt.tight_layout()
plt.savefig(sys.argv[2], dpi=70)
