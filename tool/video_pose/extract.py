"""MediaPipe PoseLandmarker(heavy)로 영상의 프레임별 3D(world) + 2D 관절 좌표를 뽑아 npz로 저장.

usage: extract.py <model.task> <video> <out.npz> [start_sec] [end_sec]
world: (N, 33, 3) 미터, 골반 중심 원점. MediaPipe 좌표계: x 화면 오른쪽, y 아래, z 카메라 쪽이 음수.
img:   (N, 33, 3) 정규화 이미지 좌표 + 가시성.
없는 프레임은 NaN.
"""
import sys

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python as mpt
from mediapipe.tasks.python import vision

model, video, out = sys.argv[1:4]
start = float(sys.argv[4]) if len(sys.argv) > 4 else 0
end = float(sys.argv[5]) if len(sys.argv) > 5 else 1e9

opts = vision.PoseLandmarkerOptions(
    base_options=mpt.BaseOptions(model_asset_path=model),
    running_mode=vision.RunningMode.VIDEO,
    num_poses=1,
)
cap = cv2.VideoCapture(video)
fps = cap.get(cv2.CAP_PROP_FPS)
cap.set(cv2.CAP_PROP_POS_FRAMES, int(start * fps))
world, img, times = [], [], []
with vision.PoseLandmarker.create_from_options(opts) as lm:
    i = int(start * fps)
    while True:
        ok, f = cap.read()
        if not ok or i / fps > end:
            break
        t = i / fps
        rgb = cv2.cvtColor(f, cv2.COLOR_BGR2RGB)
        res = lm.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), int(t * 1000))
        if res.pose_world_landmarks:
            world.append([[p.x, p.y, p.z] for p in res.pose_world_landmarks[0]])
            img.append([[p.x, p.y, p.visibility] for p in res.pose_landmarks[0]])
        else:
            world.append(np.full((33, 3), np.nan))
            img.append(np.full((33, 3), np.nan))
        times.append(t)
        i += 1
np.savez_compressed(out, world=np.array(world, float), img=np.array(img, float), t=np.array(times), fps=fps)
print(out, len(times), "frames", f"{np.mean(~np.isnan(np.array(world)[:, 0, 0])):.0%} detected")
