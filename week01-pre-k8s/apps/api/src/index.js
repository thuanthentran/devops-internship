import express from 'express';
import cors from 'cors';
import pg from 'pg';

// Pool = tập kết nối tái sử dụng tới Postgres, tránh mở kết nối mới mỗi request.
const pool = new pg.Pool({
  host: process.env.PGHOST || 'postgres',
  port: Number(process.env.PGPORT || 5432),
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  database: process.env.POSTGRES_DB,
});

const app = express();
app.use(cors());

// Bọc handler async để lỗi DB trả 500 thay vì làm treo request.
const wrap = (fn) => (req, res) =>
  fn(req, res).catch((err) => {
    console.error(err);
    res.status(500).json({ error: 'internal error' });
  });

const SONG_SELECT = `
  SELECT s.id, s.title, s.release_year, s.duration_sec, s.spotify_url, s.apple_music_url,
         a.id AS artist_id, a.name AS artist, g.name AS genre
  FROM songs s
  JOIN artists a ON a.id = s.artist_id
  LEFT JOIN genres g ON g.id = s.genre_id`;

app.get('/health', wrap(async (_req, res) => {
  await pool.query('SELECT 1');
  res.json({ status: 'ok' });
}));

app.get('/api/artists', wrap(async (_req, res) => {
  const { rows } = await pool.query('SELECT * FROM artists ORDER BY name');
  res.json(rows);
}));

app.get('/api/genres', wrap(async (_req, res) => {
  const { rows } = await pool.query('SELECT * FROM genres ORDER BY name');
  res.json(rows);
}));

app.get('/api/songs', wrap(async (_req, res) => {
  const { rows } = await pool.query(`${SONG_SELECT} ORDER BY a.name, s.title`);
  res.json(rows);
}));

app.get('/api/playlists', wrap(async (_req, res) => {
  const { rows } = await pool.query(`
    SELECT p.id, p.name, p.description, count(ps.song_id)::int AS song_count
    FROM playlists p
    LEFT JOIN playlist_songs ps ON ps.playlist_id = p.id
    GROUP BY p.id ORDER BY p.id`);
  res.json(rows);
}));

app.get('/api/playlists/:id', wrap(async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) return res.status(400).json({ error: 'invalid id' });
  const pl = await pool.query('SELECT id, name, description FROM playlists WHERE id = $1', [id]);
  if (pl.rowCount === 0) return res.status(404).json({ error: 'not found' });
  const songs = await pool.query(
    `${SONG_SELECT} JOIN playlist_songs ps ON ps.song_id = s.id
     WHERE ps.playlist_id = $1 ORDER BY ps.position`, [id]);
  res.json({ ...pl.rows[0], songs: songs.rows });
}));

const port = Number(process.env.PORT || 3000);
app.listen(port, () => console.log(`API listening on :${port}`));
