-- migrate:up
-- Bước "expand": chỉ THÊM, không đổi/xoá gì đang dùng, nên bản app cũ vẫn chạy bình thường.
CREATE TABLE albums (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            TEXT NOT NULL,
    artist_id       INTEGER NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    release_year    SMALLINT CHECK (release_year BETWEEN 1900 AND 2100),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (artist_id, name)
);

-- Cột mới phải cho phép NULL (bài cũ chưa có album, app cũ không biết cột này).
ALTER TABLE songs ADD COLUMN album_id INTEGER REFERENCES albums(id) ON DELETE SET NULL;
CREATE INDEX idx_songs_album_id ON songs(album_id);

-- migrate:down
DROP INDEX IF EXISTS idx_songs_album_id;
ALTER TABLE songs DROP COLUMN IF EXISTS album_id;
DROP TABLE IF EXISTS albums;
