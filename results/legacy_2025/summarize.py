"""Rebuild the 2025 results table from the original training logs in this folder.

All numbers are on the 607-image VALIDATION split (the 2025 runs never evaluated the test split).
Usage: python results/legacy_2025/summarize.py
"""

import csv
import json
from pathlib import Path

HERE = Path(__file__).parent


def yolo_csv(path):
    """Best epoch by the YOLO fitness (0.1*mAP50 + 0.9*mAP50-95), as used to pick best.pt."""
    with open(path) as f:
        rows = [{k.strip(): v.strip() for k, v in r.items()} for r in csv.DictReader(f)]

    def col(r, *names):
        return float(next(r[n] for n in names if n in r))

    keys = {"p": ("metrics/precision", "metrics/precision(B)"), "r": ("metrics/recall", "metrics/recall(B)"),
            "m50": ("metrics/mAP_0.5", "metrics/mAP50(B)"), "m95": ("metrics/mAP_0.5:0.95", "metrics/mAP50-95(B)")}
    best = max(rows, key=lambda r: 0.1 * col(r, *keys["m50"]) + 0.9 * col(r, *keys["m95"]))
    return {"epochs": len(rows), "best_epoch": int(float(best["epoch"])),
            **{k: col(best, *v) for k, v in keys.items()}}


def detectron_metrics(path):
    """Last COCO bbox evaluation in a Detectron2 metrics.json (one or more JSON objects per file)."""
    text, dec, i, evals = path.read_text(), json.JSONDecoder(), 0, []
    while i < len(text):
        while i < len(text) and text[i].isspace():
            i += 1
        if i >= len(text):
            break
        obj, i = dec.raw_decode(text, i)
        if "bbox/AP" in obj:
            evals.append(obj)
    e = evals[-1]
    return {"iteration": e.get("iteration"), "m50": e["bbox/AP50"] / 100, "m95": e["bbox/AP"] / 100}


RUNS = [
    ("YOLOv5x (COCO-pretrained)", "yolov5x", "86.2M"),
    ("YOLOv5 + CBAM + Involution (third-party cfg)", "yolov5_cbam_involution", "9.3M"),
    ("YOLO11s, 30 epochs", "yolo11s_30ep", "~9.4M"),
    ("YOLO11s, 200 epochs", "yolo11s_200ep", "~9.4M"),
    ("YOLO11m, 200 epochs", "yolo11m_200ep", "~20.1M"),
]

if __name__ == "__main__":
    print("| Model | Params | Epochs (best) | P | R | mAP@0.5 | mAP@0.5:0.95 |")
    print("|---|---|---|---|---|---|---|")
    for label, folder, params in RUNS:
        m = yolo_csv(HERE / folder / "results.csv")
        print(f"| {label} | {params} | {m['epochs']} ({m['best_epoch']}) | {m['p']:.3f} | {m['r']:.3f} | "
              f"{m['m50']:.3f} | {m['m95']:.3f} |")
    for label, folder in (("Faster R-CNN R50-FPN", "faster_rcnn_r50"), ("Faster R-CNN X101-FPN", "faster_rcnn_x101")):
        m = detectron_metrics(HERE / folder / "metrics.json")
        print(f"| {label} | - | {m['iteration']} it | - | - | {m['m50']:.3f} | {m['m95']:.3f} |")
