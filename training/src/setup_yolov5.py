"""Add CBAM to a pinned Ultralytics YOLOv5 checkout and prepare fair, COCO-pretrained CBAM models.

What this does (each step is idempotent):

1. ``patch``     - appends the CBAM module to ``models/common.py`` and teaches ``parse_model`` about it.
2. ``make_yaml`` - writes ``yolov5{s,x}_cbam.yaml``: the official architecture with one CBAM after
                   *every* C3 block in the backbone and the neck (8 CBAMs), all layer references remapped.
3. ``init_ckpt`` - remaps the official COCO ``yolov5{s,x}.pt`` weights into the CBAM layer numbering, so
                   the CBAM model starts from exactly the same pretrained weights as the baseline. Only
                   the CBAM blocks (and, as for the baseline, the 1-class Detect convs) start from scratch.
                   Without this remap YOLOv5 matches weights by layer index and silently drops most of them.
4. ``info``      - parameter / GFLOP table for the four models.

Run as a script inside any Python that can import the YOLOv5 repo, e.g.
``python setup_yolov5.py all --yolo-dir /tmp/lm/yolov5 --gen-dir /tmp/lm/gen --seeds 0 1 2``.
"""

import argparse
import copy
import json
import os
import sys
from pathlib import Path

import yaml

CBAM_SOURCE = '''

# ---------------------------------------------------------------------------------------------
# CBAM: Convolutional Block Attention Module (Woo et al., ECCV 2018), added for the landmine study.
# Pooling uses mean/amax rather than AdaptiveAvg/MaxPool2d because YOLOv5 trains with
# torch.use_deterministic_algorithms(True) and adaptive pooling has no deterministic CUDA backward.
class ChannelAttention(nn.Module):
    """Channel attention: shared MLP over global average- and max-pooled descriptors."""

    def __init__(self, c, r=16):
        super().__init__()
        h = max(c // r, 1)
        self.mlp = nn.Sequential(nn.Conv2d(c, h, 1, bias=False), nn.ReLU(), nn.Conv2d(h, c, 1, bias=False))

    def forward(self, x):
        return torch.sigmoid(self.mlp(x.mean((2, 3), keepdim=True)) + self.mlp(x.amax((2, 3), keepdim=True)))


class SpatialAttention(nn.Module):
    """Spatial attention: 7x7 conv over channel-wise average and max maps."""

    def __init__(self, k=7):
        super().__init__()
        self.conv = nn.Conv2d(2, 1, k, padding=k // 2, bias=False)

    def forward(self, x):
        return torch.sigmoid(self.conv(torch.cat((x.mean(1, keepdim=True), x.amax(1, keepdim=True)), 1)))


class CBAM(nn.Module):
    """Channel attention followed by spatial attention; output has the same shape as the input."""

    def __init__(self, c1, r=16, k=7):
        super().__init__()
        self.ca = ChannelAttention(c1, r)
        self.sa = SpatialAttention(k)

    def forward(self, x):
        x = x * self.ca(x)
        return x * self.sa(x)
'''

PARSE_ANCHOR = "        elif m is nn.BatchNorm2d:\n"
PARSE_BRANCH = "        elif m is CBAM:\n            c2 = ch[f]\n            args = [c2, *args]\n"
IMPORT_ANCHOR = "from models.experimental import MixConv2d\n"
IMPORT_LINE = "from models.common import CBAM\n"


def patch(yolo_dir):
    """Add CBAM to models/common.py and models/yolo.py (safe to call repeatedly)."""
    common = Path(yolo_dir, "models", "common.py")
    text = common.read_text(encoding="utf-8")
    if "class CBAM(" not in text:
        common.write_text(text + CBAM_SOURCE, encoding="utf-8")

    yolo = Path(yolo_dir, "models", "yolo.py")
    text = yolo.read_text(encoding="utf-8")
    if IMPORT_LINE not in text:
        assert text.count(IMPORT_ANCHOR) == 1 and text.count(PARSE_ANCHOR) == 1, (
            "models/yolo.py does not look like the pinned YOLOv5 commit; refusing to patch")
        text = text.replace(IMPORT_ANCHOR, IMPORT_LINE + IMPORT_ANCHOR, 1)
        text = text.replace(PARSE_ANCHOR, PARSE_BRANCH + PARSE_ANCHOR, 1)
        yolo.write_text(text, encoding="utf-8")
    print("patched YOLOv5 with CBAM")


def make_yaml(yolo_dir, variant, gen_dir):
    """Write yolov5{variant}_cbam.yaml; return (path, module_index_map, cbam_indices)."""
    src = yaml.safe_load(Path(yolo_dir, "models", f"yolov5{variant}.yaml").read_text(encoding="utf-8"))
    layers = src["backbone"] + src["head"]
    n_backbone = len(src["backbone"])

    new, module_at, output_at, cbam_idx = [], {}, {}, []
    new_backbone_len = None
    for i, layer in enumerate(layers):
        if i == n_backbone:
            new_backbone_len = len(new)
        module_at[i] = output_at[i] = len(new)
        new.append(copy.deepcopy(layer))
        if layer[2] == "C3":
            cbam_idx.append(len(new))
            output_at[i] = len(new)  # anything that consumed this C3 now consumes its CBAM
            new.append([-1, 1, "CBAM", []])

    def remap(f):
        if isinstance(f, list):
            return [remap(x) for x in f]
        return f if f < 0 else output_at[f]

    for layer in new:
        layer[0] = remap(layer[0])

    out = {k: v for k, v in src.items() if k not in ("backbone", "head")}
    out["backbone"], out["head"] = new[:new_backbone_len], new[new_backbone_len:]
    path = Path(gen_dir, f"yolov5{variant}_cbam.yaml")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"# yolov5{variant}.yaml with CBAM after every C3 (generated by setup_yolov5.py)\n"
                    + yaml.safe_dump(out, sort_keys=False, default_flow_style=None), encoding="utf-8")
    meta = {"module_map": module_at, "cbam_indices": cbam_idx}
    Path(gen_dir, f"yolov5{variant}_cbam.map.json").write_text(json.dumps(meta, indent=1))
    return path, module_at, cbam_idx


def _import_yolov5(yolo_dir):
    sys.path.insert(0, str(Path(yolo_dir).resolve()))
    os.chdir(yolo_dir)  # YOLOv5 resolves some paths relative to the repo root


def init_ckpt(yolo_dir, variant, seed, gen_dir):
    """Create gen_dir/yolov5{variant}_cbam_init_s{seed}.pt from the official COCO weights."""
    out_path = Path(gen_dir, f"yolov5{variant}_cbam_init_s{seed}.pt").resolve()
    if out_path.exists():
        return out_path
    cfg, module_at, cbam_idx = make_yaml(yolo_dir, variant, gen_dir)
    cfg = cfg.resolve()
    _import_yolov5(yolo_dir)
    import torch
    from models.yolo import Model
    from ultralytics.utils.patches import torch_load
    from utils.downloads import attempt_download

    ckpt = torch_load(attempt_download(f"yolov5{variant}.pt"), map_location="cpu")
    coco = ckpt["model"].float().state_dict()

    remapped = {}
    for k, v in coco.items():
        parts = k.split(".")
        parts[1] = str(module_at[int(parts[1])])
        remapped[".".join(parts)] = v

    torch.manual_seed(seed)  # CBAM blocks get a seed-dependent random init, like any new layer
    model = Model(str(cfg), ch=3, nc=80)
    missing, unexpected = model.load_state_dict(remapped, strict=False)
    assert not unexpected, f"unexpected keys: {unexpected[:5]}"
    bad = [k for k in missing if int(k.split(".")[1]) not in cbam_idx]
    assert not bad, f"non-CBAM weights missing after remap: {bad[:5]}"
    print(f"yolov5{variant}_cbam seed {seed}: {len(remapped)} COCO tensors transferred, "
          f"{len(missing)} CBAM tensors initialised from scratch")

    torch.save({"model": copy.deepcopy(model).half(), "epoch": -1, "best_fitness": None, "optimizer": None,
                "ema": None, "updates": None, "opt": None,
                "note": f"COCO yolov5{variant}.pt remapped into the CBAM layout (seed {seed})"}, out_path)
    return out_path


def info(yolo_dir, gen_dir, imgsz=416):
    """Print and return params/GFLOPs for the baseline and CBAM models (nc=1)."""
    _import_yolov5(yolo_dir)
    import thop
    import torch
    from models.common import CBAM
    from models.yolo import Model

    rows = {}
    for variant in ("s", "x"):
        for name, cfg in ((f"yolov5{variant}", Path(yolo_dir, "models", f"yolov5{variant}.yaml")),
                          (f"yolov5{variant}_cbam", Path(gen_dir, f"yolov5{variant}_cbam.yaml").resolve())):
            if not cfg.exists():
                continue
            m = Model(str(cfg), ch=3, nc=1).eval()
            params = sum(p.numel() for p in m.parameters())
            macs = thop.profile(copy.deepcopy(m), inputs=(torch.zeros(1, 3, imgsz, imgsz),), verbose=False)[0]
            n_cbam = sum(isinstance(x, CBAM) for x in m.modules())
            rows[name] = {"params": params, "gflops": 2 * macs / 1e9, "cbam_blocks": n_cbam}
    print(f"\n{'model':16s}{'params':>14s}{'GFLOPs@' + str(imgsz):>14s}{'CBAM blocks':>13s}")
    for k, r in rows.items():
        print(f"{k:16s}{r['params']:>14,d}{r['gflops']:>14.1f}{r['cbam_blocks']:>13d}")
    for v in ("s", "x"):
        if f"yolov5{v}_cbam" in rows:
            assert rows[f"yolov5{v}_cbam"]["cbam_blocks"] == 8, "expected one CBAM after each of the 8 C3 blocks"
    return rows


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("step", choices=["patch", "yaml", "init", "info", "all"])
    ap.add_argument("--yolo-dir", required=True)
    ap.add_argument("--gen-dir", required=True)
    ap.add_argument("--variants", nargs="+", default=["s", "x"])
    ap.add_argument("--seeds", nargs="+", type=int, default=[0])
    ap.add_argument("--imgsz", type=int, default=416)
    a = ap.parse_args()
    a.gen_dir = str(Path(a.gen_dir).resolve())
    a.yolo_dir = str(Path(a.yolo_dir).resolve())
    if a.step in ("patch", "all"):
        patch(a.yolo_dir)
    if a.step in ("yaml", "all"):
        for v in a.variants:
            print("wrote", make_yaml(a.yolo_dir, v, a.gen_dir)[0])
    if a.step in ("init", "all"):
        here = os.getcwd()
        for v in a.variants:
            for s in a.seeds:
                init_ckpt(a.yolo_dir, v, s, a.gen_dir)
                os.chdir(here)
    if a.step in ("info", "all"):
        res = info(a.yolo_dir, a.gen_dir, a.imgsz)
        Path(a.gen_dir, "model_info.json").write_text(json.dumps(res, indent=2))
