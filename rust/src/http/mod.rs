// HTTP 入口模块
// 本机 loopback HTTP API 适配器

use crate::application::backend_service::BackendService;
use std::net::SocketAddr;
use std::sync::Arc;

/// HTTP 服务器句柄
pub struct HttpServerHandle {
    local_addr: SocketAddr,
}

impl HttpServerHandle {
    pub fn local_addr(&self) -> SocketAddr {
        self.local_addr
    }
}

/// 启动本机 loopback HTTP 服务器
pub async fn start_loopback_server(
    _service: Arc<BackendService>,
) -> Result<HttpServerHandle, crate::models::error::CardMindError> {
    // 第一阶段：仅创建占位实现
    // 实际 HTTP 服务器实现将在后续迭代中添加
    let addr: SocketAddr = "127.0.0.1:0"
        .parse()
        .map_err(|e| crate::models::error::CardMindError::Io(format!("Invalid address: {}", e)))?;

    // TODO: 实现实际的 HTTP 服务器启动逻辑
    // 目前返回占位句柄
    Ok(HttpServerHandle { local_addr: addr })
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[tokio::test]
    async fn http_server_starts_with_loopback_address() {
        let dir = TempDir::new().unwrap();
        let service = Arc::new(BackendService::new(dir.path().to_str().unwrap()).unwrap());

        let handle = start_loopback_server(service).await.unwrap();

        // 验证地址是 loopback
        assert!(handle.local_addr().ip().is_loopback());
    }
}
