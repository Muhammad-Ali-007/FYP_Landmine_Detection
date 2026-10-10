"""Evaluate a trained YOLOv5 checkpoint on the val and test splits and write metrics.json.

Usage: python eval_yolov5.py --yolo-dir /tmp/lm/yolov5 --weights best.pt --data data.yaml --out run_dir
"""

import argparse
import copy
import json
import os
import sys
from pathlib import Path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--yolo-dir", required=True)
    ap.add_argument("--weights", required=True)
    ap.add_argument("--data", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--imgsz", type=int, default=416)
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--workers", type=int, default=8)
    a = ap.parse_args()
    weights, data, out = (str(Path(p).resolve()) for p in (a.weights, a.data, a.out))

    sys.path.insert(0, str(Path(a.yolo_dir).resolve()))
    os.chdir(a.yolo_dir)
    import thop
    import torch
    import val
    from models.experimental import attempt_load

    cuda = torch.cuda.is_available()
    res = {"weights": weights, "imgsz": a.imgsz}
    for task in ("val", "test"):
        (mp, mr, map50, map5095, *_), _, t = val.run(
            data=data, weights=weights, imgsz=a.imgsz, batch_size=a.batch, task=task,
            device="0" if cuda else "cpu", half=cuda, workers=a.workers, project=out, name=f"eval_{task}",
            exist_ok=True, plots=True)
        res[task] = {"precision": float(mp), "recall": float(mr), "f1": float(2 * mp * mr / (mp + mr + 1e-16)),
                     "map50": float(map50), "map50_95": float(map5095),
                     "speed_ms_per_img": {"pre": t[0], "inference": t[1], "nms": t[2]}}

    model = attempt_load(weights, device="cpu", fuse=False).float().eval()
    res["params"] = int(sum(p.numel() for p in model.parameters()))
    macs = thop.profile(copy.deepcopy(model), inputs=(torch.zeros(1, 3, a.imgsz, a.imgsz),), verbose=False)[0]
    res["gflops"] = 2 * macs / 1e9
    Path(out, "metrics.json").write_text(json.dumps(res, indent=2))
    print(json.dumps(res, indent=2))


if __name__ == "__main__":  # required on Windows, where data-loader workers re-import this file
    main()
