import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

DSN = (
    f"host={os.getenv('POSTGRES_HOST', 'postgres')} "
    f"dbname={os.environ['POSTGRES_DB']} "
    f"user={os.environ['POSTGRES_USER']} "
    f"password={os.environ['POSTGRES_PASSWORD']}"
)

TOTALS_SQL = """
SELECT
  (SELECT COUNT(*) FROM songs)     AS songs,
  (SELECT COUNT(*) FROM artists)   AS artists,
  (SELECT COUNT(*) FROM playlists) AS playlists
"""

SONGS_BY_GENRE_SQL = """
SELECT COALESCE(g.name, 'Unknown') AS genre, COUNT(*) AS count
FROM songs s
LEFT JOIN genres g ON g.id = s.genre_id
GROUP BY g.name
ORDER BY count DESC, genre
"""

TOP_ARTISTS_SQL = """
SELECT a.name AS artist, COUNT(*) AS songs
FROM songs s
JOIN artists a ON a.id = s.artist_id
GROUP BY a.id, a.name
ORDER BY songs DESC, artist
LIMIT 3
"""

PLAYLIST_DURATIONS_SQL = """
SELECT p.name AS playlist, COALESCE(SUM(s.duration_sec), 0)::int AS total_sec
FROM playlists p
LEFT JOIN playlist_songs ps ON ps.playlist_id = p.id
LEFT JOIN songs s ON s.id = ps.song_id
GROUP BY p.id, p.name
ORDER BY p.id
"""


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.pool = ConnectionPool(
        DSN, min_size=1, max_size=3, kwargs={"row_factory": dict_row}
    )
    yield
    app.state.pool.close()


app = FastAPI(lifespan=lifespan)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/api/stats")
def get_stats():
    with app.state.pool.connection() as conn:
        totals = conn.execute(TOTALS_SQL).fetchone()
        songs_by_genre = conn.execute(SONGS_BY_GENRE_SQL).fetchall()
        top_artists = conn.execute(TOP_ARTISTS_SQL).fetchall()
        playlist_durations = conn.execute(PLAYLIST_DURATIONS_SQL).fetchall()
    return {
        "totals": totals,
        "songs_by_genre": songs_by_genre,
        "top_artists": top_artists,
        "playlist_durations": playlist_durations,
    }
