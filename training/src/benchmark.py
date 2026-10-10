"""Latency benchmark (forward pass only, batch 1, no NMS) for YOLOv5 and Ultralytics checkpoints.

Usage: python benchmark.py --yolo-dir /tmp/lm/yolov5 --weights a.pt b.pt --names a b --out latency.json
YOLOv5 checkpoints that contain CBAM need the CBAM-patched YOLOv5 checkout on the path.
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("--yolo-dir", required=True)
ap.add_argument("--weights", nargs="+", required=True)
ap.add_argument("--names", nargs="+", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--imgsz", type=int, default=416)
ap.add_argument("--gpu-iters", type=int, default=300)
ap.add_argument("--cpu-iters", type=int, default=30)
a = ap.parse_args()
weights = [str(Path(w).resolve()) for w in a.weights]
out_path = Path(a.out).resolve()

sys.path.insert(0, str(Path(a.yolo_dir).resolve()))
os.chdir(a.yolo_dir)
import torch  # noqa: E402
from ultralytics.utils.patches import torch_load  # noqa: E402


def load(path):
    ckpt = torch_load(path, map_location="cpu")
    model = (ckpt.get("ema") or ckpt["model"]).float()
    if hasattr(model, "fuse"):
        model = model.fuse()
    return model.eval()


@torch.no_grad()
def time_it(model, device, iters, half):
    model = model.to(device)
    x = torch.zeros(1, 3, a.imgsz, a.imgsz, device=device)
    if half:
        model, x = model.half(), x.half()
    for _ in range(max(iters // 10, 3)):
        model(x)
    if device == "cuda":
        torch.cuda.synchronize()
    t = time.perf_counter()
    for _ in range(iters):
        model(x)
    if device == "cuda":
        torch.cuda.synchronize()
    return (time.perf_counter() - t) / iters * 1000


res = {"imgsz": a.imgsz, "batch": 1, "note": "forward pass only, no NMS", "cpu_threads": torch.get_num_threads(),
       "gpu": torch.cuda.get_device_name(0) if torch.cuda.is_available() else None, "models": {}}
for name, w in zip(a.names, weights):
    model = load(w)
    r = {"weights": w, "cpu_fp32_ms": time_it(model, "cpu", a.cpu_iters, False)}
    if torch.cuda.is_available():
        r["gpu_fp16_ms"] = time_it(load(w), "cuda", a.gpu_iters, True)
        r["gpu_fp16_fps"] = 1000 / r["gpu_fp16_ms"]
    res["models"][name] = r
    print(name, {k: round(v, 2) for k, v in r.items() if k != "weights"})
out_path.write_text(json.dumps(res, indent=2))
