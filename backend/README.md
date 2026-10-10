# Backend (Flask API for the mobile app)

Serves the trained detector to the Flutter app in [`mobile/`](../mobile/). The routes are mounted at
`/flutter` to keep the original app's URLs.

| Method | Route | Does |
|---|---|---|
| GET | `/flutter/test` | health check (model path, whether a database is configured) |
| POST | `/flutter/upload` | images in form field `file` (one or many) → JSON list of annotated JPEGs (base64), counts and boxes |
| POST | `/flutter/process_video` | video in form field `video` → annotated MP4; headers `mines_detected` (peak boxes in one frame), `frames`, `frames_with_detections` |
| GET | `/flutter/records` | detection history (empty list without a database) |
| GET | `/flutter/live_stream`, `/flutter/live_original_stream` | MJPEG stream of `LIVE_SOURCE` with / without detections |

## Run
```bash
cd backend
python -m venv .venv && . .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env                           # then edit MODEL_PATH etc.
python app.py
```
Put the trained weights at `backend/models/best.pt` (download them from the repository's GitHub release), or
point `MODEL_PATH` elsewhere. Set `HOST=0.0.0.0` to reach the API from a phone on the same network, and run
the app with `--dart-define=API_BASE_URL=http://<pc-ip>:5000/flutter`.

**Database (optional).** Set `DATABASE_URL=postgresql://user:password@host:5432/landmine_detection` and the tables
in [`schema.sql`](schema.sql) are created on start-up. Without it the API works and keeps no history.

## Notes
* Videos are annotated frame by frame without tracking, so the same mine appears in many frames. The API
  therefore reports the **peak number of boxes in a single frame**, not a sum over frames.
* The confidence threshold defaults to 0.25 (Ultralytics' default); tune `CONF_THRESHOLD` for your data.
* This is a research prototype: no authentication, and debug mode is off unless `FLASK_DEBUG=1`. Do not
  expose it to the internet as is.
