"""Dataset discovery and split construction for MineGuard-Thermal v15 (YOLO format).

Three splits are built from the same 3,042 images:

* ``random`` - the original Roboflow train/valid/test split used in the thesis.
* ``scene``  - whole recording sequences are held out, so no test sequence is seen in training.
* ``*_smoke`` - tiny subsets of the above, used to check the pipeline end to end in minutes.

Split folders contain links to the original files, so building them is cheap.
"""

import csv
import os
import random
import re
import shutil
from collections import Counter, defaultdict
from pathlib import Path

EXPECTED_COUNTS = {"train": 2132, "valid": 607, "test": 303}
IMG_EXTS = {".jpg", ".jpeg", ".png"}
SPLITS = ("train", "valid", "test")

# Scene-disjoint split (experiment E3): these sequences are held out entirely.
# Every other sequence (illia_1/2, MYKHAILO_1/2, DM-11, FlightAltitude) goes to train.
SCENE_HOLDOUT = {
    "test": ("illia_4", "MYKHAILO_4"),
    "valid": ("illia_3", "MYKHAILO_3"),
}


def sequence_of(filename):
    """Map a Roboflow filename to the recording sequence it came from (None if unknown)."""
    stem = filename.split(".rf.")[0]
    if stem.startswith("FlightAltitude"):
        return "FlightAltitude"
    m = re.match(r"(MYKHAILO_\d+|illia_\d+|DM-11)_", stem)
    return m.group(1) if m else None


def find_dataset(search_roots):
    """Return the first directory under ``search_roots`` that holds a YOLO export with train/valid/test."""
    for root in search_roots:
        if not Path(root).exists():
            continue
        for dirpath, dirnames, _ in os.walk(root):
            if set(SPLITS) <= set(dirnames) and Path(dirpath, "train", "images").is_dir():
                return Path(dirpath)
    return None


def download_roboflow(dest, api_key):
    """Fallback when the dataset is not attached as a Kaggle input."""
    from roboflow import Roboflow

    project = Roboflow(api_key=api_key).workspace("dronecv").project("mineguard-thermal")
    ds = project.version(15).download("yolov5", location=str(dest), overwrite=False)
    return Path(ds.location)


def collect_items(src_root):
    """List (original_split, image_path, label_path_or_None, n_boxes) for every image."""
    items = []
    for sp in SPLITS:
        for img in sorted((src_root / sp / "images").iterdir()):
            if img.suffix.lower() not in IMG_EXTS:
                continue
            lab = src_root / sp / "labels" / (img.stem + ".txt")
            n = sum(1 for line in lab.read_text().splitlines() if line.strip()) if lab.exists() else 0
            items.append((sp, img, lab if lab.exists() else None, n))
    return items


def _link(src, dst):
    """Symlink if possible (Kaggle/Linux), otherwise copy (e.g. Windows without dev mode)."""
    if dst.exists():
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.symlink(src, dst)
    except OSError:
        shutil.copy2(src, dst)


def _write_split(assignment, out_dir):
    """Materialise {split: [items]} under ``out_dir`` and write a data.yaml for YOLOv5/Ultralytics."""
    if out_dir.exists():
        shutil.rmtree(out_dir)
    for sp in SPLITS:
        (out_dir / sp / "images").mkdir(parents=True, exist_ok=True)
        (out_dir / sp / "labels").mkdir(parents=True, exist_ok=True)
        for _, img, lab, _ in assignment[sp]:
            _link(img, out_dir / sp / "images" / img.name)
            if lab is not None:
                _link(lab, out_dir / sp / "labels" / lab.name)
    yaml_path = out_dir / "data.yaml"
    yaml_path.write_text(
        f"path: {out_dir.as_posix()}\n"
        "train: train/images\nval: valid/images\ntest: test/images\n"
        "nc: 1\nnames: ['landmine']\n"
    )
    return yaml_path


def _summarise(name, assignment):
    print(f"\n[{name}] images / boxes per split and sequence")
    seqs = sorted({sequence_of(i[1].name) or "?" for sp in SPLITS for i in assignment[sp]})
    print(f"  {'sequence':16s}" + "".join(f"{sp:>16s}" for sp in SPLITS))
    for seq in seqs:
        row = ""
        for sp in SPLITS:
            sel = [i for i in assignment[sp] if (sequence_of(i[1].name) or "?") == seq]
            row += f"{len(sel):>9d} / {sum(i[3] for i in sel):<5d}"
        print(f"  {seq:16s}{row}")
    print(f"  {'TOTAL':16s}" + "".join(
        f"{len(assignment[sp]):>9d} / {sum(i[3] for i in assignment[sp]):<5d}" for sp in SPLITS))


def build_splits(src_root, out_root, smoke=False, smoke_sizes=(64, 32, 32), seed=0, manifest_path=None):
    """Build the random and scene splits (and smoke subsets). Returns {split_name: data.yaml path}."""
    items = collect_items(src_root)
    counts = Counter(i[0] for i in items)
    if dict(counts) != EXPECTED_COUNTS:
        print(f"WARNING: expected {EXPECTED_COUNTS}, found {dict(counts)} - is this MineGuard-Thermal v15?")

    random_split = {sp: [i for i in items if i[0] == sp] for sp in SPLITS}

    holdout = {seq: sp for sp, seqs in SCENE_HOLDOUT.items() for seq in seqs}
    scene_split = defaultdict(list)
    unknown = []
    for it in items:
        seq = sequence_of(it[1].name)
        if seq is None:
            unknown.append(it[1].name)
        scene_split[holdout.get(seq, "train")].append(it)
    if unknown:
        print(f"WARNING: {len(unknown)} images with unknown sequence were put in train, e.g. {unknown[:3]}")
    leaked = {sequence_of(i[1].name) for i in scene_split["train"]} & set(holdout)
    assert not leaked, f"held-out sequences leaked into train: {leaked}"

    splits = {"random": random_split, "scene": dict(scene_split)}
    if smoke:
        rng = random.Random(seed)
        splits = {
            f"{name}_smoke": {sp: rng.sample(s[sp], min(n, len(s[sp]))) for sp, n in zip(SPLITS, smoke_sizes)}
            for name, s in splits.items()
        }

    yamls = {}
    for name, assignment in splits.items():
        _summarise(name, assignment)
        yamls[name] = _write_split(assignment, Path(out_root) / name)

    if manifest_path is not None:
        Path(manifest_path).parent.mkdir(parents=True, exist_ok=True)
        scene_of = {i[1].name: sp for sp in SPLITS for i in scene_split[sp]}
        with open(manifest_path, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["image", "sequence", "boxes", "random_split", "scene_split"])
            for sp, img, _, n in items:
                w.writerow([img.name, sequence_of(img.name) or "", n, sp, scene_of[img.name]])
    return yamls
