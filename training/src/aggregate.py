"""Collect run outputs (run.json + metrics.json) and build the result tables for the README/report.

Works on Kaggle (inputs = the training notebook versions) and locally on the downloaded outputs:
    python aggregate.py <dir-with-run-folders> [...] --out results/
"""

import argparse
import json
from pathlib import Path

import pandas as pd

METRICS = ["precision", "recall", "f1", "map50", "map50_95"]


def collect(roots, min_epochs=100):
    rows, seen = [], set()
    for root in roots:
        for run_json in sorted(Path(root).rglob("run.json")):
            run = json.loads(run_json.read_text())
            metrics_path = run_json.parent / "metrics.json"
            if run.get("status") != "done" or not metrics_path.exists() or run["run"] in seen:
                continue
            if run.get("epochs", 0) < min_epochs:  # smoke-test runs
                print(f"skipping {run_json.parent} ({run.get('epochs')} epochs)")
                continue
            seen.add(run["run"])
            m = json.loads(metrics_path.read_text())
            row = {"run": run["run"], "model": run["model"], "split": run["split"], "seed": run["seed"],
                   "params_M": m["params"] / 1e6, "gflops": m["gflops"], "train_hours": run.get("train_hours"),
                   "transferred": run.get("transferred_items")}
            for part in ("val", "test"):
                for k in METRICS:
                    row[f"{part}_{k}"] = m[part][k]
            rows.append(row)
    return pd.DataFrame(rows)


def summarise(df):
    """Mean and sample std over seeds for every (model, split)."""
    cols = [f"test_{k}" for k in METRICS] + [f"val_{k}" for k in METRICS]
    g = df.groupby(["split", "model"])
    out = g[cols].agg(["mean", "std"])
    out.columns = [f"{a}_{b}" for a, b in out.columns]
    out["n_seeds"] = g.size()
    out["params_M"] = g["params_M"].first()
    out["gflops"] = g["gflops"].first()
    return out.reset_index()


def paired_deltas(df):
    """CBAM minus baseline for the same (variant, split, seed) - the core ablation."""
    rows = []
    for (split, seed), grp in df.groupby(["split", "seed"]):
        by_model = grp.set_index("model")
        for base in ("yolov5s", "yolov5x"):
            cbam = f"{base}_cbam"
            if base in by_model.index and cbam in by_model.index:
                r = {"split": split, "seed": seed, "pair": f"{cbam} - {base}"}
                for k in METRICS:
                    r[f"d_test_{k}"] = by_model.loc[cbam, f"test_{k}"] - by_model.loc[base, f"test_{k}"]
                rows.append(r)
    return pd.DataFrame(rows)


def markdown_table(summary):
    lines = ["| Split | Model | Seeds | Params (M) | GFLOPs | P | R | mAP@0.5 | mAP@0.5:0.95 |",
             "|---|---|---|---|---|---|---|---|---|"]
    for _, r in summary.sort_values(["split", "model"]).iterrows():
        def f(k):
            s = r[f"test_{k}_std"]
            return f"{r[f'test_{k}_mean']:.3f}" + ("" if pd.isna(s) else f" ± {s:.3f}")
        lines.append(f"| {r['split']} | {r['model']} | {int(r['n_seeds'])} | {r['params_M']:.1f} | {r['gflops']:.1f} | "
                     f"{f('precision')} | {f('recall')} | {f('map50')} | {f('map50_95')} |")
    return "\n".join(lines)


def main(roots, out_dir, min_epochs=100):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    df = collect(roots, min_epochs)
    if df.empty:
        print("no finished runs found under", roots)
        return None
    df.sort_values(["split", "model", "seed"]).to_csv(out_dir / "runs.csv", index=False)
    summary = summarise(df)
    summary.to_csv(out_dir / "summary.csv", index=False)
    deltas = paired_deltas(df)
    deltas.to_csv(out_dir / "cbam_vs_baseline.csv", index=False)
    md = markdown_table(summary)
    (out_dir / "summary.md").write_text(md + "\n", encoding="utf-8")
    print(md)
    if not deltas.empty:
        print("\nCBAM minus baseline (test set), per seed:")
        print(deltas.to_string(index=False, float_format=lambda x: f"{x:+.4f}"))
        agg = deltas.groupby(["split", "pair"])[[f"d_test_{k}" for k in METRICS]].agg(["mean", "std"])
        print("\nmean ± std of the difference:")
        print(agg.to_string(float_format=lambda x: f"{x:+.4f}"))
    return df, summary, deltas


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("roots", nargs="+")
    ap.add_argument("--out", default="results")
    ap.add_argument("--min-epochs", type=int, default=100, help="ignore shorter (smoke-test) runs")
    a = ap.parse_args()
    main(a.roots, a.out, a.min_epochs)
