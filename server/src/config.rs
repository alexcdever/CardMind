use std::env;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::fs;
use std::error::Error as StdError;
use std::fmt;

/// 全局配置单例
static GLOBAL_CONFIG: OnceLock<Config> = OnceLock::new();

/// 配置结构体
#[derive(Debug, Clone)]
pub struct Config {
    /// 服务器配置
    server_host: String,
    server_port: u16,
    /// 数据目录
    data_dir: PathBuf,
    /// 部署模式
    is_center_server: bool,
    /// PostgreSQL连接URL（仅中心服务器模式）
    postgres_url: Option<String>,
}

impl Config {
    /// 初始化全局配置
    pub fn init() -> Result<&'static Self, ConfigError> {
        if GLOBAL_CONFIG.get().is_some() {
            return Ok(Self::global());
        }

        // 加载.env文件（如果存在）
        dotenv::dotenv().ok();

        // 获取服务器配置
        let server_host = env::var("SERVER_HOST").unwrap_or_else(|_| "127.0.0.1".to_string());
        let server_port = env::var("SERVER_PORT")
            .unwrap_or_else(|_| "8080".to_string())
            .parse()
            .map_err(|_| ConfigError::InvalidPort)?;

        // 获取数据目录
        let data_dir = env::var("DATA_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|_| {
                if cfg!(debug_assertions) {
                    env::current_dir()
                        .map(|d| d.join("data"))
                        .unwrap_or_else(|_| PathBuf::from("data"))
                } else {
                    dirs::data_dir()
                        .unwrap_or_else(|| PathBuf::from("/var/lib"))
                        .join("cardmind")
                }
            });

        // 创建数据目录
        fs::create_dir_all(&data_dir)
            .map_err(|e| ConfigError::IoError(format!("无法创建数据目录：{}", e)))?;

        // 获取部署模式
        let is_center_server = env::var("DEPLOYMENT_MODE")
            .map(|mode| mode == "center")
            .unwrap_or(false);

        // 获取PostgreSQL连接URL（仅中心服务器模式）
        let postgres_url = if is_center_server {
            Some(env::var("POSTGRES_URL").map_err(|_| {
                ConfigError::MissingEnv("中心服务器模式需要设置POSTGRES_URL环境变量".to_string())
            })?)
        } else {
            None
        };

        // 创建并设置全局配置
        let config = Config {
            server_host,
            server_port,
            data_dir,
            is_center_server,
            postgres_url,
        };

        GLOBAL_CONFIG
            .set(config)
            .map_err(|_| ConfigError::AlreadyInitialized)?;

        Ok(Self::global())
    }

    /// 获取全局配置实例
    pub fn global() -> &'static Self {
        GLOBAL_CONFIG.get().expect("配置未初始化")
    }

    /// 获取服务器地址
    pub fn server_addr(&self) -> String {
        format!("{}:{}", self.server_host, self.server_port)
    }

    /// 获取服务器主机名
    pub fn server_host(&self) -> &str {
        &self.server_host
    }

    /// 获取服务器端口
    pub fn server_port(&self) -> u16 {
        self.server_port
    }

    /// 获取数据目录
    pub fn data_dir(&self) -> &Path {
        &self.data_dir
    }

    /// 是否为中心服务器模式
    pub fn is_center_server(&self) -> bool {
        self.is_center_server
    }

    /// 获取PostgreSQL连接URL
    pub fn postgres_url(&self) -> Option<&str> {
        self.postgres_url.as_deref()
    }
}

/// 配置错误类型
#[derive(Debug)]
pub enum ConfigError {
    /// 环境变量缺失
    MissingEnv(String),
    /// 无效的端口号
    InvalidPort,
    /// 无效的值
    InvalidValue(String),
    /// 配置已初始化
    AlreadyInitialized,
    /// IO错误
    IoError(String),
}

impl fmt::Display for ConfigError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ConfigError::MissingEnv(msg) => write!(f, "环境变量缺失: {}", msg),
            ConfigError::InvalidPort => write!(f, "无效的端口号"),
            ConfigError::InvalidValue(msg) => write!(f, "无效的值: {}", msg),
            ConfigError::AlreadyInitialized => write!(f, "配置已初始化"),
            ConfigError::IoError(msg) => write!(f, "IO错误: {}", msg),
        }
    }
}

impl StdError for ConfigError {}
