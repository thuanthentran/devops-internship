-- Dữ liệu mẫu. Link dùng trang tìm kiếm của Spotify/Apple Music
-- (không bịa ID bài hát); có thể thay bằng link bài cụ thể sau.

INSERT INTO genres (name) VALUES
    ('Pop'), ('Dream-Pop'), ('V-Pop'), ('Indie'), ('Alternative'), ('Hyperpop') ;

INSERT INTO artists (name, country, spotify_url, apple_music_url) VALUES
    ('Phùng Khánh Linh', 'VN', 'https://open.spotify.com/search/Phung%20Khanh%20Linh', 'https://music.apple.com/search?term=Phung%20Khanh%20Linh'),
    ('Olivia Rodrigo',   'US', 'https://open.spotify.com/search/Olivia%20Rodrigo',     'https://music.apple.com/search?term=Olivia%20Rodrigo'),
    ('Sabrina Carpenter','US', 'https://open.spotify.com/search/Sabrina%20Carpenter',  'https://music.apple.com/search?term=Sabrina%20Carpenter'),
    ('Ariana Grande',    'US', 'https://open.spotify.com/search/Ariana%20Grande',      'https://music.apple.com/search?term=Ariana%20Grande'),
    ('aespa',            'KR', 'https://open.spotify.com/search/aespa',                'https://music.apple.com/search?term=aespa'),
    ('Adele',            'UK', 'https://open.spotify.com/search/Adele',                'https://music.apple.com/search?term=Adele');

-- Chèn bài hát bằng tên nghệ sĩ/thể loại thay vì ID cứng.
INSERT INTO songs (title, artist_id, genre_id, release_year, duration_sec, spotify_url, apple_music_url)
SELECT s.title, a.id, g.id, s.release_year, s.duration_sec,
       'https://open.spotify.com/search/' || replace(s.title || ' ' || s.artist, ' ', '%20'),
       'https://music.apple.com/search?term=' || replace(s.title || ' ' || s.artist, ' ', '%20')
FROM (VALUES
    ('Ước Anh Tan Nát Con Tim','Phùng Khánh Linh', 'V-Pop',      2024, 230),
    ('good 4 u',           'Olivia Rodrigo',   'Alternative', 2021, 178),
    ('drivers license',    'Olivia Rodrigo',   'Pop',         2021, 242),
    ('Espresso',           'Sabrina Carpenter','Pop',         2024, 175),
    ('Please Please Please','Sabrina Carpenter','Pop',        2024, 186),
    ('7 rings',            'Ariana Grande',    'Pop',         2019, 178),
    ('thank u, next',      'Ariana Grande',    'Pop',         2018, 207),
    ('Supernova',          'aespa',            'Hyperpop',    2024, 179),
    ('Next Level',         'aespa',            'Hyperpop',    2021, 221),
    ('Someone Like You',   'Adele',            'Pop',         2011, 285),
    ('Hello',              'Adele',            'Pop',         2015, 295)
) AS s(title, artist, genre, release_year, duration_sec)
JOIN artists a ON a.name = s.artist
JOIN genres  g ON g.name = s.genre;

INSERT INTO playlists (name, description) VALUES
    ('Chill buổi tối', 'Nhẹ nhàng để thư giãn'),
    ('Code mode',      'Nghe khi tập trung làm việc'),
    ('Pop nữ',         'Các giọng nữ pop yêu thích');

INSERT INTO playlist_songs (playlist_id, song_id, position)
SELECT p.id, s.id, x.position
FROM (VALUES
    ('Chill buổi tối', 'Someone Like You',    1),
    ('Chill buổi tối', 'drivers license',     2),
    ('Chill buổi tối', 'Ước Anh Tan Nát Con Tim',   3),
    ('Code mode',      'Supernova',           1),
    ('Code mode',      'Next Level',          2),
    ('Code mode',      'good 4 u',            3),
    ('Code mode',      'Espresso',            4),
    ('Pop nữ',         '7 rings',             1),
    ('Pop nữ',         'thank u, next',       2),
    ('Pop nữ',         'Please Please Please',3),
    ('Pop nữ',         'Hello',               4)
) AS x(playlist, title, position)
JOIN playlists p ON p.name = x.playlist
JOIN songs     s ON s.title = x.title;
