"""영상에서 일정 간격(또는 구간)으로 프레임을 뽑아 타임스탬프를 붙인 격자 이미지로 저장.

usage: sheet.py <video> <out.png> [step_sec] [start_sec] [end_sec] [cols]
"""
import sys

import cv2
import numpy as np

video, out = sys.argv[1], sys.argv[2]
step = float(sys.argv[3]) if len(sys.argv) > 3 else 6
cap = cv2.VideoCapture(video)
fps = cap.get(cv2.CAP_PROP_FPS)
n = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
start = float(sys.argv[4]) if len(sys.argv) > 4 else 0
end = float(sys.argv[5]) if len(sys.argv) > 5 else n / fps
cols = int(sys.argv[6]) if len(sys.argv) > 6 else 6

tiles = []
t = start
while t < end:
    cap.set(cv2.CAP_PROP_POS_FRAMES, int(t * fps))
    ok, f = cap.read()
    if not ok:
        break
    h, w = f.shape[:2]
    f = cv2.resize(f, (320, int(320 * h / w)))
    cv2.putText(f, f"{t:.2f}", (5, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 4)
    cv2.putText(f, f"{t:.2f}", (5, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
    tiles.append(f)
    t += step
while len(tiles) % cols:
    tiles.append(np.zeros_like(tiles[0]))
rows = [np.hstack(tiles[i:i + cols]) for i in range(0, len(tiles), cols)]
cv2.imwrite(out, np.vstack(rows))
print(f"fps={fps:.2f} frames={n} dur={n / fps:.1f}s tiles={len(tiles)}")
