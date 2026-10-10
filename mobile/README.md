# Mobile app (Flutter)

Prototype Android client for the landmine detector, intended to run on Android-based drone controllers.
It sends thermal images or videos to the [Flask backend](../backend/) and shows the annotated results.

| Screen | File | What it does |
|---|---|---|
| Dashboard | `lib/dashboard_page.dart` | summary statistics from past detections, navigation |
| Image detection | `lib/main.dart` (`ImageUploadPage`) | pick one or more images → annotated images + mine counts |
| Video detection | `lib/video_detection.dart` | upload a video → annotated video, side by side with the input |
| Live detection | `lib/live_stream_page.dart` | original and annotated MJPEG streams from the backend |
| Records | `lib/records_page.dart` | detection history (status *DANGER* / *SAFE*) |

## Run
```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/flutter      # Android emulator → backend on this PC
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5000/flutter  # real phone → backend's LAN address
```
Without `--dart-define` the app uses `http://127.0.0.1:5000/flutter` (desktop/web builds on the same machine).
The setting lives in [`lib/config.dart`](lib/config.dart).

Status: working prototype (image, video, live stream, history). Not yet integrated with a drone SDK.
