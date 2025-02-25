use poem::{
    listener::TcpListener,
    middleware::Cors,
    EndpointExt,
    Route,
    Server,
};
use poem_openapi::OpenApiService;
use std::env;
use tracing::{info, Level};

mod api;
mod database;
mod entity;

use api::CardApi;
use database::DatabasePool;

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

    // 获取部署模式
    let deployment_mode = env::var("DEPLOYMENT_MODE").unwrap_or_else(|_| "desktop".to_string());
    
    // 获取数据目录（仅在 desktop 模式下需要）
    let data_dir = if deployment_mode == "desktop" {
        Some(env::current_dir()?.join("data"))
    } else {
        None
    };

    // 初始化数据库连接池
    let pool = DatabasePool::new(&deployment_mode, data_dir).await?;
    
    // 执行数据库迁移
    info!("Running database migrations...");
    pool.migrate().await?;
    info!("Database migrations completed");
    
    // 创建 API 服务
    let api_service = OpenApiService::new(CardApi::new(pool.get_connection().clone()), "CardMind", "1.0.0")
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
    
    info!("Server running at http://{}", addr);
      
    Server::new(TcpListener::bind(addr))
        .run(app)
        .await?;

    Ok(())
}
