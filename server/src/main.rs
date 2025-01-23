use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::{get, post, delete},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use sqlx::{sqlite::SqliteConnectOptions, Pool, Sqlite};
use tower_http::cors::CorsLayer;
use std::net::SocketAddr;
use tokio::net::TcpListener;
use std::str::FromStr;
use tracing::{info, error, debug};
use directories::ProjectDirs;
use std::time::Duration;

#[derive(Debug, Serialize, sqlx::FromRow)]
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
        .with_max_level(tracing::Level::DEBUG)
        .init();

    info!("Starting server...");
    
    // 获取系统推荐的数据目录
    let project_dirs = ProjectDirs::from("com", "cardmind", "CardMind")
        .ok_or("Failed to get project directories")?;
    
    // 创建并设置数据目录
    let data_dir = project_dirs.data_dir();
    std::fs::create_dir_all(data_dir)?;
    debug!("Data directory: {}", data_dir.display());
    
    // 设置数据库路径
    let db_path = data_dir.join("cardmind.db");
    debug!("Database path: {}", db_path.display());
    
    // 创建连接选项
    let conn_opts = SqliteConnectOptions::from_str(&format!("sqlite:{}", db_path.display()))?
        .create_if_missing(true)
        .journal_mode(sqlx::sqlite::SqliteJournalMode::Wal)
        .foreign_keys(true);

    info!("Connecting to database...");
    let pool = sqlx::SqlitePool::connect_with(conn_opts).await?;
    info!("Database connection established");

    // 运行数据库迁移
    info!("Running database migrations...");
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await?;
    info!("Database migrations completed");

    // 配置 CORS
    let cors = CorsLayer::new()
        .allow_origin(["http://localhost:3001".parse().unwrap()])
        .allow_methods([
            axum::http::Method::GET,
            axum::http::Method::POST,
            axum::http::Method::PUT,
            axum::http::Method::DELETE,
        ])
        .allow_headers([
            axum::http::header::CONTENT_TYPE,
            axum::http::header::ACCEPT,
        ])
        .max_age(Duration::from_secs(3600));

    // 创建路由
    let app = Router::new()
        .route("/api/cards", get(get_cards))
        .route("/api/cards", post(create_card))
        .route("/api/cards/:id", delete(delete_card))
        .layer(cors)
        .with_state(pool);

    // 创建监听器
    let addr = SocketAddr::from(([0, 0, 0, 0], 9999));
    let listener = TcpListener::bind(addr).await?;
    info!("Listening on {}", addr);

    axum::serve(listener, app).await?;

    Ok(())
}

async fn get_cards(
    State(pool): State<Pool<Sqlite>>,
) -> Result<Json<Vec<Card>>, (StatusCode, String)> {
    let cards = sqlx::query_as::<_, Card>(
        "SELECT id, title, content, created_at FROM cards ORDER BY created_at DESC"
    )
    .fetch_all(&pool)
    .await
    .map_err(|e| {
        error!("Failed to fetch cards: {}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to fetch cards: {}", e))
    })?;

    Ok(Json(cards))
}

async fn create_card(
    State(pool): State<Pool<Sqlite>>,
    Json(payload): Json<CreateCard>,
) -> Result<Json<Card>, (StatusCode, String)> {
    let card = sqlx::query_as::<_, Card>(
        "INSERT INTO cards (title, content, created_at) VALUES (?, ?, CURRENT_TIMESTAMP) RETURNING *"
    )
    .bind(&payload.title)
    .bind(&payload.content)
    .fetch_one(&pool)
    .await
    .map_err(|e| {
        error!("Failed to create card: {}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to create card: {}", e))
    })?;

    Ok(Json(card))
}

async fn delete_card(
    State(pool): State<Pool<Sqlite>>,
    Path(id): Path<i64>,
) -> Result<StatusCode, (StatusCode, String)> {
    sqlx::query("DELETE FROM cards WHERE id = ?")
        .bind(id)
        .execute(&pool)
        .await
        .map_err(|e| {
            error!("Failed to delete card: {}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to delete card: {}", e))
        })?;

    Ok(StatusCode::NO_CONTENT)
}
