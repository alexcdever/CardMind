//! HTTP 入口适配器 - REST API 服务端
//!
//! 核心职责：
//! - 提供本机 loopback HTTP REST API
//! - 供外部工具/脚本与 CardMind 集成
//! - 默认监听 127.0.0.1（本地安全）
//!
//! # 安全警告
//! HTTP 服务器仅绑定到 loopback 接口（127.0.0.1），不暴露给局域网/公网。
//! 这是有意设计的安全边界，防止未授权访问。
//!
//! # 配置
//! 通过后端配置启用/禁用（`http_enabled`）：
//! - 生产环境：通常禁用
//! - 开发环境：可启用便于调试
//!
//! # TODO
//! 当前为占位实现，完整 API 将在后续迭代中实现。
//!
//! # Examples
//! ```rust,ignore
//! use cardmind_rust::http::start_loopback_server;
//! use cardmind_rust::application::backend_service::BackendService;
//! use std::sync::Arc;
//!
//! #[tokio::main]
//! async fn main() {
//!     let service = Arc::new(BackendService::new("/data").unwrap());
//!     let handle = start_loopback_server(service).await.unwrap();
//!     println!("HTTP 服务运行在: {}", handle.local_addr());
//! }
//! ```

use crate::application::backend_service::BackendService;
use std::net::SocketAddr;
use std::sync::Arc;

/// HTTP 服务器句柄
///
/// 包含服务器本地地址，可用于连接到服务。
/// 当句柄被丢弃时，服务器会继续运行直到进程结束。
pub struct HttpServerHandle {
    local_addr: SocketAddr,
}

impl HttpServerHandle {
    /// 获取服务器本地监听地址。
    ///
    /// # 返回
    /// 服务器绑定的本地套接字地址（IP + 端口）。
    ///
    /// # 示例
    /// ```rust,ignore
    /// use cardmind_rust::http::start_loopback_server;
    /// use cardmind_rust::application::backend_service::BackendService;
    /// use std::sync::Arc;
    ///
    /// #[tokio::main]
    /// async fn main() {
    ///     let service = Arc::new(BackendService::new("/data").unwrap());
    ///     let handle = start_loopback_server(service).await.unwrap();
    ///     println!("服务地址: {}", handle.local_addr());
    /// }
    /// ```
    pub fn local_addr(&self) -> SocketAddr {
        self.local_addr
    }
}

/// 启动本机 loopback HTTP 服务器。
///
/// 创建一个绑定到 127.0.0.1 的 HTTP 服务器。目前为占位实现，
/// 返回一个包含默认地址的句柄。
///
/// # 参数
/// * `_service` - 后端服务实例，用于处理 HTTP 请求。
///
/// # 返回
/// * `Ok(HttpServerHandle)` - 服务器启动成功，返回服务器句柄。
/// * `Err(CardMindError)` - 地址解析或绑定失败时返回错误。
///
/// # 错误
/// 可能返回以下错误：
/// * `CardMindError::Io` - 当地址解析失败时。
///
/// # 示例
/// ```rust,ignore
/// use cardmind_rust::http::start_loopback_server;
/// use cardmind_rust::application::backend_service::BackendService;
/// use std::sync::Arc;
///
/// #[tokio::main]
/// async fn main() {
///     let service = Arc::new(BackendService::new("/data").unwrap());
///     match start_loopback_server(service).await {
///         Ok(handle) => println!("HTTP 服务启动于: {}", handle.local_addr()),
///         Err(e) => eprintln!("启动失败: {}", e),
///     }
/// }
/// ```
///
/// # TODO
/// 实际 HTTP 路由与请求处理逻辑待实现。
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
