-- Dữ liệu mẫu. Link dùng trang tìm kiếm của Spotify/Apple Music
-- (không bịa ID bài hát); có thể thay bằng link bài cụ thể sau.

INSERT INTO genres (name) VALUES
    ('Pop'), ('Dream-Pop'), ('V-Pop'), ('Indie'), ('Alternative'), ('Hyperpop') ;

INSERT INTO artists (name, country, spotify_url, apple_music_url) VALUES
    ('Phùng Khánh Linh', 'US', 'https://open.spotify.com/search/Taylor%20Swift', 'https://music.apple.com/search?term=Taylor%20Swift'),
    ('Coldplay',     'UK', 'https://open.spotify.com/search/Coldplay',       'https://music.apple.com/search?term=Coldplay'),
    ('Sơn Tùng M-TP','VN', 'https://open.spotify.com/search/Son%20Tung%20M-TP', 'https://music.apple.com/search?term=Son%20Tung%20M-TP'),
    ('Đen',          'VN', 'https://open.spotify.com/search/Den%20Vau',      'https://music.apple.com/search?term=Den%20Vau'),
    ('Norah Jones',  'US', 'https://open.spotify.com/search/Norah%20Jones',   'https://music.apple.com/search?term=Norah%20Jones'),
    ('Arctic Monkeys','UK','https://open.spotify.com/search/Arctic%20Monkeys','https://music.apple.com/search?term=Arctic%20Monkeys');

-- Chèn bài hát bằng tên nghệ sĩ/thể loại thay vì ID cứng.
INSERT INTO songs (title, artist_id, genre_id, release_year, duration_sec, spotify_url, apple_music_url)
SELECT s.title, a.id, g.id, s.release_year, s.duration_sec,
       'https://open.spotify.com/search/' || replace(s.title || ' ' || s.artist, ' ', '%20'),
       'https://music.apple.com/search?term=' || replace(s.title || ' ' || s.artist, ' ', '%20')
FROM (VALUES
    ('Love Story',            'Taylor Swift',   'Pop',   2008, 235),
    ('Anti-Hero',             'Taylor Swift',   'Pop',   2022, 200),
    ('Yellow',                'Coldplay',       'Rock',  2000, 269),
    ('Viva La Vida',          'Coldplay',       'Rock',  2008, 242),
    ('Lạc Trôi',              'Sơn Tùng M-TP',  'V-Pop', 2017, 233),
    ('Chúng Ta Của Hiện Tại', 'Sơn Tùng M-TP',  'V-Pop', 2020, 301),
    ('Mang Tiền Về Cho Mẹ',   'Đen',            'V-Pop', 2021, 404),
    ('Don''t Know Why',       'Norah Jones',    'Jazz',  2002, 186),
    ('Do I Wanna Know?',      'Arctic Monkeys', 'Indie', 2013, 272),
    ('505',                   'Arctic Monkeys', 'Indie', 2007, 253)
) AS s(title, artist, genre, release_year, duration_sec)
JOIN artists a ON a.name = s.artist
JOIN genres  g ON g.name = s.genre;

INSERT INTO playlists (name, description) VALUES
    ('Chill buổi tối', 'Nhẹ nhàng để thư giãn'),
    ('Code mode',      'Nghe khi tập trung làm việc'),
    ('Nhạc Việt',      'Các bài V-Pop yêu thích');

INSERT INTO playlist_songs (playlist_id, song_id, position)
SELECT p.id, s.id, x.position
FROM (VALUES
    ('Chill buổi tối', 'Don''t Know Why',        1),
    ('Chill buổi tối', 'Yellow',                 2),
    ('Chill buổi tối', 'Chúng Ta Của Hiện Tại',  3),
    ('Code mode',      'Do I Wanna Know?',       1),
    ('Code mode',      'Viva La Vida',           2),
    ('Code mode',      '505',                    3),
    ('Code mode',      'Anti-Hero',              4),
    ('Nhạc Việt',      'Lạc Trôi',               1),
    ('Nhạc Việt',      'Chúng Ta Của Hiện Tại',  2),
    ('Nhạc Việt',      'Mang Tiền Về Cho Mẹ',    3)
) AS x(playlist, title, position)
JOIN playlists p ON p.name = x.playlist
JOIN songs     s ON s.title = x.title;
