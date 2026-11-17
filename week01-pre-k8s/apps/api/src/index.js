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


const port = Number(process.env.PORT || 3000);
app.listen(port, () => console.log(`API listening on :${port}`));
