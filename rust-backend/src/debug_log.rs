//! 结构化、脱敏的调试日志（debug-log 任务）。
//!
//! 设计原则：
//! - **结构化事件**：`LogEvent` 一条事件包含时间戳/平台/事件名/阶段/脱敏 device id/
//!   错误链/耗时/额外字段，测试可断言事件字段而不依赖控制台文本。
//! - **可测试 sink**：`LogSink` trait + 测试收集 sink（`CollectingSink`）与异常 sink
//!   （`PanickingSink`）；生产默认 `PlatformSink`。
//! - **脱敏保证**：`redact_device_id` 只允许输出前 8 + 后 8 字符；所有事件构造入口
//!   对 device id 一律先脱敏；`SecretKey` / API key / 配对码 / 笔记正文绝不写入事件。
//! - **不打断主流程**：sink 调用包 `catch_unwind`，日志失败（含 panic）不影响配对/同步。
//! - **debug 开关**：`LogEvent::verbose` 事件默认不输出，`SyncService::set_log_verbose`
//!   打开后输出更多细节（如候选设备列表）。

use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::{Arc, Mutex};

/// 单条结构化日志事件。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LogEvent {
    /// RFC3339 时间戳（UTC）。
    pub timestamp: String,
    /// 平台（`env::consts::OS`；Android 目标为 "android"）。
    pub platform: String,
    /// 事件名（如 "relay.config"、"sync.push"）。
    pub event: String,
    /// 当前阶段（如 "sync.init"、"pairing.accept"）。
    pub stage: String,
    /// 已脱敏的 device id 列表（只允许前 8 + 后 8 字符）。
    pub device_ids: Vec<String>,
    /// 错误类型与消息（成功事件为 None）。
    pub error: Option<String>,
    /// 完整错误链（anyhow `{e:#}`；成功事件为 None）。
    pub error_chain: Option<String>,
    /// 耗时（毫秒）。
    pub duration_ms: Option<u64>,
    /// 额外安全字段（count/direction/transport 等；不得含敏感内容）。
    pub fields: Vec<(String, String)>,
    /// verbose 级事件：默认不输出，`set_log_verbose(true)` 后输出。
    pub verbose: bool,
}

impl Default for LogEvent {
    fn default() -> Self {
        Self {
            timestamp: chrono::Utc::now().to_rfc3339(),
            platform: platform(),
            event: String::new(),
            stage: String::new(),
            device_ids: Vec::new(),
            error: None,
            error_chain: None,
            duration_ms: None,
            fields: Vec::new(),
            verbose: false,
        }
    }
}

impl LogEvent {
    /// 构造事件（时间戳/平台自动填充）。
    pub fn new(event: impl Into<String>, stage: impl Into<String>) -> Self {
        Self {
            event: event.into(),
            stage: stage.into(),
            ..Self::default()
        }
    }

    /// 追加一个 device id（**立即脱敏**——事件里永远只有 8+8 形式）。
    pub fn with_id(mut self, id: &str) -> Self {
        self.device_ids.push(redact_device_id(id));
        self
    }

    pub fn with_error(mut self, error: &str) -> Self {
        self.error = Some(error.to_string());
        self
    }

    pub fn with_chain(mut self, chain: &str) -> Self {
        self.error_chain = Some(chain.to_string());
        self
    }

    pub fn with_duration(mut self, d: std::time::Duration) -> Self {
        self.duration_ms = Some(d.as_millis() as u64);
        self
    }

    pub fn with_field(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.fields.push((key.into(), value.into()));
        self
    }

    pub fn with_verbose(mut self) -> Self {
        self.verbose = true;
        self
    }
}

/// 可测试的日志 sink：测试注入收集 sink 断言事件，不依赖控制台文本。
pub trait LogSink: Send + Sync {
    fn emit(&self, event: LogEvent);
}

/// 默认 sink：同时输出到 `tracing`（结构化）与 `eprintln`（平台调试日志可见；
/// Windows stderr / Android logcat 均能捕获）。
pub struct PlatformSink;

impl LogSink for PlatformSink {
    fn emit(&self, event: LogEvent) {
        let line = format_line(&event);
        // eprintln 保证无 tracing subscriber 时日志仍进入平台调试输出
        eprintln!("{line}");
        // tracing 结构化输出（宿主应用安装了 subscriber 时可见）
        tracing::info!(
            target: "cardmind",
            event = %event.event,
            stage = %event.stage,
            platform = %event.platform,
            device_ids = ?event.device_ids,
            error = ?event.error,
            duration_ms = ?event.duration_ms,
            "cardmind"
        );
    }
}

/// 测试用收集 sink：把事件收集到 Vec 供断言。
pub struct CollectingSink {
    events: Mutex<Vec<LogEvent>>,
}

impl CollectingSink {
    pub fn new() -> Self {
        Self {
            events: Mutex::new(Vec::new()),
        }
    }

    pub fn snapshot(&self) -> Vec<LogEvent> {
        self.events.lock().unwrap().clone()
    }
}

impl Default for CollectingSink {
    fn default() -> Self {
        Self::new()
    }
}

impl LogSink for CollectingSink {
    fn emit(&self, event: LogEvent) {
        self.events.lock().unwrap().push(event);
    }
}

/// 测试用异常 sink：emit 时 panic（验证日志失败不影响主流程）。
pub struct PanickingSink;

impl LogSink for PanickingSink {
    fn emit(&self, _event: LogEvent) {
        panic!("log sink exploded (intentional test failure)");
    }
}

/// 脱敏 device id：只保留前 8 + 后 8 字符，中间省略。
///
/// 短 id（≤ 16 字符）原样返回——整体不超过"前 8 + 后 8"的窗口，无法再脱敏。
pub fn redact_device_id(id: &str) -> String {
    if id.len() <= 16 {
        return id.to_string();
    }
    let mut chars = id.chars();
    let prefix: String = chars.by_ref().take(8).collect();
    let suffix: String = chars
        .rev()
        .take(8)
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .collect();
    format!("{prefix}…{suffix}")
}

/// 当前平台（`env::consts::OS`）。
pub fn platform() -> String {
    std::env::consts::OS.to_string()
}

/// 全局兜底 sink（SyncService 构造之前的事件，如启动失败）。
static GLOBAL_SINK: Mutex<Option<Arc<dyn LogSink>>> = Mutex::new(None);

/// 设置/清除全局兜底 sink（测试钩子；生产不调用）。
pub fn set_global_sink(sink: Option<Arc<dyn LogSink>>) {
    *GLOBAL_SINK.lock().unwrap() = sink;
}

/// 向指定 sink 输出事件；sink 调用包 `catch_unwind`——日志失败（含 panic）
/// 绝不打断配对/同步主流程。
pub fn emit_to(sink: &Arc<dyn LogSink>, event: LogEvent) {
    let sink = sink.clone();
    let _ = catch_unwind(AssertUnwindSafe(move || sink.emit(event)));
}

/// 输出事件到全局兜底 sink（默认 PlatformSink；测试可注入收集 sink）。
pub fn emit_global(event: LogEvent) {
    let sink = GLOBAL_SINK
        .lock()
        .unwrap()
        .clone()
        .unwrap_or_else(|| Arc::new(PlatformSink));
    emit_to(&sink, event);
}

/// 单行格式化（人类可读的调试日志）。
fn format_line(event: &LogEvent) -> String {
    let mut s = format!(
        "[cardmind:log] {} platform={} event={} stage={}",
        event.timestamp, event.platform, event.event, event.stage
    );
    if !event.device_ids.is_empty() {
        s.push_str(&format!(" ids=[{}]", event.device_ids.join(",")));
    }
    if let Some(e) = &event.error {
        s.push_str(&format!(" error={e}"));
    }
    if let Some(c) = &event.error_chain {
        s.push_str(&format!(" chain={c}"));
    }
    if let Some(d) = event.duration_ms {
        s.push_str(&format!(" duration_ms={d}"));
    }
    for (k, v) in &event.fields {
        s.push_str(&format!(" {k}={v}"));
    }
    s
}
