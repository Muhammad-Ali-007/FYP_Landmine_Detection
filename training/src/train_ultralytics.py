"""Train an Ultralytics model (YOLO11) and evaluate it on val and test; writes metrics.json like eval_yolov5.py.

Usage: python train_ultralytics.py --model yolo11m.pt --data data.yaml --project out --name run --seed 0
"""

import argparse
import json
from pathlib import Path

from ultralytics import YOLO
from ultralytics.utils.torch_utils import get_flops, get_num_params


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--data", required=True)
    ap.add_argument("--project", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--epochs", type=int, default=200)
    ap.add_argument("--imgsz", type=int, default=416)
    ap.add_argument("--batch", type=int, default=16)
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--device", default="0")
    a = ap.parse_args()
    project = str(Path(a.project).resolve())

    YOLO(a.model).train(data=a.data, epochs=a.epochs, imgsz=a.imgsz, batch=a.batch, seed=a.seed, deterministic=True,
                        device=a.device, workers=a.workers, cache="ram", patience=100, project=project, name=a.name,
                        exist_ok=True, plots=True)

    run_dir = Path(project, a.name)
    best = run_dir / "weights" / "best.pt"
    model = YOLO(str(best))
    res = {"weights": str(best), "imgsz": a.imgsz}
    for split in ("val", "test"):
        r = model.val(data=a.data, split=split, imgsz=a.imgsz, batch=32, device=a.device, workers=a.workers,
                      project=str(run_dir),
                      name=f"eval_{split}", exist_ok=True, plots=True)
        mp, mr = float(r.box.mp), float(r.box.mr)
        res[split] = {"precision": mp, "recall": mr, "f1": 2 * mp * mr / (mp + mr + 1e-16),
                      "map50": float(r.box.map50), "map50_95": float(r.box.map),
                      "speed_ms_per_img": {k: float(v) for k, v in r.speed.items()}}
    res["params"] = int(get_num_params(model.model))
    res["gflops"] = float(get_flops(model.model, imgsz=a.imgsz))
    (run_dir / "metrics.json").write_text(json.dumps(res, indent=2))
    print(json.dumps(res, indent=2))


if __name__ == "__main__":  # required on Windows, where data-loader workers re-import this file
    main()
