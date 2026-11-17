package com.music.playlist_service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class PlaylistController {
    private final JdbcTemplate jdbc;

    public PlaylistController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/api/playlists")
    public List<Map<String, Object>> list() {
        return jdbc.queryForList("""
            SELECT p.id, p.name, p.description, count(ps.song_id)::int AS song_count
            FROM playlists p
            LEFT JOIN playlist_songs ps ON ps.playlist_id = p.id
            GROUP BY p.id ORDER BY p.id
            """);
    }

    @GetMapping("/api/playlists/{id}")
    public Map<String, Object> detail(@PathVariable int id) {
        List<Map<String, Object>> found = jdbc.queryForList(
            "SELECT id, name, description FROM playlists WHERE id = ?", id);
        if (found.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }

        List<Map<String, Object>> songs = jdbc.queryForList("""
            SELECT s.id, s.title, s.release_year, s.duration_sec, s.spotify_url, s.apple_music_url,
                   a.id AS artist_id, a.name AS artist, g.name AS genre
            FROM songs s
            JOIN artists a ON a.id = s.artist_id
            LEFT JOIN genres g ON g.id = s.genre_id
            JOIN playlist_songs ps ON ps.song_id = s.id
            WHERE ps.playlist_id = ?
            ORDER BY ps.position
            """, id);

        Map<String, Object> result = new LinkedHashMap<>(found.get(0));
        result.put("songs", songs);
        return result;
    }
}
//trigger ci builds