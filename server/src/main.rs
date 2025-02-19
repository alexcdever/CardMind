use poem::{
    listener::TcpListener,
    middleware::Cors,
    EndpointExt,
    Route,
    Server,
};
use poem_openapi::OpenApiService;
use sea_orm::Database;
use std::env;
use tracing::{info, Level};

mod api;
mod entity;

use api::CardApi;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 初始化日志
    tracing_subscriber::fmt()
        .with_max_level(Level::INFO)
        .with_target(false)
        .with_thread_ids(false)
        .with_file(false)
        .with_line_number(false)
        .compact()
        .init();

    info!("Starting server...");

    // 获取数据库 URL
    let database_url = env::var("DATABASE_URL").unwrap_or_else(|_| {
        if env::var("DEPLOYMENT_MODE").unwrap_or_default() == "web" {
            "postgres://cardmind:changeme@db:5432/cardmind".to_string()
        } else {
            "sqlite::memory:".to_string()
        }
    });

    // 连接数据库
    let db = Database::connect(&database_url).await?;
    
    // 创建 API 服务
    let api_service = OpenApiService::new(CardApi::new(db.clone()), "CardMind", "1.0.0")
        .server("http://localhost:3002/api");
    let docs_service = api_service.swagger_ui();
    
    // 创建路由
    let app = Route::new()
        .nest("/api", api_service)
        .nest("/docs", docs_service)
        .with(Cors::new());

    // 启动服务器
    let host = env::var("HOST").unwrap_or_else(|_| "0.0.0.0".to_string());
    let port = env::var("PORT").unwrap_or_else(|_| "3002".to_string());
    let addr = format!("{}:{}", host, port);
    
    info!("Server starting on http://{}", addr);
    info!("API documentation available at http://{}/docs", addr);
    
    Server::new(TcpListener::bind(addr))
        .run(app)
        .await?;

    Ok(())
}
