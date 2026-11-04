use cardmind_backend::sync::SYNC_POLL_INTERVAL_SECS;
use nsh_core::prelude::*;

use crate::backend::dto::{DevicePushResultDto, SyncCycleResultDto};
use crate::backend::globals::{SYNC, ensure_sync, store};

// ━━━ 施工方案 1.2：Backend.Sync ━━━
//
// 同步服务生命周期 / 开关 / cycle / receiver。状态在 `SyncService` 单例；
// `create_sync_service` 把「惰性建」显式化（等价于首次 `ensure_sync`）。
/// Sync service lifecycle / switches / cycle / receiver，exported to TSX as `BackendSync.*`。
///
/// `Result<bool, String>` 的 `Ok(true)` = 无返回值操作成功。
#[module]
pub struct BackendSync;

// Sync service lifecycle / switches / cycle / receiver，TSX 侧 `BackendSync.*`。
//
// `Result<bool, String>` 的 `Ok(true)` = 无返回值操作成功。
#[module]
impl BackendSync {
    /// 创建（或返回已创建的）全局 `SyncService`（内存版：不写数据目录）。
    /// 返回 device_id 供调用方确认服务已就绪。
    pub async fn create_sync_service() -> Result<String, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.device_id())
    }

    /// 设置同步开关（决策 6 能力）：false 时调度器暂停推送与拉取。
    /// 移动端由 UI 侧按网络类型（WiFi vs 蜂窝）调用；桌面端恒 true。
    pub async fn set_sync_allowed(allowed: bool) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.set_sync_allowed(allowed);
        Ok(true)
    }

    /// 当前同步开关状态。
    pub async fn get_sync_allowed() -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.sync_allowed())
    }

    /// 待同步笔记计数（模块 5 基础）。
    pub async fn pending_sync_count() -> Result<u32, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.pending_sync_count())
    }

    /// 周期拉取间隔（秒）——UI 侧 Timer 周期用。
    pub fn sync_poll_interval_secs() -> u32 {
        SYNC_POLL_INTERVAL_SECS as u32
    }

    /// 推送待办（编辑保存即推送）：向所有配对设备推全量快照。
    /// 失败静默（决策 18）：返回每台设备结果，不抛错。
    pub async fn push_pending() -> Result<Vec<DevicePushResultDto>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let results = svc.push_pending(store()?).await;
        Ok(results.iter().map(DevicePushResultDto::from).collect())
    }

    /// 周期同步任务体：push 给所有对端 + 短窗口 accept 对端 push + 刷新 SQLite 投影。
    pub async fn run_sync_cycle() -> Result<SyncCycleResultDto, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let result = svc
            .run_sync_cycle(store()?)
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(SyncCycleResultDto::from(&result))
    }

    /// 启动被动接收任务（幂等）：持续短窗口 accept 对端 push，收到即
    /// import → 刷新 SQLite 投影 → 更新发送方 last_seen。
    /// 接收任务持有 `endpoint.clone()` + 共享 core + `store.clone()`。
    pub async fn start_receiver() -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.start_receiver(store()?.clone())
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 停止被动接收任务（幂等；3 秒内返回）。
    pub async fn stop_receiver() -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.stop_receiver().await.map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 接收任务是否运行中（诊断/测试用）。
    pub async fn receiver_running() -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.receiver_running())
    }

    /// Monotonic revision of successfully projected inbound receiver content.
    pub async fn receiver_content_revision() -> Result<u32, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        Ok(svc.receiver_content_revision() as u32)
    }

    /// 推送到指定对端。
    pub async fn push_to_peer(peer_id: String, ips: Vec<String>) -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        svc.push_to_peer(&peer_id, ips)
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 接受对端推送（返回原始字节）。
    pub async fn accept_push() -> Result<Vec<u32>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let bytes = svc.accept_push().await.map_err(|e| format!("{e:#}"))?;
        Ok(bytes.into_iter().map(u32::from).collect())
    }

    /// 向多台设备逐个推送全量快照（含墓碑），返回每台设备的结果。
    /// `devices`: `(peer_id, Option<IP 列表>)`；IP 缺省时经 relay/地址解析尝试。
    pub async fn push_to_devices(
        devices: Vec<Vec<String>>,
    ) -> Result<Vec<DevicePushResultDto>, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        // 简化编码：TSX 侧每项 `[peer_id, ip0, ip1, ...]`；空数组 = 仅 peer_id。
        let parsed: Vec<(String, Option<Vec<String>>)> = devices
            .into_iter()
            .map(|row| {
                let mut it = row.into_iter();
                let peer_id = it.next().unwrap_or_default();
                let ips: Vec<String> = it.collect();
                (peer_id, if ips.is_empty() { None } else { Some(ips) })
            })
            .collect();
        let results = svc.push_to_paired_devices(&parsed).await;
        Ok(results.iter().map(DevicePushResultDto::from).collect())
    }

    /// 对已配对设备执行有界轻量健康检查，成功时更新 last_seen；返回 last_seen ms。
    pub async fn check_device_connectivity(peer_id: String) -> Result<u32, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let peer_ips = store()?
            .paired_device_ips(&peer_id)
            .map_err(|e| format!("{e:#}"))?;
        let ms = svc
            .check_connectivity(store()?, &peer_id, peer_ips)
            .await
            .map_err(|e| format!("{e:#}"))?;
        Ok(ms as u32)
    }

    /// 接受对端推送并导入（首次全量同步接收端；配对成功后发起方调用）。
    pub async fn accept_push_and_import() -> Result<bool, String> {
        let guard = ensure_sync().await?;
        let svc = guard
            .as_ref()
            .ok_or_else(|| "SyncService 初始化后仍为空".to_owned())?;
        let data = svc.accept_push().await.map_err(|e| format!("{e:#}"))?;
        svc.import_all(&data).map_err(|e| format!("{e:#}"))?;
        Ok(true)
    }

    /// 优雅退出（施工方案 1.6）：先 `stop_receiver()` 再 `endpoint.close()`，
    /// 并把全局 SYNC 单例置空。重复调用幂等（单例已空时直接返回 Ok）。
    ///
    /// 未走本路径直接让进程 drop `Endpoint` 时，iroh 会打印
    /// 「Endpoint dropped without calling Endpoint::close. Aborting ungracefully.」；
    /// `nsh trace` 无头进程退出路径没有生命周期钩子可调本函数（见 executor.md），
    /// 但真实 app 宿主/退出流程应调用它。
    pub async fn close() -> Result<bool, String> {
        let mutex = SYNC.get_or_init(|| tokio::sync::Mutex::new(None));
        let mut guard = mutex.lock().await;
        if let Some(svc) = guard.take() {
            svc.close().await.map_err(|e| format!("{e:#}"))?;
        }
        Ok(true)
    }
}
