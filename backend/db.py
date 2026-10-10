"""Optional PostgreSQL persistence. Without DATABASE_URL the API works and simply keeps no history."""

import logging
import os
from contextlib import closing
from pathlib import Path

log = logging.getLogger(__name__)
DATABASE_URL = os.getenv("DATABASE_URL", "")  # e.g. postgresql://user:password@localhost:5432/landmine_detection


def enabled():
    return bool(DATABASE_URL)


def _connect():
    import psycopg2

    return psycopg2.connect(DATABASE_URL)


def init():
    """Create the tables if they do not exist (schema.sql is idempotent)."""
    if not enabled():
        log.warning("DATABASE_URL not set: detections will not be stored")
        return
    schema = Path(__file__).with_name("schema.sql").read_text()
    with closing(_connect()) as conn, conn, conn.cursor() as cur:
        cur.execute(schema)


def save_detection(file_name, confidences, is_video=False, result_path=None):
    if not enabled():
        return None
    try:
        with closing(_connect()) as conn, conn, conn.cursor() as cur:
            cur.execute("INSERT INTO detections (image_path, mines_detected, result_image_path, is_video) "
                        "VALUES (%s, %s, %s, %s) RETURNING id", (file_name, len(confidences), result_path, is_video))
            det_id = cur.fetchone()[0]
            cur.executemany("INSERT INTO landmine_details (detection_id, mine_number, detection_percentage) "
                            "VALUES (%s, %s, %s)",
                            [(det_id, i, round(float(c) * 100, 2)) for i, c in enumerate(confidences, start=1)])
        return det_id
    except Exception:  # a database hiccup must not lose the user's detection result
        log.exception("could not store detection for %s", file_name)
        return None


def list_records():
    if not enabled():
        return []
    with closing(_connect()) as conn, conn, conn.cursor() as cur:
        cur.execute("SELECT id, image_path, mines_detected, result_image_path, is_video, timestamp "
                    "FROM detections ORDER BY id DESC")
        rows = cur.fetchall()
        cur.execute("SELECT detection_id, mine_number, detection_percentage FROM landmine_details "
                    "ORDER BY detection_id, mine_number")
        details = {}
        for det_id, n, pct in cur.fetchall():
            details.setdefault(det_id, []).append({"mine_number": n, "detection_percentage": float(pct)})
    return [{"detection_id": r[0], "file_path": r[1], "mines_detected": r[2], "result_path": r[3],
             "is_video": r[4], "timestamp": r[5].isoformat() if r[5] else None,
             "mine_details": details.get(r[0], [])} for r in rows]
