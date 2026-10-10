"""Flask API used by the mobile app (mounted at /flutter).

Endpoints
  GET  /flutter/test                  health check
  POST /flutter/upload                one or more images (field "file")  -> annotated JPEGs (base64) + boxes
  POST /flutter/process_video         one video (field "video")          -> annotated MP4, counts in headers
  GET  /flutter/records               detection history (empty list when no database is configured)
  GET  /flutter/live_stream           MJPEG stream of LIVE_SOURCE with detections
  GET  /flutter/live_original_stream  MJPEG stream of LIVE_SOURCE without detections
  GET  /flutter/static/<filename>     files saved in RESULTS_DIR

All settings come from environment variables (see .env.example).
"""

import base64
import io
import os
import tempfile
import time
from pathlib import Path

import cv2
import numpy as np
from flask import Blueprint, Flask, Response, jsonify, request, send_file, send_from_directory
from flask_cors import CORS

try:  # load .env before db/detector read their settings
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass

import db  # noqa: E402
from detector import Detector  # noqa: E402

RESULTS_DIR = Path(os.getenv("RESULTS_DIR", "static")).resolve()
LIVE_SOURCE = os.getenv("LIVE_SOURCE", "")
MAX_UPLOAD_MB = int(os.getenv("MAX_UPLOAD_MB", "100"))

api = Blueprint("flutter_api", __name__)
detector = Detector(
    weights=os.getenv("MODEL_PATH", "models/best.pt"),
    conf=float(os.getenv("CONF_THRESHOLD", "0.25")),
    imgsz=int(os.getenv("IMGSZ", "640")),
)


@api.route("/test")
def health():
    return jsonify({"status": "API working", "model": Path(detector.weights).name, "database": db.enabled()})


@api.route("/upload", methods=["POST"])
def upload_images():
    files = [f for f in request.files.getlist("file") if f and f.filename]
    if not files:
        return jsonify({"status": "error", "message": "no file uploaded (form field 'file')"}), 400
    results = []
    for f in files:
        img = cv2.imdecode(np.frombuffer(f.read(), np.uint8), cv2.IMREAD_COLOR)
        if img is None:
            return jsonify({"status": "error", "message": f"{f.filename} is not a readable image"}), 400
        dets = detector.detect(img)
        annotated = detector.draw(img, dets)
        ok, jpg = cv2.imencode(".jpg", annotated)
        if not ok:
            return jsonify({"status": "error", "message": "could not encode the result image"}), 500
        db.save_detection(f.filename, [d["conf"] for d in dets], is_video=False)
        results.append({
            "original_filename": f.filename,
            "image_data": base64.b64encode(jpg.tobytes()).decode("ascii"),
            "num_mines": len(dets),
            "detections": dets,
        })
    return jsonify(results)


@api.route("/process_video", methods=["POST"])
def process_video():
    video = request.files.get("video")
    if video is None or not video.filename:
        return jsonify({"status": "error", "message": "no video uploaded (form field 'video')"}), 400
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp, "input" + (Path(video.filename).suffix or ".mp4"))
        dst = Path(tmp, "processed.mp4")
        video.save(src)
        try:
            stats = detector.process_video(src, dst)
        except ValueError as e:
            return jsonify({"status": "error", "message": str(e)}), 400
        data = io.BytesIO(dst.read_bytes())  # read before the temp dir is removed (Windows-safe)
    # Without tracking the same mine is seen in many frames, so report the per-frame peak, not a sum.
    db.save_detection(video.filename, stats["peak_confidences"], is_video=True)
    response = send_file(data, mimetype="video/mp4", as_attachment=True,
                         download_name=f"processed_{Path(video.filename).stem}.mp4")
    response.headers["mines_detected"] = str(stats["max_mines_in_frame"])
    response.headers["frames"] = str(stats["frames"])
    response.headers["frames_with_detections"] = str(stats["frames_with_detections"])
    return response


@api.route("/records")
def records():
    try:
        return jsonify(db.list_records())
    except Exception as e:  # database configured but unreachable
        return jsonify({"status": "error", "message": str(e)}), 500


def _mjpeg(annotate):
    if not LIVE_SOURCE:
        return jsonify({"status": "error", "message": "LIVE_SOURCE is not set"}), 503
    source = int(LIVE_SOURCE) if LIVE_SOURCE.isdigit() else LIVE_SOURCE
    cap = cv2.VideoCapture(source)
    if not cap.isOpened():
        return jsonify({"status": "error", "message": f"cannot open LIVE_SOURCE {LIVE_SOURCE!r}"}), 503
    fps = cap.get(cv2.CAP_PROP_FPS) or 15

    def frames():
        try:
            while True:
                ok, frame = cap.read()
                if not ok:  # loop video files; stop if the source is gone
                    cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    ok, frame = cap.read()
                    if not ok:
                        break
                if annotate:
                    frame = detector.draw(frame, detector.detect(frame))
                else:
                    time.sleep(1 / fps)
                ok, jpg = cv2.imencode(".jpg", frame)
                if ok:
                    yield b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" + jpg.tobytes() + b"\r\n"
        finally:
            cap.release()

    return Response(frames(), mimetype="multipart/x-mixed-replace; boundary=frame")


@api.route("/live_stream")
def live_stream():
    return _mjpeg(annotate=True)


@api.route("/live_original_stream")
def live_original_stream():
    return _mjpeg(annotate=False)


@api.route("/static/<path:filename>")
def static_files(filename):
    return send_from_directory(RESULTS_DIR, filename)  # rejects paths outside RESULTS_DIR


def create_app():
    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = MAX_UPLOAD_MB * 1024 * 1024
    origins = os.getenv("CORS_ORIGINS", "*")
    CORS(app, resources={r"/flutter/*": {"origins": origins.split(",") if origins != "*" else "*"}},
         expose_headers=["mines_detected", "frames", "frames_with_detections"])
    app.register_blueprint(api, url_prefix="/flutter")
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    db.init()
    return app


if __name__ == "__main__":
    create_app().run(host=os.getenv("HOST", "127.0.0.1"), port=int(os.getenv("PORT", "5000")),
                     debug=os.getenv("FLASK_DEBUG", "0") == "1")
