"""지정한 시각들의 프레임을 잘라 한 줄로. usage: frames.py <video> <out.png> <t1,t2,...> [crop x0,y0,x1,y1 비율] [width]"""
import sys

import cv2
import numpy as np

video, out, ts = sys.argv[1], sys.argv[2], [float(x) for x in sys.argv[3].split(",")]
crop = [float(x) for x in sys.argv[4].split(",")] if len(sys.argv) > 4 else [0, 0, 1, 1]
width = int(sys.argv[5]) if len(sys.argv) > 5 else 260
cap = cv2.VideoCapture(video)
fps = cap.get(cv2.CAP_PROP_FPS)
tiles = []
for t in ts:
    cap.set(cv2.CAP_PROP_POS_FRAMES, int(round(t * fps)))
    ok, f = cap.read()
    h, w = f.shape[:2]
    f = f[int(crop[1] * h):int(crop[3] * h), int(crop[0] * w):int(crop[2] * w)]
    f = cv2.resize(f, (width, int(width * f.shape[0] / f.shape[1])))
    cv2.putText(f, f"{t:.2f}", (4, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 4)
    cv2.putText(f, f"{t:.2f}", (4, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
    tiles.append(f)
cols = int(sys.argv[6]) if len(sys.argv) > 6 else len(tiles)
while len(tiles) % cols:
    tiles.append(np.zeros_like(tiles[0]))
cv2.imwrite(out, np.vstack([np.hstack(tiles[i:i + cols]) for i in range(0, len(tiles), cols)]))
