use axum::{
    extract::State,
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use sqlx::{sqlite::SqliteConnectOptions, Pool, Sqlite, Row, migrate};
use tower_http::cors::{CorsLayer, Any};
use std::net::{SocketAddr, TcpListener};
use std::{env, fs, str::FromStr};
use tracing::{info, error, debug};
use directories::ProjectDirs;
use chrono::DateTime;

#[derive(Debug, Serialize)]
struct Card {
    id: i64,
    title: String,
    content: String,
    created_at: DateTime<chrono::Utc>,
}

#[derive(Debug, Deserialize)]
struct CreateCard {
    title: String,
    content: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 初始化日志
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .init();

    info!("Starting server...");
    
    // 获取系统推荐的数据目录
    let project_dirs = ProjectDirs::from("com", "cardmind", "CardMind")
        .ok_or("Failed to get project directories")?;
    
    // 创建并设置数据目录
    let data_dir = project_dirs.data_dir();
    fs::create_dir_all(data_dir)?;
    debug!("Data directory: {}", data_dir.display());
    
    // 设置数据库路径
    let db_path = data_dir.join("cardmind.db");
    debug!("Database path: {}", db_path.display());
    
    // 创建连接选项
    let conn_opts = SqliteConnectOptions::from_str(&format!("sqlite:{}", db_path.display()))?
        .create_if_missing(true)
        .journal_mode(sqlx::sqlite::SqliteJournalMode::Wal)
        .foreign_keys(true);
    
    debug!("Connection options: {:?}", conn_opts);
    
    info!("Connecting to database...");
    let pool = sqlx::SqlitePool::connect_with(conn_opts).await?;
    info!("Database connection established");

    info!("Running database migrations...");
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await?;
    info!("Database migrations completed");

    // 配置 CORS
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/", get(health_check))
        .route("/api/cards", get(list_cards).post(create_card))
        .layer(cors)
        .with_state(pool);

    let addr = SocketAddr::from(([127, 0, 0, 1], 9999));
    info!("Listening on {}", addr);
    
    let listener = TcpListener::bind(addr)?;
    axum::Server::from_tcp(listener)?
        .serve(app.into_make_service())
        .await?;

    Ok(())
}

async fn health_check() -> &'static str {
    "OK"
}

async fn list_cards(
    State(pool): State<Pool<Sqlite>>,
) -> Result<Json<Vec<Card>>, StatusCode> {
    info!("Listing cards...");
    match sqlx::query(
        "SELECT id, title, content, created_at FROM cards ORDER BY created_at DESC"
    )
    .try_map(|row: sqlx::sqlite::SqliteRow| {
        Ok(Card {
            id: row.get("id"),
            title: row.get("title"),
            content: row.get("content"),
            created_at: row.get("created_at"),
        })
    })
    .fetch_all(&pool)
    .await
    {
        Ok(cards) => {
            info!("Found {} cards", cards.len());
            Ok(Json(cards))
        },
        Err(e) => {
            error!("Failed to list cards: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

async fn create_card(
    State(pool): State<Pool<Sqlite>>,
    Json(payload): Json<CreateCard>,
) -> Result<Json<Card>, StatusCode> {
    let now = chrono::Utc::now();
    info!("Creating new card: {}", payload.title);

    match sqlx::query(
        r#"
        INSERT INTO cards (title, content, created_at)
        VALUES (?, ?, ?)
        RETURNING id, title, content, created_at
        "#
    )
    .bind(&payload.title)
    .bind(&payload.content)
    .bind(now)
    .map(|row: sqlx::sqlite::SqliteRow| {
        Card {
            id: row.get("id"),
            title: row.get("title"),
            content: row.get("content"),
            created_at: row.get("created_at"),
        }
    })
    .fetch_one(&pool)
    .await
    {
        Ok(card) => {
            info!("Created card with id: {}", card.id);
            Ok(Json(card))
        },
        Err(e) => {
            error!("Failed to create card: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}
