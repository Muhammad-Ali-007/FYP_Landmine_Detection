"""Run the landmine detector on a video, a camera, or a folder of frames and save an annotated MP4.

Examples
  python demo/detect.py --weights weights/yolo11m_landmine.pt --source drone_clip.mp4
  python demo/detect.py --weights weights/yolo11m_landmine.pt --source frames/ --fps 5   # "simulated UAV feed"
  python demo/detect.py --weights weights/yolo11m_landmine.pt --source 0 --show           # webcam / capture card

A folder of frames is played in natural filename order, as if it were a drone video.
"""

import argparse
import re
import time
from pathlib import Path

import cv2
from ultralytics import YOLO

IMG_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff"}


def natural_key(p):
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", p.name)]


def frames_from(source):
    """Yield BGR frames from a folder of images, a video file or a camera index."""
    path = Path(source)
    if path.is_dir():
        for f in sorted((p for p in path.iterdir() if p.suffix.lower() in IMG_EXTS), key=natural_key):
            img = cv2.imread(str(f))
            if img is not None:
                yield img
        return
    cap = cv2.VideoCapture(int(source) if str(source).isdigit() else str(source))
    if not cap.isOpened():
        raise SystemExit(f"cannot open source {source!r}")
    try:
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            yield frame
    finally:
        cap.release()


def source_fps(source):
    if Path(source).is_dir():
        return None
    cap = cv2.VideoCapture(int(source) if str(source).isdigit() else str(source))
    fps = cap.get(cv2.CAP_PROP_FPS)
    cap.release()
    return fps or None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--weights", required=True, help="trained model (.pt)")
    ap.add_argument("--source", required=True, help="video file, folder of frames, or camera index")
    ap.add_argument("--out", default="outputs/detections.mp4")
    ap.add_argument("--conf", type=float, default=0.25)
    ap.add_argument("--imgsz", type=int, default=640)
    ap.add_argument("--fps", type=float, default=None, help="output fps (default: source fps, 5 for folders)")
    ap.add_argument("--size", type=int, nargs=2, metavar=("W", "H"), default=None,
                    help="output frame size (default: first frame's size)")
    ap.add_argument("--show", action="store_true", help="also display frames in a window")
    a = ap.parse_args()

    model = YOLO(a.weights)
    fps = a.fps or source_fps(a.source) or 5
    out_path = Path(a.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    writer, size = None, tuple(a.size) if a.size else None
    n = n_with = boxes = 0
    t0 = time.perf_counter()
    for frame in frames_from(a.source):
        result = model.predict(frame, conf=a.conf, imgsz=a.imgsz, verbose=False)[0]
        annotated = result.plot(line_width=2)
        if size is None:
            size = (annotated.shape[1], annotated.shape[0])
        if (annotated.shape[1], annotated.shape[0]) != size:
            annotated = cv2.resize(annotated, size)
        if writer is None:
            writer = cv2.VideoWriter(str(out_path), cv2.VideoWriter_fourcc(*"mp4v"), fps, size)
        writer.write(annotated)
        n += 1
        n_with += len(result.boxes) > 0
        boxes += len(result.boxes)
        if a.show:
            cv2.imshow("landmine detection", annotated)
            if cv2.waitKey(1) & 0xFF == ord("q"):
                break
    if writer is not None:
        writer.release()
    if a.show:
        cv2.destroyAllWindows()
    dt = time.perf_counter() - t0
    print(f"{n} frames in {dt:.1f} s ({n / max(dt, 1e-9):.1f} FPS incl. drawing) | "
          f"{n_with} frames with detections, {boxes} boxes | saved {out_path}")


if __name__ == "__main__":
    main()
