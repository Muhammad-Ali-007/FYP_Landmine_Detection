-- Detection history for the mobile backend (PostgreSQL). Safe to run repeatedly.
CREATE TABLE IF NOT EXISTS detections (
    id                SERIAL PRIMARY KEY,
    image_path        TEXT NOT NULL,              -- original upload name
    mines_detected    INTEGER NOT NULL DEFAULT 0, -- images: boxes; videos: peak boxes in one frame
    result_image_path TEXT,
    is_video          BOOLEAN NOT NULL DEFAULT FALSE,
    timestamp         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- databases created with the 2025 schema lack this column
ALTER TABLE detections ADD COLUMN IF NOT EXISTS is_video BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS landmine_details (
    id                   SERIAL PRIMARY KEY,
    detection_id         INTEGER NOT NULL REFERENCES detections(id) ON DELETE CASCADE,
    mine_number          INTEGER NOT NULL,
    detection_percentage NUMERIC(5, 2) NOT NULL   -- model confidence x 100
);
