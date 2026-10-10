# 2025 training logs (archive)

Original logs from the runs made for the 2025 thesis on Kaggle (Tesla T4), copied unchanged except for file
names. They are kept so every number in [`docs/ERRATA.md`](../../docs/ERRATA.md) can be checked.

* All metrics are on the **validation** split (607 images, 1,187 boxes) of MineGuard-Thermal v15; none of
  these runs was evaluated on the test split.
* `python summarize.py` rebuilds the table below from the files in this folder.

| Model | Params | Epochs (best) | P | R | mAP@0.5 | mAP@0.5:0.95 |
|---|---|---|---|---|---|---|
| YOLOv5x (COCO-pretrained) | 86.2M | 200 (187) | 0.957 | 0.950 | 0.963 | 0.803 |
| YOLOv5 + CBAM + Involution (third-party cfg) | 9.3M | 200 (179) | 0.929 | 0.900 | 0.944 | 0.668 |
| YOLO11s, 30 epochs | ~9.4M | 30 (28) | 0.943 | 0.913 | 0.967 | 0.721 |
| YOLO11s, 200 epochs | ~9.4M | 200 (200) | 0.956 | 0.942 | 0.975 | 0.803 |
| YOLO11m, 200 epochs | ~20.1M | 200 (200) | 0.947 | 0.948 | 0.978 | 0.818 |
| Faster R-CNN R50-FPN | - | 10,000 it | - | - | 0.952 | 0.613 |
| Faster R-CNN X101-FPN | - | 5,000 it | - | - | 0.944 | 0.614 |

YOLO rows: best epoch by YOLO fitness (0.1·mAP@0.5 + 0.9·mAP@0.5:0.95), i.e. the epoch saved as `best.pt`.
YOLO11 parameter counts are the published COCO sizes (`yolo11s`, `yolo11m`); the single-class heads are
slightly smaller. Faster R-CNN rows: last COCO evaluation in `metrics.json`. The screenshot in
`faster_rcnn_r50/` shows another evaluation (AP 65.0) whose model and split were not recorded.

| Folder | Contents |
|---|---|
| `yolov5x/`, `yolov5_cbam_involution/` | `results.csv`, `opt.yaml`, `hyp.yaml`, training and PR/F1/confusion plots |
| `yolo11s_30ep/`, `yolo11s_200ep/`, `yolo11m_200ep/` | `results.csv` (+ plots, sample predictions for YOLO11m) |
| `faster_rcnn_r50/`, `faster_rcnn_x101/` | Detectron2 `metrics.json` |
