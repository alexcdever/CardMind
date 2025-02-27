use poem::{
    listener::TcpListener,
    middleware::Cors,
    EndpointExt,
    Route,
    Server,
};
use poem_openapi::OpenApiService;
use tracing::{info, Level};

use cardmind_server::{
    handler::CardHandler,
    config::Config,
    database::DatabasePool,
};

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

    info!("正在启动服务器...");

    // 初始化配置
    let config = Config::init()?;
    
    // 初始化数据库连接池
    let pool = DatabasePool::new().await?;
    
    // 执行数据库迁移
    info!("正在执行数据库迁移...");
    pool.migrate().await?;
    info!("数据库迁移完成");
    
    // 创建 API 服务
    let api_service = OpenApiService::new(CardHandler::new(pool.connection().clone()), "CardMind", "1.0.0")
        .server(format!("http://{}:{}", config.server_host(), config.server_port()));

    // 创建路由
    let app = Route::new()
        .nest("/api/v1", api_service.clone())
        .nest("/docs", api_service.spec_endpoint())
        .with(Cors::new()
            .allow_origin("http://localhost:4000")  // 明确允许前端开发服务器的域名
            .allow_methods(["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"])
            .allow_headers(["*"])
            .allow_credentials(true)  // 允许携带认证信息
            .expose_headers(["*"])
            .max_age(3600)
        );

    // 启动服务器
    let addr = format!("{}:{}", config.server_host(), config.server_port());
    info!("服务器运行在 http://{}", addr);
    
    Server::new(TcpListener::bind(addr))
        .run(app)
        .await?;

    Ok(())
}
