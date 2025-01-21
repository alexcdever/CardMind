use axum::{
    extract::State,
    http::StatusCode,
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use sqlx::{Pool, Sqlite, Row};
use tower_http::cors::{CorsLayer, Any};
use std::net::{SocketAddr, TcpListener};
use tracing::{info, error};

#[derive(Debug, Serialize)]
struct Card {
    id: i64,
    title: String,
    content: String,
    created_at: chrono::DateTime<chrono::Utc>,
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
        .with_env_filter("debug")
        .init();

    info!("Starting server...");
    
    // 使用内存数据库
    let database_url = "sqlite::memory:";
    info!("Connecting to database: {}", database_url);
    let pool = sqlx::SqlitePool::connect(database_url).await?;

    info!("Creating cards table...");
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS cards (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at DATETIME NOT NULL
        )
        "#,
    )
    .execute(&pool)
    .await?;

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
