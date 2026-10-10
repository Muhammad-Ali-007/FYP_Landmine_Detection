# Landmine Detection in Thermal Imagery with Deep Learning

Detecting surface and shallowly buried landmines in drone-style thermal images, from a controlled study of
attention modules to a working prototype (Flask API, Android app and web dashboard).

*Final-year project, BS Computer Science, NUST Balochistan Campus (2025), revisited in 2026 to make the
evaluation rigorous and reproducible.*

> **Status (October 2026).** The controlled CBAM study (E1-E4 below) is running on Kaggle. Its results table
> will replace the "pending" section. The 2025 numbers are reported as logged; see [`docs/ERRATA.md`](docs/ERRATA.md)
> for how they differ from the thesis text.

## Research question
Thermal cameras can reveal landmines through the different rate at which a mine and the surrounding soil
heat up and cool down, but the signatures are small, low-contrast and vary with time of day. Attention
modules such as **CBAM** (channel + spatial attention) are often added to YOLO detectors to emphasise such
faint features. This project asks:

1. Does adding CBAM after every C3 block of YOLOv5 improve landmine detection **when everything else is held
   fixed** (same pretrained weights, data, recipe and seeds)? Does the answer depend on model size?
2. How much of the reported accuracy survives on **recording sequences the model has never seen**, rather
   than on frames from the same sequences, as in the dataset's default random split?

## Contributions
* **A controlled CBAM ablation** for YOLOv5s and YOLOv5x on MineGuard-Thermal, three seeds per model,
  reported on the held-out test split. The CBAM models start from the *same* COCO weights as their
  baselines; the weights are remapped to the new layer numbering, which naive implementations get wrong.
  The model-size overhead is +0.7 % parameters (x) and +1.4 % (s).
* **A scene-disjoint evaluation protocol** that holds out whole recording sequences, to measure how optimistic
  the random split is.
* **A comparison with other detectors**: YOLO11 and Faster R-CNN (R50 and X101 backbones).
* **An end-to-end prototype**: Flask inference API, Flutter Android app for drone controllers, Django web
  dashboard, and a CLI for annotating drone video.

## Results

### 2026 controlled study (test split, mean ± std over seeds): *pending*
| Exp. | Comparison | Split | Status |
|---|---|---|---|
| E1 | YOLOv5x vs YOLOv5x + CBAM, 3 seeds | original | running |
| E2 | YOLOv5s vs YOLOv5s + CBAM, 3 seeds | original | running |
| E3 | YOLOv5x, YOLOv5x + CBAM, YOLO11m | scene-disjoint | running |
| E4 | paired CBAM − baseline differences, latency | all | after E1-E3 |

### 2025 runs (validation split, as logged)
| Model | Params | P | R | mAP@0.5 | mAP@0.5:0.95 |
|---|---|---|---|---|---|
| YOLOv5x | 86.2M | 0.957 | 0.950 | 0.963 | 0.803 |
| YOLOv5 + CBAM + Involution (third-party config) | 9.3M | 0.929 | 0.900 | 0.944 | 0.668 |
| YOLO11s | ~9.4M | 0.956 | 0.942 | 0.975 | 0.803 |
| **YOLO11m** (used in the apps) | ~20.1M | 0.947 | 0.948 | **0.978** | **0.818** |
| Faster R-CNN R50-FPN | - | - | - | 0.952 | 0.613 |
| Faster R-CNN X101-FPN | - | - | - | 0.944 | 0.614 |

Rebuild this table from the raw logs with `python results/legacy_2025/summarize.py`. These runs were
selected and scored on the same validation split, and the random split shares recording sequences between
train and validation, so they are optimistic; the 2026 study addresses both issues.

## Repository layout
| Path | Contents |
|---|---|
| [`training/`](training/) | the controlled study: experiment code, Kaggle notebooks, 2025 notebooks for provenance |
| [`results/`](results/) | result tables and logs (`legacy_2025/` = original 2025 runs) |
| [`data/`](data/) | dataset source, licence and split definitions (images are downloaded, not stored) |
| [`backend/`](backend/) | Flask inference API used by the mobile app |
| [`mobile/`](mobile/) | Flutter Android app |
| [`demo/`](demo/) | `detect.py`: annotate a video, a camera stream or a folder of frames |
| [`docs/`](docs/) | thesis (2025) and [errata](docs/ERRATA.md) |

## Quick start
```bash
pip install ultralytics opencv-python
# weights: download yolo11m_landmine.pt from the GitHub release into weights/
python demo/detect.py --weights weights/yolo11m_landmine.pt --source path/to/thermal_video.mp4
python demo/detect.py --weights weights/yolo11m_landmine.pt --source path/to/frames/ --fps 5
```
* API and app: see [`backend/README.md`](backend/README.md) and [`mobile/README.md`](mobile/README.md).
* Reproducing the study: see [`training/README.md`](training/README.md).

## Data
[MineGuard-Thermal v15](https://universe.roboflow.com/dronecv/mineguard-thermal/dataset/15) (Roboflow, CC BY 4.0):
3,042 thermal frames, 5,929 annotated landmines, one class. Details in [`data/README.md`](data/README.md).

## Limitations
* One public dataset with ten recording sequences; no field validation on real minefields.
* Thermal contrast depends on weather, soil moisture, burial depth and time of day; the dataset covers only
  part of that range.
* The detector is an assistive tool for surveyors; it is not a clearance decision system.

## Team
Muhammad Ali (group lead), Muhammad, Hajra Mehmood, Abbas Ali. Supervisor: Dr. Adnan Idris,
Department of Computer Science, NUST Balochistan Campus. The Django web dashboard ("MineGuard") was built by a
team member and is described in the thesis; its code is not part of this repository.

## Licence
Code in this repository: MIT (see [`LICENSE`](LICENSE)). The training code patches and runs
[Ultralytics YOLOv5](https://github.com/ultralytics/yolov5) and uses the
[Ultralytics](https://github.com/ultralytics/ultralytics) package, both AGPL-3.0; follow their licence if
you distribute modified versions or models. Dataset: CC BY 4.0, by its authors.

## Citation
```bibtex
@thesis{ali2025landmine,
  title  = {Landmine Detection Using Deep Learning and Thermal Imagery},
  author = {Ali, Muhammad and Muhammad and Mehmood, Hajra and Ali, Abbas},
  school = {National University of Sciences and Technology (NUST), Balochistan Campus},
  type   = {Bachelor's thesis},
  year   = {2025}
}
```
