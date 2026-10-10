"""Generate the self-contained Kaggle notebooks from training/src/*.py.

The .py files are the single source of truth; each notebook embeds them with %%writefile so it runs on
Kaggle without cloning this repository. Re-run after editing anything in training/src:
    python training/tools/build_notebooks.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
NB_DIR = ROOT / "notebooks"


def md(text):
    return {"cell_type": "markdown", "metadata": {}, "source": text.strip("\n").splitlines(keepends=True)}


def code(text, hidden=False):
    meta = {"jupyter": {"source_hidden": True}} if hidden else {}
    return {"cell_type": "code", "metadata": meta, "execution_count": None, "outputs": [],
            "source": text.strip("\n").splitlines(keepends=True)}


def embed(name):
    body = (SRC / name).read_text(encoding="utf-8")
    return code(f"%%writefile /tmp/lm/src/{name}\n{body}", hidden=True)


def notebook(cells):
    return {"cells": cells, "nbformat": 4, "nbformat_minor": 5,
            "metadata": {"kernelspec": {"name": "python3", "display_name": "Python 3", "language": "python"},
                         "language_info": {"name": "python"},
                         "kaggle": {"accelerator": "nvidiaTeslaT4", "isInternetEnabled": True}}}


SETUP = '''
import os, sys, json, platform, subprocess, time
import torch

os.makedirs(SRC_DIR, exist_ok=True)
os.makedirs(OUT_DIR, exist_ok=True)
os.environ["TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD"] = "1"  # YOLOv5/Ultralytics checkpoints are full pickles


def sh(cmd, cwd=None):
    print("$", cmd)
    subprocess.run(cmd, shell=True, check=True, cwd=cwd)


if not os.path.isdir(YOLO_DIR):
    sh(f"git clone -q https://github.com/ultralytics/yolov5 {YOLO_DIR}")
sh(f"git checkout -q {YOLOV5_COMMIT}", cwd=YOLO_DIR)
sh("pip install -q -r requirements.txt", cwd=YOLO_DIR)
sh(f"pip install -q ultralytics=={ULTRALYTICS_VERSION}")

GPUS = list(range(torch.cuda.device_count())) or ["cpu"]
print("GPUs:", [torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())] or "none (CPU only!)")
if GPUS == ["cpu"] and not SMOKE_TEST:
    raise SystemExit("No GPU found: set Accelerator to 'GPU T4 x2' in the notebook settings.")
'''

TRAIN_CONFIG = '''
# ============================ CONFIGURATION - edit this cell only ============================
SESSION = "A"        # "A", "B", "C" (required), "D" (optional) or "CUSTOM" - see the table above
CUSTOM_RUNS = []     # used when SESSION = "CUSTOM", e.g. [("yolov5x_cbam", "random", 2), ("yolov5s", "scene", 1)]
SMOKE_TEST = True    # True: 2 epochs on tiny subsets of every split (~15-20 min) to check the pipeline first

EPOCHS, IMGSZ, BATCH = 200, 416, 16   # identical to the 2025 thesis runs
TIME_BUDGET_H = 11.0                  # Kaggle kills sessions at 12 h; runs that would not finish are skipped

YOLOV5_COMMIT = "f9578796b8a64889aa9e66dc06914d19f40d338e"   # ultralytics/yolov5 master, pinned for all runs
ULTRALYTICS_VERSION = "8.4.175"
WORK_DIR = "/tmp/lm"                                          # code, YOLOv5 checkout, split links (not saved)
OUT_DIR = "/kaggle/working/" + ("smoke_outputs" if SMOKE_TEST else f"outputs_session_{SESSION}")
# ==============================================================================================
SRC_DIR, YOLO_DIR, GEN_DIR = f"{WORK_DIR}/src", f"{WORK_DIR}/yolov5", f"{WORK_DIR}/gen"
'''

TRAIN_INTRO = '''
# Landmine detection: does CBAM attention help? (training notebook)

This notebook trains the models for the controlled CBAM study on **MineGuard-Thermal v15**:

| Exp. | Question | Runs |
|---|---|---|
| **E1** | Does CBAM help YOLOv5x when both start from the *same* COCO weights? | YOLOv5x vs YOLOv5x+CBAM, original split, seeds 0-2 |
| **E2** | Does it help a small model more? | YOLOv5s vs YOLOv5s+CBAM, original split, seeds 0-2 |
| **E3** | How much do scores drop on *unseen recording sequences*? | YOLOv5x, YOLOv5x+CBAM, YOLO11m on the scene-disjoint split |

E4 (latency + aggregated tables) is in `02_evaluate_kaggle.ipynb`.

**Sessions** (each fits one Kaggle *GPU T4 x2* session; two runs train side by side):

| Session | Runs | Approx. time |
|---|---|---|
| A | YOLOv5x, YOLOv5x+CBAM on the original split, seeds 0 and 1 | ~8.5 h |
| B | YOLOv5x, YOLOv5x+CBAM seed 2; YOLOv5s, YOLOv5s+CBAM seeds 0 and 1 | ~8.5 h |
| C | Scene split: YOLOv5x, YOLOv5x+CBAM, YOLO11m; YOLOv5s, YOLOv5s+CBAM seed 2 | ~8.5 h |
| D (optional) | Scene split: YOLOv5s, YOLOv5s+CBAM, seeds 0-2 | ~6 h |

### How to run on Kaggle
1. **Settings:** *Accelerator* = **GPU T4 x2**, *Internet* = **on**.
2. **Data:** *Add Input* → your private dataset containing the MineGuard-Thermal v15 YOLO export
   (upload `MineGuard-Thermal.v15i.yolov8.zip` once as a Kaggle dataset). Alternative: add a Kaggle
   *Secret* named `ROBOFLOW_API_KEY` and the notebook downloads it from Roboflow.
3. **Smoke test first:** keep `SMOKE_TEST = True` and click *Run All* (about 15-20 min). The last cell
   must show every run as `done`.
4. **Real run:** set `SMOKE_TEST = False` and `SESSION = "A"`, then *Save Version* → **Save & Run All (Commit)**.
   It keeps running after you close the browser.
5. When the version finishes: open it → *Output* → download `outputs_session_A` (or attach the version as
   an input to the evaluation notebook). Then repeat with sessions B and C.

What is fair about the comparison: same pinned YOLOv5 code, same data, hyper-parameters, image size,
epochs and seeds; the CBAM models start from the **same COCO weights** as their baselines (remapped to the
new layer numbering), so the only difference is the 8 CBAM blocks.
'''

TRAIN_RUNS = '''
sys.path.insert(0, SRC_DIR)
import runner, splits

RUNS = runner.SESSIONS[SESSION] if SESSION != "CUSTOM" else CUSTOM_RUNS
if SMOKE_TEST:  # every model once on the original split + one scene-split run, 2 epochs each
    RUNS = [(m, "random", 0) for m in runner.MODELS] + [("yolov5s_cbam", "scene", 0)]
    EPOCHS, TIME_BUDGET_H = 2, 99
print(f"{len(RUNS)} runs:", *RUNS, sep="\\n  ")

# ---- data -------------------------------------------------------------------------------------
src = splits.find_dataset(["/kaggle/input"])
if src is None:
    from kaggle_secrets import UserSecretsClient
    sh("pip install -q roboflow")
    src = splits.download_roboflow(f"{WORK_DIR}/roboflow", UserSecretsClient().get_secret("ROBOFLOW_API_KEY"))
print("dataset:", src)
yamls = splits.build_splits(src, f"{WORK_DIR}/data", smoke=SMOKE_TEST, manifest_path=f"{OUT_DIR}/split_manifest.csv")
DATA_YAMLS = {k.replace("_smoke", ""): v for k, v in yamls.items()}
'''

TRAIN_MODELS = '''
# ---- CBAM patch, CBAM configs, COCO-initialised CBAM checkpoints, model sizes ----------------
v5 = [runner.MODELS[m] for m, _, _ in RUNS if runner.MODELS[m]["kind"] == "yolov5"]
variants = sorted({m["variant"] for m in v5}) or ["s"]
seeds = sorted({s for _, _, s in RUNS})
sh(f"{sys.executable} {SRC_DIR}/setup_yolov5.py all --yolo-dir {YOLO_DIR} --gen-dir {GEN_DIR} "
   f"--variants {' '.join(variants)} --seeds {' '.join(map(str, seeds))} --imgsz {IMGSZ}")
'''

TRAIN_GO = '''
# ---- train + evaluate -----------------------------------------------------------------------
import ultralytics
env = {"python": platform.python_version(), "torch": torch.__version__, "cuda": torch.version.cuda,
       "gpus": [torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())],
       "yolov5_commit": YOLOV5_COMMIT, "ultralytics": ultralytics.__version__, "session": SESSION,
       "smoke_test": SMOKE_TEST, "epochs": EPOCHS, "imgsz": IMGSZ, "batch": BATCH, "runs": RUNS,
       "started": time.strftime("%Y-%m-%d %H:%M:%S")}
json.dump(env, open(f"{OUT_DIR}/env.json", "w"), indent=2)
for f in ("model_info.json", "yolov5s_cbam.yaml", "yolov5x_cbam.yaml"):
    if os.path.exists(f"{GEN_DIR}/{f}"):
        sh(f"cp {GEN_DIR}/{f} {OUT_DIR}/")

cfg = {"work_dir": WORK_DIR, "yolo_dir": YOLO_DIR, "gen_dir": GEN_DIR, "src_dir": SRC_DIR, "out_dir": OUT_DIR,
       "epochs": EPOCHS, "imgsz": IMGSZ, "batch": BATCH, "workers": 2 if len(GPUS) > 1 else 4}
summary = runner.run_session(RUNS, cfg, DATA_YAMLS, GPUS, TIME_BUDGET_H, poll_s=120 if SMOKE_TEST else 900)
runner.print_summary(summary)
'''

TRAIN_OUTRO = '''
### After the session
* Every run folder in the output has `weights/best.pt`, `results.csv`, training plots, `train.log`,
  `metrics.json` (val + **test** metrics, params, GFLOPs) and `run.json` (command, timing, status).
* `session_summary.json` lists finished, failed and skipped runs. Re-run anything skipped or failed in a
  later session with `SESSION = "CUSTOM"`.
* For the CBAM runs, `run.json` → `transferred_items` should be **larger** than for the matching baseline
  (the extra items are the CBAM blocks); if it is much smaller, the COCO weights were not transferred.
'''

EVAL_INTRO = '''
# Landmine detection: CBAM study, evaluation notebook (E4)

1. **Inputs** (*Add Input* → *Your Work*): the finished versions of `01_train_kaggle` (sessions A, B, C, ...).
   Optionally also a dataset containing the 2025 **YOLO11m** `best.pt` (set `LEGACY_YOLO11M` below); in that
   case attach the MineGuard-Thermal dataset too, because those weights are evaluated on its test split.
2. **Settings:** Accelerator **GPU T4** (one is enough), Internet **on**. Click *Run All*.
3. Outputs: `results/summary.md` (mean ± std over seeds, **test** split), `cbam_vs_baseline.csv` (paired
   per-seed differences), `runs.csv`, `latency.json`, plus plots. Download `results/` and send it back.
'''

EVAL_CONFIG = '''
# ============================ CONFIGURATION ============================
INPUT_ROOTS = ["/kaggle/input"]            # where the training outputs are attached
LEGACY_YOLO11M = None                      # e.g. "/kaggle/input/fyp-weights/best.pt" (2025 YOLO11m, original split)
IMGSZ = 416
YOLOV5_COMMIT = "f9578796b8a64889aa9e66dc06914d19f40d338e"
ULTRALYTICS_VERSION = "8.4.175"
SMOKE_TEST = False
WORK_DIR, OUT_DIR = "/tmp/lm", "/kaggle/working/results"
# =======================================================================
SRC_DIR, YOLO_DIR, GEN_DIR = f"{WORK_DIR}/src", f"{WORK_DIR}/yolov5", f"{WORK_DIR}/gen"
'''

EVAL_AGG = '''
sys.path.insert(0, SRC_DIR)
sh(f"{sys.executable} {SRC_DIR}/setup_yolov5.py patch --yolo-dir {YOLO_DIR} --gen-dir {GEN_DIR}")  # to load CBAM models
import aggregate
res = aggregate.main(INPUT_ROOTS, OUT_DIR)
if res is None:
    raise SystemExit("No finished runs found: attach the training notebook versions as inputs.")
df, summary, deltas = res
'''

EVAL_LEGACY = '''
# ---- 2025 YOLO11m weights on the original test split (optional) ------------------------------
import splits
if LEGACY_YOLO11M:
    from ultralytics import YOLO
    ck = torch.load(LEGACY_YOLO11M, map_location="cpu", weights_only=False)
    legacy_imgsz = (ck.get("train_args") or {}).get("imgsz", 640)
    print("legacy YOLO11m was trained at imgsz", legacy_imgsz)
    src = splits.find_dataset(["/kaggle/input"])
    yamls = splits.build_splits(src, f"{WORK_DIR}/data")
    legacy = {}
    for split in ("val", "test"):
        r = YOLO(LEGACY_YOLO11M).val(data=str(yamls["random"]), split=split, imgsz=legacy_imgsz, batch=32,
                                     project=f"{OUT_DIR}/legacy_yolo11m", name=split, exist_ok=True)
        legacy[split] = {"precision": float(r.box.mp), "recall": float(r.box.mr), "map50": float(r.box.map50),
                         "map50_95": float(r.box.map)}
    legacy["imgsz"] = legacy_imgsz
    json.dump(legacy, open(f"{OUT_DIR}/legacy_yolo11m.json", "w"), indent=2)
    print(json.dumps(legacy, indent=2))
'''

EVAL_LATENCY = '''
# ---- latency: one checkpoint per architecture (seed 0 if available) ---------------------------
from pathlib import Path
picked = {}
for _, r in df.sort_values("seed").iterrows():
    if r["model"] not in picked:
        hits = list(Path("/kaggle/input").rglob(f"{r['run']}/weights/best.pt"))
        if hits:
            picked[r["model"]] = str(hits[0])
if LEGACY_YOLO11M:
    picked["yolo11m_legacy"] = LEGACY_YOLO11M
print(picked)
if picked:
    sh(f"{sys.executable} {SRC_DIR}/benchmark.py --yolo-dir {YOLO_DIR} --imgsz {IMGSZ} --out {OUT_DIR}/latency.json "
       f"--weights {' '.join(picked.values())} --names {' '.join(picked)}")
'''

EVAL_PLOTS = '''
# ---- plots -----------------------------------------------------------------------------------
import matplotlib.pyplot as plt
for split, grp in df.groupby("split"):
    order = [m for m in ("yolov5s", "yolov5s_cbam", "yolov5x", "yolov5x_cbam", "yolo11m") if m in set(grp["model"])]
    fig, ax = plt.subplots(figsize=(7, 4))
    for i, m in enumerate(order):
        v = grp[grp["model"] == m]["test_map50_95"]
        ax.bar(i, v.mean(), yerr=v.std() if len(v) > 1 else None, capsize=4, color="#9ab" if "cbam" not in m else "#e96")
        ax.scatter([i] * len(v), v, color="k", s=12, zorder=3)
    ax.set_xticks(range(len(order)), order, rotation=20)
    ax.set_ylabel("test mAP@0.5:0.95")
    ax.set_title(f"{split} split (bars: mean, dots: seeds)")
    lo = grp["test_map50_95"].min()
    ax.set_ylim(max(0, lo - 0.08), min(1, grp["test_map50_95"].max() + 0.04))
    fig.tight_layout()
    fig.savefig(f"{OUT_DIR}/map50_95_{split}.png", dpi=150)
    plt.show()
'''


def main():
    NB_DIR.mkdir(parents=True, exist_ok=True)
    srcs = ["splits.py", "setup_yolov5.py", "runner.py", "eval_yolov5.py", "train_ultralytics.py"]
    train = notebook([md(TRAIN_INTRO), code(TRAIN_CONFIG), md("### Setup (no need to edit below)"), code(SETUP)]
                     + [md("Experiment code (from `training/src` in the GitHub repo):")]
                     + [embed(s) for s in srcs]
                     + [code(TRAIN_RUNS), code(TRAIN_MODELS), code(TRAIN_GO), md(TRAIN_OUTRO)])
    evaluate = notebook([md(EVAL_INTRO), code(EVAL_CONFIG), code(SETUP)]
                        + [embed(s) for s in ("splits.py", "setup_yolov5.py", "aggregate.py", "benchmark.py")]
                        + [code(EVAL_AGG), code(EVAL_LEGACY), code(EVAL_LATENCY), code(EVAL_PLOTS)])
    for name, nb in (("01_train_kaggle.ipynb", train), ("02_evaluate_kaggle.ipynb", evaluate)):
        (NB_DIR / name).write_text(json.dumps(nb, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
        print("wrote", NB_DIR / name)


if __name__ == "__main__":
    main()
