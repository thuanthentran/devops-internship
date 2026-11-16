-- Schema chính cho app sở thích nghe nhạc.
-- File trong /docker-entrypoint-initdb.d chỉ chạy khi volume dữ liệu còn trống (lần khởi tạo đầu).

CREATE TABLE genres (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE artists (
    id               INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name             TEXT NOT NULL UNIQUE,
    country          TEXT,
    spotify_url      TEXT,
    apple_music_url  TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE songs (
    id               INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title            TEXT NOT NULL,
    artist_id        INTEGER NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    genre_id         INTEGER REFERENCES genres(id) ON DELETE SET NULL,
    release_year     SMALLINT CHECK (release_year BETWEEN 1900 AND 2100),
    duration_sec     INTEGER CHECK (duration_sec > 0),
    spotify_url      TEXT,
    apple_music_url  TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (artist_id, title)
);

CREATE TABLE playlists (
    id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         TEXT NOT NULL UNIQUE,
    description  TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Bảng nối N-N: một playlist có nhiều bài, một bài nằm trong nhiều playlist.
CREATE TABLE playlist_songs (
    playlist_id  INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    song_id      INTEGER NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    position     INTEGER NOT NULL CHECK (position > 0),
    added_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (playlist_id, song_id),
    UNIQUE (playlist_id, position)
);

-- Index cho các khoá ngoại hay dùng khi JOIN/lọc.
CREATE INDEX idx_songs_artist_id ON songs(artist_id);
CREATE INDEX idx_songs_genre_id ON songs(genre_id);
CREATE INDEX idx_playlist_songs_song_id ON playlist_songs(song_id);
