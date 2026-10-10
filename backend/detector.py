"""Thin wrapper around an Ultralytics YOLO model: detect, draw and process whole videos."""

from pathlib import Path

import cv2

BOX_COLOR = (0, 255, 0)


class Detector:
    def __init__(self, weights, conf=0.25, imgsz=640):
        self.weights, self.conf, self.imgsz = str(weights), conf, imgsz
        self._model = None

    @property
    def model(self):
        if self._model is None:  # load lazily so the API starts (and /test answers) without the weights
            if not Path(self.weights).exists():
                raise FileNotFoundError(f"model weights not found: {self.weights} (set MODEL_PATH)")
            from ultralytics import YOLO

            self._model = YOLO(self.weights)
        return self._model

    def detect(self, image):
        """Return [{'box': [x1, y1, x2, y2], 'conf': float}] for one BGR image."""
        result = self.model.predict(image, conf=self.conf, imgsz=self.imgsz, verbose=False)[0]
        boxes = result.boxes.xyxy.cpu().numpy().round().astype(int).tolist()
        confs = result.boxes.conf.cpu().numpy().tolist()
        return [{"box": b, "conf": round(c, 4)} for b, c in zip(boxes, confs)]

    @staticmethod
    def draw(image, detections):
        out = image.copy()
        for i, d in enumerate(detections, start=1):
            x1, y1, x2, y2 = d["box"]
            cv2.rectangle(out, (x1, y1), (x2, y2), BOX_COLOR, 2)
            cv2.putText(out, f"Mine {i} ({d['conf']:.2f})", (x1, max(y1 - 8, 12)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, BOX_COLOR, 2)
        return out

    def process_video(self, src, dst):
        """Annotate every frame of ``src`` into ``dst`` (same fps as the input) and return counts."""
        cap = cv2.VideoCapture(str(src))
        if not cap.isOpened():
            raise ValueError("could not open the video file")
        fps = cap.get(cv2.CAP_PROP_FPS) or 15
        size = (int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)), int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)))
        writer = None
        for codec in ("avc1", "mp4v"):  # avc1 (H.264) plays in browsers/phones; mp4v is the fallback
            writer = cv2.VideoWriter(str(dst), cv2.VideoWriter_fourcc(*codec), fps, size)
            if writer.isOpened():
                break
        if writer is None or not writer.isOpened():
            cap.release()
            raise ValueError("could not create an MP4 writer for this video")
        frames = frames_with = 0
        peak = []
        try:
            while True:
                ok, frame = cap.read()
                if not ok:
                    break
                dets = self.detect(frame)
                frames += 1
                frames_with += bool(dets)
                if len(dets) > len(peak):
                    peak = [d["conf"] for d in dets]
                writer.write(self.draw(frame, dets))
        finally:
            cap.release()
            writer.release()
        return {"frames": frames, "frames_with_detections": frames_with, "max_mines_in_frame": len(peak),
                "peak_confidences": peak, "fps": fps}
