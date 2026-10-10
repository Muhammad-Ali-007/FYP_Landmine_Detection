# Errata for the 2025 thesis

The thesis PDF in this folder is the version submitted in 2025 and is kept unchanged. When the project was
revisited in 2026, its claims were checked against the original training logs (`results/legacy_2025/`).
This page lists every discrepancy found. The corrected, controlled experiments are described in the
main [README](../README.md) and in [`training/`](../training/).

## 1. The "CBAM-enhanced YOLOv5x" was not what was trained

| Thesis (§4.2.2, §5.5, §7.5) | What the 2025 notebook actually ran |
|---|---|
| YOLOv5x with a CBAM block after every C3 in backbone and neck | Config `yolo5m-cbam-involution.yaml` from a third-party fork (`aash1999/yolov5-cbam`): a YOLOv5m-style network with CBAM **and Involution** layers |
| ~86 M parameters (YOLOv5x) | **9.3 M** parameters, 30.6 GFLOPs |
| Fine-tuned from COCO `yolov5x.pt` | `--weights yolov5x.pt` was passed, but YOLOv5 only copies tensors whose name *and* shape match; with different layer widths (m vs x) and an extra layer type, essentially nothing could transfer, so the model was in effect trained from scratch |

The 2026 study (`training/`) implements the architecture the thesis describes and transfers the COCO
weights correctly, so CBAM can be compared fairly with plain YOLOv5x.

## 2. The headline numbers do not match any logged run

All 2025 numbers below are on the **validation** split (607 images); no 2025 run was evaluated on the test split.

| Model | P | R | mAP@0.5 | mAP@0.5:0.95 | Source |
|---|---|---|---|---|---|
| **Thesis claim (CBAM-YOLOv5x)** | 0.955 | 0.943 | 0.966 | **0.828** | §7.3 |
| YOLOv5x, plain | 0.957 | 0.950 | 0.963 | 0.803 | `legacy_2025/yolov5x` |
| YOLOv5 + CBAM + Involution | 0.929 | 0.900 | 0.944 | **0.668** | `legacy_2025/yolov5_cbam_involution` |
| YOLO11m | 0.947 | 0.948 | 0.978 | 0.818 | `legacy_2025/yolo11m_200ep` |

In 2025 the CBAM variant scored **lower** than plain YOLOv5x. Run `python results/legacy_2025/summarize.py`
to regenerate this table from the logs.

## 3. Baseline comparison (§7.5)

* Faster R-CNN: the thesis gives mAP@0.5:0.95 of 51.1 % (R50) and 63.8 % (X101). The logs show **61.3 %** (R50,
  10k iterations) and **61.4 %** (X101, 5k iterations). A screenshot of a third evaluation (65.0 %) exists, but
  which model and split it used was not recorded.
* RT-DETR (57.7 %), YOLO-NAS (P 55.6 %, R 98.0 %) and YOLOv5s (80.0 %) are cited without runs in the archive.
  They are described as "reported" and should not be read as results of this project.

## 4. The deployed model

The web app, the mobile backend and the "simulated UAV pipeline" use **YOLO11m** (`best.pt`, 40 MB), not
CBAM-YOLOv5x. The simulated UAV feed is the 153 test-split images played back as a 5 fps video.

## 5. Evaluation protocol

The dataset's random split places frames from the same recording sequences (the same mines on the same
ground, filmed at different times or altitudes) in train, validation and test. Exact duplicates are rare
(about 2 % of test images have a near-identical training image), but scores on such a split are optimistic
about performance on new terrain. Experiment E3 measures this with a scene-disjoint split.

## 6. Smaller inconsistencies in the text

| Where | Thesis says | Correct |
|---|---|---|
| §7.3 vs §7.5 vs §8 | precision 0.955 / 0.966 / 95.2 % | one value per model, from the logs (table above) |
| §7.3 | recall 0.943 and "94.1 %" in the same sentence | 0.950 (YOLOv5x val, best epoch) |
| §8 | "mAP@0.5 reached 96.6 % [or 0.972" | editing note left in |
| §4.1.5.1 vs §4.2.3.2 | image size 640 / 416 | 416 (`opt.yaml`) |
| §4.3.1 | 70 / 15 / 15 split | 2,132 / 607 / 303 images = 70 / 20 / 10 |
| §4.2.3 | YOLOv5 uses Adam by default | YOLOv5's default (and what was used) is SGD |
| §7.3 | background score 1.00 means perfect background classification | with one class, YOLOv5's normalised *background* column only holds false positives (background predicted as landmine), so it is always 1.00; it is not an accuracy |
| Abstract, §3 | reduce "false positives and true negatives" | false positives and **false negatives** |
