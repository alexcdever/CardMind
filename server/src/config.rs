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
        // 如果已经初始化过，直接返回全局实例
        if GLOBAL_CONFIG.get().is_some() {
            return Ok(Self::global());
        }

        // 加载配置优先级：
        // 1. 系统环境变量
        // 2. .env 文件（如果系统环境变量不存在）
        dotenv::dotenv().ok();

        // 获取默认配置
        let mut config = Self::default();

        // 从环境变量覆盖配置
        if let Ok(host) = env::var("SERVER_HOST") {
            config.server_host = host;
        }

        if let Ok(port_str) = env::var("SERVER_PORT") {
            config.server_port = port_str.parse()
                .map_err(|_| ConfigError::InvalidPort)?;
        }

        if let Ok(data_dir) = env::var("DATA_DIR") {
            config.data_dir = PathBuf::from(data_dir);
        }

        // 创建数据目录
        fs::create_dir_all(&config.data_dir)
            .map_err(|e| ConfigError::IoError(format!("无法创建数据目录：{}", e)))?;

        // 获取部署模式
        if let Ok(mode) = env::var("DEPLOYMENT_MODE") {
            config.is_center_server = mode == "center";
        }

        // 如果是中心服务器模式，获取PostgreSQL连接URL
        if config.is_center_server {
            config.postgres_url = Some(env::var("POSTGRES_URL").map_err(|_| {
                ConfigError::MissingEnv("中心服务器模式需要设置POSTGRES_URL环境变量".to_string())
            })?);
        }

        // 设置全局配置
        GLOBAL_CONFIG
            .set(config)
            .map_err(|_| ConfigError::AlreadyInitialized)?;

        Ok(Self::global())
    }

    /// 返回一个使用默认值的配置实例
    pub fn default() -> Self {
        // 获取可执行文件所在目录，并在其下创建data目录
        let data_dir = env::current_exe()
            .map(|exe_path| exe_path.parent().unwrap_or(Path::new(".")).to_path_buf())
            .unwrap_or_else(|_| PathBuf::from("."))
            .join("data");

        Self {
            server_host: "0.0.0.0".to_string(),
            server_port: 9000,
            data_dir,
            is_center_server: false,
            postgres_url: None,
        }
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
