# Training: a controlled CBAM study

**Question.** Does adding CBAM attention after every C3 block of YOLOv5 improve landmine detection in
thermal imagery, when everything else is held fixed? And how much of the accuracy survives on recording
sequences the model has never seen?

| Exp. | Comparison | Split | Seeds |
|---|---|---|---|
| E1 | YOLOv5x vs YOLOv5x + CBAM | original Roboflow split | 0, 1, 2 |
| E2 | YOLOv5s vs YOLOv5s + CBAM | original Roboflow split | 0, 1, 2 |
| E3 | YOLOv5x, YOLOv5x + CBAM, YOLO11m (+ optional YOLOv5s pair) | scene-disjoint split | 0 (s pair: 0-2) |
| E4 | test-set metrics, mean ± std, paired CBAM − baseline differences, latency | all of the above | - |

## What makes the comparison fair
* **Same code** for every run: Ultralytics YOLOv5 pinned to commit `f957879`, Ultralytics `8.4.175`.
* **Same recipe** as the 2025 thesis runs: 200 epochs, 416 px, batch 16, SGD, default `hyp.scratch-low`, RAM cache.
* **Same starting point.** CBAM models start from the same COCO `yolov5{s,x}.pt` weights as their baselines.
  Inserting CBAM shifts layer indices, so the weights are remapped to the new numbering
  ([`setup_yolov5.py`](src/setup_yolov5.py)); YOLOv5's loader would otherwise silently skip most of them.
  Only the 24 CBAM tensors start from a (seed-dependent) random initialisation.
* **Deterministic training** (YOLOv5 enables `torch.use_deterministic_algorithms`). CBAM pools with
  `mean`/`amax` instead of adaptive pooling, which has no deterministic CUDA backward pass.
* **Model selection on validation, reporting on test.** `best.pt` is chosen on the validation split; all
  headline numbers are on the held-out test split.

| Model | Params (nc=1) | CBAM blocks |
|---|---|---|
| YOLOv5s | 7.02 M | 0 |
| YOLOv5s + CBAM | 7.12 M (+1.4 %) | 8 |
| YOLOv5x | 86.22 M | 0 |
| YOLOv5x + CBAM | 86.81 M (+0.7 %) | 8 |

## Scene-disjoint split (E3)
The dataset consists of ten recording sequences. The original split scatters frames of every sequence over
train, validation and test. The scene split holds whole sequences out:

| Split | Sequences | Images |
|---|---|---|
| test | `illia_4`, `MYKHAILO_4` | 371 |
| validation | `illia_3`, `MYKHAILO_3` | 480 |
| train | `illia_1`, `illia_2`, `MYKHAILO_1`, `MYKHAILO_2`, `DM-11`, `FlightAltitude` | 2,191 |

`FlightAltitude` (1,228 images over 99 altitude/temperature settings) cannot be divided into independent
sequences from its filenames, so it stays in training; E3 therefore measures generalisation to new
`illia`/`MYKHAILO` sequences. The full per-image assignment is written to `split_manifest.csv` by every run.

## Running it on Kaggle
1. Upload `MineGuard-Thermal.v15i.yolov8.zip` (Roboflow export, YOLO format) once as a private Kaggle dataset.
2. Import [`notebooks/01_train_kaggle.ipynb`](notebooks/01_train_kaggle.ipynb), attach the dataset, set
   *Accelerator* = **GPU T4 x2** and *Internet* = on.
3. Run it once with `SMOKE_TEST = True` (about 20 minutes), then commit sessions **A**, **B** and **C**
   (about 8.5 h each, under Kaggle's 12 h limit). Session **D** is optional.
4. Run [`notebooks/02_evaluate_kaggle.ipynb`](notebooks/02_evaluate_kaggle.ipynb) with the finished sessions
   attached as inputs. It writes the result tables, plots and latency numbers.

## Layout
| Path | Purpose |
|---|---|
| `src/` | experiment code: the single source of truth (splits, CBAM patch, scheduler, evaluation, aggregation) |
| `notebooks/` | self-contained Kaggle notebooks generated from `src/` by `tools/build_notebooks.py` |
| `legacy_2025/` | the original 2025 notebooks (outputs and API keys removed), for provenance |

After editing anything in `src/`, regenerate the notebooks with `python training/tools/build_notebooks.py`.
