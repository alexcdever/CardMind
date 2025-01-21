use axum::{
    routing::{get, post},
    Router,
    Json,
    http::StatusCode,
    extract::State,
};
use tower_http::cors::{CorsLayer, Any};
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
use std::env;

#[derive(Debug, Serialize)]
struct ApiResponse<T> {
    success: bool,
    data: Option<T>,
    message: Option<String>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 加载环境变量
    dotenv::dotenv().ok();
    
    // 初始化日志
    tracing_subscriber::fmt::init();

    // 初始化数据库连接
    let database_url = env::var("DATABASE_URL").unwrap_or_else(|_| "sqlite:data.db".to_string());
    let pool = SqlitePool::connect(&database_url).await?;

    // 运行数据库迁移
    sqlx::migrate!("./migrations").run(&pool).await?;

    // 创建路由
    let app = Router::new()
        .route("/", get(health_check))
        .route("/api/cards", get(list_cards))
        .route("/api/cards", post(create_card))
        .layer(
            CorsLayer::new()
                .allow_origin(Any)
                .allow_methods(Any)
                .allow_headers(Any),
        )
        .with_state(pool);

    // 获取服务器配置
    let host = env::var("HOST").unwrap_or_else(|_| "127.0.0.1".to_string());
    let port = env::var("PORT").unwrap_or_else(|_| "3001".to_string());
    let addr = format!("{}:{}", host, port);

    // 启动服务器
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    tracing::info!("Server running on http://{}", addr);
    
    axum::serve(listener, app).await?;
    Ok(())
}

// 健康检查接口
async fn health_check() -> Json<ApiResponse<&'static str>> {
    Json(ApiResponse {
        success: true,
        data: Some("OK"),
        message: None,
    })
}

// 列出所有卡片
async fn list_cards(
    State(pool): State<SqlitePool>
) -> Result<Json<ApiResponse<Vec<Card>>>, StatusCode> {
    match sqlx::query_as!(
        Card,
        "SELECT * FROM cards ORDER BY created_at DESC"
    )
    .fetch_all(&pool)
    .await {
        Ok(cards) => Ok(Json(ApiResponse {
            success: true,
            data: Some(cards),
            message: None,
        })),
        Err(_) => Err(StatusCode::INTERNAL_SERVER_ERROR),
    }
}

// 创建新卡片
async fn create_card(
    State(pool): State<SqlitePool>,
    Json(payload): Json<CreateCardRequest>,
) -> Result<(StatusCode, Json<ApiResponse<Card>>), StatusCode> {
    let now = chrono::Utc::now();
    
    match sqlx::query_as!(
        Card,
        r#"
        INSERT INTO cards (title, content, created_at)
        VALUES (?, ?, ?)
        RETURNING *
        "#,
        payload.title,
        payload.content,
        now,
    )
    .fetch_one(&pool)
    .await {
        Ok(card) => Ok((
            StatusCode::CREATED,
            Json(ApiResponse {
                success: true,
                data: Some(card),
                message: None,
            }),
        )),
        Err(_) => Err(StatusCode::INTERNAL_SERVER_ERROR),
    }
}

#[derive(Debug, Serialize, sqlx::FromRow)]
struct Card {
    id: i64,
    title: String,
    content: String,
    created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Deserialize)]
struct CreateCardRequest {
    title: String,
    content: String,
}
