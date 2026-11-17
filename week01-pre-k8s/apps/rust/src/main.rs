use std::env;

use axum::{
    extract::{Path, State},
    http::{header, StatusCode},
    response::{IntoResponse, Response},
    routing::get,
    Router,
};
use redis::{aio::ConnectionManager, AsyncCommands};
use serde::Serialize;
use sqlx::{postgres::PgPoolOptions, FromRow, PgPool};

// Giữ nguyên câu SELECT của Node (apps/api) để JSON trả ra giống hệt.
const SONG_SELECT: &str = "
  SELECT s.id, s.title, s.release_year, s.duration_sec, s.spotify_url, s.apple_music_url,
         a.id AS artist_id, a.name AS artist, g.name AS genre
  FROM songs s
  JOIN artists a ON a.id = s.artist_id
  LEFT JOIN genres g ON g.id = s.genre_id";

// Cache sống 60 giây: seed gần như không đổi, hết hạn thì tự đọc lại Postgres.
const CACHE_TTL_SECS: u64 = 60;

// Thứ tự field = thứ tự key trong JSON (khớp với Node). Option<T> -> null khi cột NULL.
#[derive(Serialize, FromRow)]
struct Song {
    id: i32,
    title: String,
    release_year: Option<i16>,
    duration_sec: Option<i32>,
    spotify_url: Option<String>,
    apple_music_url: Option<String>,
    artist_id: i32,
    artist: String,
    genre: Option<String>,
}

// State dùng chung cho mọi request (clone rẻ: bên trong là Arc).
#[derive(Clone)]
struct AppState {
    db: PgPool,
    redis: ConnectionManager,
}

fn json(body: String) -> Response {
    ([(header::CONTENT_TYPE, "application/json")], body).into_response()
}

fn internal<E: std::fmt::Display>(err: E) -> StatusCode {
    eprintln!("error: {err}");
    StatusCode::INTERNAL_SERVER_ERROR
}

// Redis lỗi/chết thì coi như cache miss, không làm hỏng request.
async fn cache_get(st: &AppState, key: &str) -> Option<String> {
    let mut conn = st.redis.clone();
    match conn.get::<_, Option<String>>(key).await {
        Ok(v) => v,
        Err(e) => {
            eprintln!("redis get {key}: {e}");
            None
        }
    }
}

async fn cache_set(st: &AppState, key: &str, body: &str) {
    let mut conn = st.redis.clone();
    if let Err(e) = conn.set_ex::<_, _, ()>(key, body, CACHE_TTL_SECS).await {
        eprintln!("redis set {key}: {e}");
    }
}

async fn health(State(st): State<AppState>) -> Result<Response, StatusCode> {
    sqlx::query("SELECT 1")
        .execute(&st.db)
        .await
        .map_err(internal)?;
    Ok(json(r#"{"status":"ok"}"#.to_string()))
}

async fn list_songs(State(st): State<AppState>) -> Result<Response, StatusCode> {
    let key = "songs:all";
    if let Some(body) = cache_get(&st, key).await {
        println!("cache hit {key}");
        return Ok(json(body));
    }
    println!("cache miss {key}");

    let sql = format!("{SONG_SELECT} ORDER BY a.name, s.title");
    let songs: Vec<Song> = sqlx::query_as(&sql)
        .fetch_all(&st.db)
        .await
        .map_err(internal)?;
    let body = serde_json::to_string(&songs).map_err(internal)?;
    cache_set(&st, key, &body).await;
    Ok(json(body))
}

async fn get_song(
    State(st): State<AppState>,
    Path(id): Path<i32>,
) -> Result<Response, StatusCode> {
    let key = format!("songs:{id}");
    if let Some(body) = cache_get(&st, &key).await {
        println!("cache hit {key}");
        return Ok(json(body));
    }
    println!("cache miss {key}");

    let sql = format!("{SONG_SELECT} WHERE s.id = $1");
    let song: Option<Song> = sqlx::query_as(&sql)
        .bind(id)
        .fetch_optional(&st.db)
        .await
        .map_err(internal)?;
    // Không có bài thì 404 và không cache.
    let song = song.ok_or(StatusCode::NOT_FOUND)?;
    let body = serde_json::to_string(&song).map_err(internal)?;
    cache_set(&st, &key, &body).await;
    Ok(json(body))
}

// Docker/K8s dừng container bằng SIGTERM: bắt tín hiệu để tắt êm thay vì bị kill sau 10s.
async fn shutdown_signal() {
    let mut term = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        .expect("cannot install SIGTERM handler");
    tokio::select! {
        _ = term.recv() => {},
        _ = tokio::signal::ctrl_c() => {},
    }
}

fn env_or(key: &str, default: &str) -> String {
    env::var(key).unwrap_or_else(|_| default.to_string())
}

#[tokio::main]
async fn main() {
    let db_url = format!(
        "postgres://{}:{}@{}:{}/{}",
        env_or("POSTGRES_USER", "music"),
        env_or("POSTGRES_PASSWORD", ""),
        env_or("PGHOST", "postgres"),
        env_or("PGPORT", "5432"),
        env_or("POSTGRES_DB", "music"),
    );
    let db = PgPoolOptions::new()
        .max_connections(5)
        .connect(&db_url)
        .await
        .expect("cannot connect to Postgres");

    let redis_client = redis::Client::open(env_or("REDIS_URL", "redis://redis:6379"))
        .expect("invalid REDIS_URL");
    // ConnectionManager tự kết nối lại khi Redis rớt rồi quay lại.
    let redis = ConnectionManager::new(redis_client)
        .await
        .expect("cannot connect to Redis");

    let app = Router::new()
        .route("/health", get(health))
        .route("/api/songs", get(list_songs))
        .route("/api/songs/:id", get(get_song))
        .with_state(AppState { db, redis });

    let port = env_or("PORT", "8080");
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{port}"))
        .await
        .expect("cannot bind port");
    println!("Rust songs service listening on :{port}");
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .expect("server error");
}
