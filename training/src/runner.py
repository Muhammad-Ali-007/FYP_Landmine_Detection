"""Run matrix and a small multi-GPU scheduler for the attention study.

Every run is (model, split, seed). Runs are queued and each GPU takes the next run that still fits in
the session's time budget, so one Kaggle "T4 x2" session trains two models side by side.
Each run writes to OUT/<model>__<split>__s<seed>/ : weights/best.pt, results.csv, plots, train.log,
metrics.json (val + test) and run.json (command, timing, status).
"""

import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from pathlib import Path

# est_h: rough hours per 200-epoch run on one T4 while a second run uses the other GPU.
MODELS = {
    "yolov5s":      {"kind": "yolov5", "variant": "s", "cbam": False, "est_h": 1.8},
    "yolov5s_cbam": {"kind": "yolov5", "variant": "s", "cbam": True,  "est_h": 2.0},
    "yolov5x":      {"kind": "yolov5", "variant": "x", "cbam": False, "est_h": 4.0},
    "yolov5x_cbam": {"kind": "yolov5", "variant": "x", "cbam": True,  "est_h": 4.5},
    "yolo11m":      {"kind": "ultralytics", "weights": "yolo11m.pt",   "est_h": 3.5},
}

# Sessions sized for one Kaggle "GPU T4 x2" session (12 h hard limit).
SESSIONS = {
    # E1: YOLOv5x vs YOLOv5x+CBAM on the original split, seeds 0 and 1           (~8.5 h)
    "A": [("yolov5x", "random", 0), ("yolov5x_cbam", "random", 0),
          ("yolov5x", "random", 1), ("yolov5x_cbam", "random", 1)],
    # E1 seed 2 + E2: YOLOv5s vs YOLOv5s+CBAM, seeds 0 and 1                      (~8.5 h)
    "B": [("yolov5x", "random", 2), ("yolov5x_cbam", "random", 2),
          ("yolov5s", "random", 0), ("yolov5s_cbam", "random", 0),
          ("yolov5s", "random", 1), ("yolov5s_cbam", "random", 1)],
    # E3: scene-disjoint split + E2 seed 2                                         (~8.5 h)
    "C": [("yolov5x", "scene", 0), ("yolov5x_cbam", "scene", 0), ("yolo11m", "scene", 0),
          ("yolov5s", "random", 2), ("yolov5s_cbam", "random", 2)],
    # Optional: E3 with the small models over 3 seeds                             (~6 h)
    "D": [(m, "scene", s) for s in (0, 1, 2) for m in ("yolov5s", "yolov5s_cbam")],
}


@dataclass
class Run:
    model: str
    split: str
    seed: int

    @property
    def name(self):
        return f"{self.model}__{self.split}__s{self.seed}"


def build_command(run, cfg, data_yaml, run_dir, device):
    """Return (argv, cwd) for one training run."""
    m = MODELS[run.model]
    if m["kind"] == "ultralytics":
        argv = [sys.executable, str(Path(cfg["src_dir"], "train_ultralytics.py")), "--model", m["weights"],
                "--data", str(data_yaml), "--project", str(run_dir.parent), "--name", run_dir.name,
                "--seed", str(run.seed), "--epochs", str(cfg["epochs"]), "--imgsz", str(cfg["imgsz"]),
                "--batch", str(cfg["batch"]), "--workers", str(cfg["workers"]), "--device", device]
        return argv, cfg["work_dir"]
    v = m["variant"]
    if m["cbam"]:
        model_cfg = Path(cfg["gen_dir"], f"yolov5{v}_cbam.yaml")
        weights = Path(cfg["gen_dir"], f"yolov5{v}_cbam_init_s{run.seed}.pt")
    else:
        model_cfg = Path("models", f"yolov5{v}.yaml")
        weights = f"yolov5{v}.pt"
    argv = [sys.executable, "train.py", "--img", str(cfg["imgsz"]), "--batch", str(cfg["batch"]),
            "--epochs", str(cfg["epochs"]), "--data", str(data_yaml), "--cfg", str(model_cfg),
            "--weights", str(weights), "--seed", str(run.seed), "--cache", "ram", "--workers", str(cfg["workers"]),
            "--patience", "100", "--device", device, "--project", str(run_dir.parent), "--name", run_dir.name,
            "--exist-ok"]
    return argv, cfg["yolo_dir"]


def _env_for(gpu):
    env = dict(os.environ)
    env["PYTHONUNBUFFERED"] = "1"
    env.setdefault("TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD", "1")
    if gpu != "cpu":
        env["CUDA_VISIBLE_DEVICES"] = str(gpu)
    return env


def execute(run, cfg, data_yaml, gpu):
    """Train + evaluate one run; never raises (failures are recorded in run.json)."""
    run_dir = Path(cfg["out_dir"], run.name)
    run_dir.mkdir(parents=True, exist_ok=True)
    device = "cpu" if gpu == "cpu" else "0"
    meta = {"run": run.name, "model": run.model, "split": run.split, "seed": run.seed, "gpu": gpu,
            "epochs": cfg["epochs"], "imgsz": cfg["imgsz"], "batch": cfg["batch"], "data": str(data_yaml),
            "status": "running", "started": time.strftime("%Y-%m-%d %H:%M:%S")}
    t0 = time.time()
    argv, cwd = build_command(run, cfg, data_yaml, run_dir, device)
    meta["command"] = " ".join(argv)
    (run_dir / "run.json").write_text(json.dumps(meta, indent=2))
    log_path = run_dir / "train.log"
    try:
        with open(log_path, "w", encoding="utf-8") as log:
            rc = subprocess.run(argv, cwd=cwd, env=_env_for(gpu), stdout=log, stderr=subprocess.STDOUT).returncode
        if rc != 0:
            raise RuntimeError(f"training exited with code {rc}")
        meta["train_hours"] = round((time.time() - t0) / 3600, 3)
        log_text = log_path.read_text(encoding="utf-8", errors="replace")
        hit = re.findall(r"Transferred (\d+)/(\d+) items", log_text)
        if hit:
            meta["transferred_items"] = f"{hit[-1][0]}/{hit[-1][1]}"
        if MODELS[run.model]["kind"] == "yolov5":
            best = run_dir / "weights" / "best.pt"
            eval_argv = [sys.executable, str(Path(cfg["src_dir"], "eval_yolov5.py")), "--yolo-dir", cfg["yolo_dir"],
                         "--weights", str(best), "--data", str(data_yaml), "--out", str(run_dir),
                         "--imgsz", str(cfg["imgsz"]), "--workers", str(cfg["workers"])]
            with open(run_dir / "eval.log", "w", encoding="utf-8") as log:
                rc = subprocess.run(eval_argv, cwd=cfg["yolo_dir"], env=_env_for(gpu), stdout=log,
                                    stderr=subprocess.STDOUT).returncode
            if rc != 0:
                raise RuntimeError(f"evaluation exited with code {rc}")
        last = run_dir / "weights" / "last.pt"
        if last.exists():
            last.unlink()  # best.pt is all we need; keeps the Kaggle output small
        meta["status"] = "done"
        meta["test"] = json.loads((run_dir / "metrics.json").read_text())["test"]
    except Exception as e:  # keep the session going; the log has the details
        meta["status"] = "failed"
        meta["error"] = str(e)
        tail = log_path.read_text(encoding="utf-8", errors="replace").splitlines()[-25:] if log_path.exists() else []
        print(f"\n!!! {run.name} FAILED: {e}\n" + "\n".join(tail))
    meta["total_hours"] = round((time.time() - t0) / 3600, 3)
    (run_dir / "run.json").write_text(json.dumps(meta, indent=2))
    return meta


def _progress(run_dir):
    for csv_path in (run_dir / "results.csv",):
        if csv_path.exists():
            lines = [ln for ln in csv_path.read_text().splitlines() if ln.strip()]
            if len(lines) > 1:
                head = [h.strip() for h in lines[0].split(",")]
                last = [x.strip() for x in lines[-1].split(",")]
                key = next((k for k in head if "mAP_0.5:0.95" in k or "mAP50-95" in k), None)
                score = f"{float(last[head.index(key)]):.3f}" if key else "?"
                return f"epoch {len(lines) - 1}, val mAP50-95 {score}"
    return "starting"


def run_session(runs, cfg, data_yamls, gpus, budget_h, poll_s=600):
    """Run ``runs`` across ``gpus``; a GPU only starts a run if its estimate fits in the remaining budget."""
    queue = [Run(*r) for r in runs]
    lock = threading.Lock()
    active, results = {}, {}
    t0 = time.time()

    def worker(gpu):
        while True:
            with lock:
                elapsed = (time.time() - t0) / 3600
                pick = next((r for r in queue if elapsed + MODELS[r.model]["est_h"] <= budget_h), None)
                if pick is None:
                    return
                queue.remove(pick)
                active[gpu] = pick
            print(f"[{time.strftime('%H:%M')}] GPU {gpu}: start {pick.name}")
            results[pick.name] = execute(pick, cfg, data_yamls[pick.split], gpu)
            r = results[pick.name]
            print(f"[{time.strftime('%H:%M')}] GPU {gpu}: {pick.name} {r['status']} "
                  f"in {r['total_hours']:.2f} h" + (f" | test mAP50-95 {r['test']['map50_95']:.4f}"
                                                    if r["status"] == "done" else ""))
            with lock:
                active.pop(gpu, None)

    threads = [threading.Thread(target=worker, args=(g,), daemon=True) for g in gpus]
    for t in threads:
        t.start()
    while any(t.is_alive() for t in threads):
        for t in threads:
            t.join(timeout=poll_s / max(len(threads), 1))
        with lock:
            status = {g: f"{r.name}: {_progress(Path(cfg['out_dir'], r.name))}" for g, r in active.items()}
        if status:
            print(f"[{time.strftime('%H:%M')}] elapsed {(time.time() - t0) / 3600:.2f} h | "
                  + " | ".join(f"GPU {g} {s}" for g, s in status.items()))

    skipped = [r.name for r in queue]
    summary = {"runs": results, "skipped_for_time": skipped, "hours": round((time.time() - t0) / 3600, 2)}
    Path(cfg["out_dir"], "session_summary.json").write_text(json.dumps(summary, indent=2))
    return summary


def print_summary(summary):
    print(f"\n{'run':34s}{'status':>8s}{'hours':>7s}{'P':>8s}{'R':>8s}{'mAP50':>8s}{'mAP50-95':>10s}")
    for name, r in summary["runs"].items():
        t = r.get("test", {})
        print(f"{name:34s}{r['status']:>8s}{r['total_hours']:>7.2f}" + (
            f"{t['precision']:>8.3f}{t['recall']:>8.3f}{t['map50']:>8.3f}{t['map50_95']:>10.3f}" if t else ""))
    if summary["skipped_for_time"]:
        print("\nNot started (would not fit in the time budget) - run them in a later session with CUSTOM_RUNS:")
        for n in summary["skipped_for_time"]:
            print("  ", n)


def copy_split_manifest(src, out_dir):
    if src and Path(src).exists():
        shutil.copy2(src, Path(out_dir, Path(src).name))
