import { useEffect, useState } from 'react';

// Mặc định gọi cùng origin (nginx trong container web proxy /api sang API).
// Khi deploy tách subdomain, build với VITE_API_URL=https://node.<domain>.
const API = import.meta.env.VITE_API_URL || '';

const fmt = (sec) => `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`;

function useFetch(path) {
  const [state, setState] = useState({ data: null, error: null });
  useEffect(() => {
    if (!path) return;
    setState({ data: null, error: null });
    fetch(`${API}${path}`)
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`))))
      .then((data) => setState({ data, error: null }))
      .catch((error) => setState({ data: null, error }));
  }, [path]);
  return state;
}

function SongTable({ songs }) {
  return (
    <table>
      <thead>
        <tr><th>Bài hát</th><th>Nghệ sĩ</th><th>Thể loại</th><th>Năm</th><th>Thời lượng</th><th>Nghe trên</th></tr>
      </thead>
      <tbody>
        {songs.map((s) => (
          <tr key={s.id}>
            <td>{s.title}</td>
            <td>{s.artist}</td>
            <td>{s.genre}</td>
            <td>{s.release_year}</td>
            <td>{fmt(s.duration_sec)}</td>
            <td>
              <a href={s.spotify_url} target="_blank" rel="noreferrer">Spotify</a>{' · '}
              <a href={s.apple_music_url} target="_blank" rel="noreferrer">Apple Music</a>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function Playlists() {
  const list = useFetch('/api/playlists');
  const [selected, setSelected] = useState(null);
  const detail = useFetch(selected ? `/api/playlists/${selected}` : null);

  if (list.error) return <p className="error">Lỗi tải playlist: {list.error.message}</p>;
  if (!list.data) return <p>Đang tải…</p>;
  return (
    <>
      <div className="chips">
        {list.data.map((p) => (
          <button key={p.id} className={p.id === selected ? 'active' : ''} onClick={() => setSelected(p.id)}>
            {p.name} ({p.song_count})
          </button>
        ))}
      </div>
      {detail.data && (
        <>
          <p className="muted">{detail.data.description}</p>
          <SongTable songs={detail.data.songs} />
        </>
      )}
    </>
  );
}

function AllSongs() {
  const { data, error } = useFetch('/api/songs');
  if (error) return <p className="error">Lỗi tải bài hát: {error.message}</p>;
  if (!data) return <p>Đang tải…</p>;
  return <SongTable songs={data} />;
}

export default function App() {
  return (
    <main>
      <h1>🎧 Sở thích nghe nhạc</h1>
      <h2>Playlist</h2>
      <Playlists />
      <h2>Tất cả bài hát</h2>
      <AllSongs />
    </main>
  );
}
