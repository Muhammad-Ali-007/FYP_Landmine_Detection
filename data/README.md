# Data

**MineGuard-Thermal, version 15**, a public Roboflow dataset by the `dronecv` workspace:
<https://universe.roboflow.com/dronecv/mineguard-thermal/dataset/15>, licensed **CC BY 4.0**.
The images are not stored in this repository; download them from Roboflow.

| | |
|---|---|
| Images | 3,042 thermal frames, one class (`landmine`) |
| Original split | 2,132 train / 607 valid / 303 test (70 / 20 / 10) |
| Sequences | `FlightAltitude` (1,228), `MYKHAILO_1-4` (813), `illia_1-4` (905), `DM-11` (96) |
| Boxes | 5,929 in total (4,177 / 1,187 / 565 in train / valid / test); `DM-11` frames are dense (≈13 boxes per image) |

## Download
* **Roboflow website:** open the link above → *Download Dataset* → format **YOLOv8** (same label format as
  YOLOv5) → zip.
* **Python:**
  ```python
  from roboflow import Roboflow  # pip install roboflow
  rf = Roboflow(api_key="<your key>")  # never commit the key
  rf.workspace("dronecv").project("mineguard-thermal").version(15).download("yolov5", location="data/raw")
  ```

## Splits used in this project
* **random**: the original Roboflow split, used in the 2025 thesis and in experiments E1/E2.
* **scene**: whole recording sequences held out (experiment E3); see [`training/README.md`](../training/README.md).

Both are built on the fly by [`training/src/splits.py`](../training/src/splits.py) from the downloaded export.

## Attribution
If you use the dataset, credit the MineGuard-Thermal authors (Roboflow Universe, `dronecv`) as required by CC BY 4.0.
