//! # Phase 2 恢复契约模块
//!
//! 负责同步状态、查询收敛状态、实例连续性状态等底层证据的归一化判断。
//!
//! ## 核心职责
//! 产出稳定的恢复语义真相，包括：
//! - 本地内容安全状态
//! - 恢复阶段判断
//! - 连续性状态
//! - 允许/禁止操作列表
//!
//! ## 架构原则
//! 所有恢复语义判断必须在此完成，**不允许 Flutter 层二次推断**。
//! 这是 Phase 2 规则归一化中心，确保跨平台恢复行为一致。
//!
//! ## 修改注意
//! 修改本文件需同步更新所属 DIR.md。

/// Phase 2 本地内容安全状态。
///
/// 表示本地数据的安全等级，决定允许的操作范围。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum LocalContentSafety {
    /// 数据安全，允许正常读写操作。
    Safe,
    /// 只读风险，建议暂停写入操作。
    ReadOnlyRisk,
    /// 状态未知，需保守处理。
    Unknown,
}

impl LocalContentSafety {
    /// 将枚举转换为字符串表示。
    ///
    /// # 返回
    /// - `"safe"` - 安全状态
    /// - `"read_only_risk"` - 只读风险
    /// - `"unknown"` - 未知状态
    pub fn as_str(&self) -> &'static str {
        match self {
            LocalContentSafety::Safe => "safe",
            LocalContentSafety::ReadOnlyRisk => "read_only_risk",
            LocalContentSafety::Unknown => "unknown",
        }
    }
}

impl From<&str> for LocalContentSafety {
    /// 从字符串解析安全状态。
    ///
    /// 未知字符串默认为 `Unknown`（保守策略）。
    fn from(s: &str) -> Self {
        match s {
            "safe" => LocalContentSafety::Safe,
            "read_only_risk" => LocalContentSafety::ReadOnlyRisk,
            "unknown" => LocalContentSafety::Unknown,
            _ => LocalContentSafety::Unknown, // 默认保守
        }
    }
}

/// 子状态统一枚举。
///
/// 用于表示各种恢复子状态的通用状态机。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum SubState {
    /// 就绪状态，可以进行正常操作。
    Ready,
    /// 恢复中，正在处理之前的故障。
    Recovering,
    /// 被阻塞，需要用户介入或等待外部条件。
    Blocked,
    /// 待处理，仅用于 `query_convergence_state`。
    Pending,
}

impl SubState {
    /// 将枚举转换为字符串表示。
    pub fn as_str(&self) -> &'static str {
        match self {
            SubState::Ready => "ready",
            SubState::Recovering => "recovering",
            SubState::Blocked => "blocked",
            SubState::Pending => "pending",
        }
    }
}

impl From<&str> for SubState {
    /// 从字符串解析子状态。
    ///
    /// 未知字符串默认为 `Blocked`（保守策略）。
    fn from(s: &str) -> Self {
        match s {
            "ready" => SubState::Ready,
            "recovering" => SubState::Recovering,
            "blocked" => SubState::Blocked,
            "pending" => SubState::Pending,
            _ => SubState::Blocked, // 默认保守
        }
    }
}

/// 恢复阶段。
///
/// 表示当前系统所处的恢复阶段，用于决策下一步动作。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum RecoveryStage {
    /// 稳定状态，无需恢复操作。
    Stable,
    /// 等待中，正在观察或等待条件满足。
    Waiting,
    /// 重试中，正在自动重试之前的失败操作。
    Retrying,
    /// 需要用户操作，无法自动恢复。
    NeedsUserAction,
    /// 不安全未知状态，可能存在数据风险。
    UnsafeUnknown,
}

impl RecoveryStage {
    /// 将枚举转换为字符串表示。
    pub fn as_str(&self) -> &'static str {
        match self {
            RecoveryStage::Stable => "stable",
            RecoveryStage::Waiting => "waiting",
            RecoveryStage::Retrying => "retrying",
            RecoveryStage::NeedsUserAction => "needs_user_action",
            RecoveryStage::UnsafeUnknown => "unsafe_unknown",
        }
    }
}

/// 连续性状态。
///
/// 表示数据连续性是否受损。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ContinuityState {
    /// 路径一致，数据连续性完好。
    SamePath,
    /// 路径有风险，但尚未断裂。
    PathAtRisk,
    /// 路径已断裂，数据连续性受损。
    PathBroken,
}

impl ContinuityState {
    /// 将枚举转换为字符串表示。
    pub fn as_str(&self) -> &'static str {
        match self {
            ContinuityState::SamePath => "same_path",
            ContinuityState::PathAtRisk => "path_at_risk",
            ContinuityState::PathBroken => "path_broken",
        }
    }
}

/// 下一步动作。
///
/// 表示系统建议的下一步恢复动作。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum NextAction {
    /// 无需动作，继续当前状态。
    None,
    /// 重试同步操作。
    RetrySync,
    /// 重试查询收敛状态。
    RetryQueryConvergence,
    /// 重新连接实例。
    ReconnectInstance,
    /// 重新检查当前状态。
    RecheckStatus,
    /// 返回源实例。
    ReturnToSourceInstance,
}

impl NextAction {
    /// 将枚举转换为字符串表示。
    pub fn as_str(&self) -> &'static str {
        match self {
            NextAction::None => "none",
            NextAction::RetrySync => "retry_sync",
            NextAction::RetryQueryConvergence => "retry_query_convergence",
            NextAction::ReconnectInstance => "reconnect_instance",
            NextAction::RecheckStatus => "recheck_status",
            NextAction::ReturnToSourceInstance => "return_to_source_instance",
        }
    }
}

/// Phase 2 恢复契约。
///
/// 包含所有归一化判断结果，是恢复决策的唯一真相来源。
#[derive(Debug, Clone)]
pub struct RecoveryContract {
    /// 本地内容安全状态。
    pub local_content_safety: LocalContentSafety,
    /// 同步子状态。
    pub sync_state: SubState,
    /// 查询收敛子状态。
    pub query_convergence_state: SubState,
    /// 实例连续性子状态。
    pub instance_continuity_state: SubState,
    /// 当前恢复阶段。
    pub recovery_stage: RecoveryStage,
    /// 连续性状态。
    pub continuity_state: ContinuityState,
    /// 建议的下一步动作。
    pub next_action: NextAction,
    /// 允许的操作列表。
    pub allowed_operations: Vec<String>,
    /// 禁止的操作列表。
    pub forbidden_operations: Vec<String>,
}

impl RecoveryContract {
    /// 从底层证据构建契约。
    ///
    /// 根据各种子状态和风险证据计算完整的恢复契约。
    ///
    /// # 参数
    /// * `sync_state` - 同步子状态字符串（"ready" | "recovering" | "blocked"）
    /// * `query_convergence_state` - 查询收敛子状态字符串（"ready" | "pending" | "blocked"）
    /// * `instance_continuity_state` - 实例连续性子状态字符串（"ready" | "recovering" | "blocked"）
    /// * `has_local_content_risk` - 是否有本地内容风险证据
    ///
    /// # 返回
    /// 完整的 `RecoveryContract` 实例。
    ///
    /// # Examples
    /// ```rust,ignore
    /// use cardmind_rust::api::recovery_contract::RecoveryContract;
    ///
    /// let contract = RecoveryContract::from_evidence(
    ///     "ready",      // sync_state
    ///     "ready",      // query_convergence_state
    ///     "ready",      // instance_continuity_state
    ///     false,        // has_local_content_risk
    /// );
    ///
    /// assert!(contract.validate().is_ok());
    /// ```
    pub fn from_evidence(
        sync_state: &str,
        query_convergence_state: &str,
        instance_continuity_state: &str,
        has_local_content_risk: bool,
    ) -> Self {
        let sync = SubState::from(sync_state);
        let query = SubState::from(query_convergence_state);
        let instance = SubState::from(instance_continuity_state);

        // 1. 计算本地内容安全
        let local_content_safety = if has_local_content_risk {
            LocalContentSafety::Unknown
        } else if sync == SubState::Blocked || query == SubState::Blocked {
            LocalContentSafety::ReadOnlyRisk
        } else {
            LocalContentSafety::Safe
        };

        // 2. 计算恢复阶段
        let recovery_stage =
            Self::compute_recovery_stage(&sync, &query, &instance, local_content_safety);

        // 3. 计算连续性状态
        let continuity_state = Self::compute_continuity_state(
            local_content_safety,
            &sync,
            &query,
            &instance,
            recovery_stage,
        );

        // 4. 计算下一步动作
        let next_action = Self::compute_next_action(
            local_content_safety,
            recovery_stage,
            &sync,
            &query,
            &instance,
        );

        // 5. 计算允许/禁止操作
        let (allowed, forbidden) =
            Self::compute_operations(local_content_safety, recovery_stage, continuity_state);

        Self {
            local_content_safety,
            sync_state: sync,
            query_convergence_state: query,
            instance_continuity_state: instance,
            recovery_stage,
            continuity_state,
            next_action,
            allowed_operations: allowed,
            forbidden_operations: forbidden,
        }
    }

    /// 计算恢复阶段。
    ///
    /// 根据子状态和安全状态推断当前恢复阶段。
    /// 这是 Phase 2 恢复契约的核心计算逻辑，决定系统当前处于哪个恢复阶段。
    ///
    /// # 参数
    /// * `sync` - 同步子状态
    /// * `query` - 查询收敛子状态
    /// * `instance` - 实例连续性子状态
    /// * `local_safety` - 本地内容安全状态
    ///
    /// # 返回
    /// 推断出的恢复阶段。
    ///
    /// # 规则
    /// - 规则 8.2.3: `local_content_safety = unknown` 时必须是 `unsafe_unknown`
    /// - 规则 8.2.6: 任一子状态为 `blocked` 时只能是 `needs_user_action` 或 `unsafe_unknown`
    /// - 规则 8.2.7: 三个子状态都为 `ready` 时必须是 `stable`
    /// - 规则 8.2.2: 至少一个子状态为 `recovering/pending` 且没有 `blocked` → `waiting`
    fn compute_recovery_stage(
        sync: &SubState,
        query: &SubState,
        instance: &SubState,
        local_safety: LocalContentSafety,
    ) -> RecoveryStage {
        use RecoveryStage::*;

        // 规则 8.2.3: local_content_safety = unknown 时必须是 unsafe_unknown
        if local_safety == LocalContentSafety::Unknown {
            return UnsafeUnknown;
        }

        // 规则 8.2.6: 任一子状态为 blocked 时只能是 needs_user_action 或 unsafe_unknown
        if *sync == SubState::Blocked
            || *query == SubState::Blocked
            || *instance == SubState::Blocked
        {
            return NeedsUserAction;
        }

        // 规则 8.2.7: 三个子状态都为 ready 时必须是 stable
        if *sync == SubState::Ready && *query == SubState::Ready && *instance == SubState::Ready {
            return Stable;
        }

        // 规则 8.2.2: 至少一个子状态为 recovering/pending 且没有 blocked
        let has_recovering = *sync == SubState::Recovering
            || *query == SubState::Pending
            || *instance == SubState::Recovering;

        if has_recovering {
            // 默认保守选择 waiting
            Waiting
        } else {
            Stable
        }
    }

    /// 计算连续性状态。
    ///
    /// 根据本地内容安全状态和各个子状态判断数据连续性是否受损。
    /// 这是 Phase 2 恢复契约的核心计算逻辑，用于确定数据路径的完整性。
    ///
    /// # 参数
    /// * `local_safety` - 本地内容安全状态
    /// * `sync` - 同步子状态
    /// * `query` - 查询收敛子状态
    /// * `instance` - 实例连续性子状态
    /// * `recovery_stage` - 当前恢复阶段
    ///
    /// # 返回
    /// 推断出的连续性状态。
    ///
    /// # 规则
    /// - 规则 8.3: `safe` 但子状态非 `ready` = `path_at_risk`
    fn compute_continuity_state(
        local_safety: LocalContentSafety,
        sync: &SubState,
        query: &SubState,
        instance: &SubState,
        recovery_stage: RecoveryStage,
    ) -> ContinuityState {
        use ContinuityState::*;
        use LocalContentSafety::*;

        match local_safety {
            // 规则 8.3: safe 但子状态非 ready = path_at_risk
            Safe => {
                let all_ready = *sync == SubState::Ready
                    && *query == SubState::Ready
                    && *instance == SubState::Ready;
                if all_ready { SamePath } else { PathAtRisk }
            }
            ReadOnlyRisk => PathAtRisk,
            Unknown => {
                // 规则 8.2.3: unknown 且允许有限确认 = path_at_risk
                // 规则 8.3 最后一行: 必须停止依赖 = path_broken
                if recovery_stage == RecoveryStage::UnsafeUnknown {
                    PathAtRisk
                } else {
                    PathBroken
                }
            }
        }
    }

    /// 计算下一步动作。
    ///
    /// 根据本地内容安全状态、恢复阶段和各子状态决定系统应该采取的下一步动作。
    /// 这是 Phase 2 恢复契约的核心计算逻辑，为上层提供明确的恢复指引。
    ///
    /// # 参数
    /// * `local_safety` - 本地内容安全状态
    /// * `recovery_stage` - 当前恢复阶段
    /// * `sync` - 同步子状态
    /// * `query` - 查询收敛子状态
    /// * `instance` - 实例连续性子状态
    ///
    /// # 返回
    /// 建议的下一步动作。
    ///
    /// # 规则
    /// - 规则 8.2.4: `needs_user_action` 时 `next_action` 不能是 `none`
    fn compute_next_action(
        local_safety: LocalContentSafety,
        recovery_stage: RecoveryStage,
        sync: &SubState,
        query: &SubState,
        instance: &SubState,
    ) -> NextAction {
        use NextAction::*;
        use RecoveryStage::*;

        // 规则 8.2.4: needs_user_action 时 next_action 不能是 none
        if recovery_stage == NeedsUserAction {
            // 优先级：sync blocked > query blocked > instance blocked
            if *sync == SubState::Blocked {
                return RetrySync;
            }
            if *query == SubState::Blocked {
                return RetryQueryConvergence;
            }
            if *instance == SubState::Blocked {
                return ReconnectInstance;
            }
            return RecheckStatus;
        }

        // 规则 8.2.3: unknown 时只能是 recheck_status 或 return_to_source_instance
        if local_safety == LocalContentSafety::Unknown {
            return RecheckStatus;
        }

        // stable 或 waiting 时返回 none
        None
    }

    /// 计算允许和禁止的操作。
    ///
    /// 根据本地内容安全状态、恢复阶段和连续性状态，确定当前允许和禁止的操作列表。
    /// 这是 Phase 2 恢复契约的核心计算逻辑，为上层的 UI 层提供操作权限控制依据。
    ///
    /// # 参数
    /// * `local_safety` - 本地内容安全状态
    /// * `_recovery_stage` - 当前恢复阶段（保留参数，供未来扩展）
    /// * `continuity_state` - 连续性状态
    ///
    /// # 返回
    /// 元组 `(允许的操作列表, 禁止的操作列表)`。
    ///
    /// # 操作说明
    /// - Safe: 允许查看、继续编辑、等待、重试；禁止内容丢失表达
    /// - ReadOnlyRisk: 允许查看、检查状态、恢复操作；禁止写入、继续编辑、常规路径写入
    /// - Unknown: 允许查看状态、恢复操作；禁止写入、继续编辑、内容安全承诺、高风险写入
    /// - PathBroken: 额外禁止常规主路径操作
    fn compute_operations(
        local_safety: LocalContentSafety,
        _recovery_stage: RecoveryStage,
        continuity_state: ContinuityState,
    ) -> (Vec<String>, Vec<String>) {
        use LocalContentSafety::*;

        let mut allowed = Vec::new();
        let mut forbidden = Vec::new();

        match local_safety {
            Safe => {
                allowed.push("view".to_string());
                allowed.push("continue_edit".to_string());
                allowed.push("wait".to_string());
                allowed.push("retry".to_string());

                forbidden.push("content_lost_expression".to_string());
            }
            ReadOnlyRisk => {
                allowed.push("view".to_string());
                allowed.push("check_status".to_string());
                allowed.push("recovery_action".to_string());

                forbidden.push("write".to_string());
                forbidden.push("continue_edit".to_string());
                forbidden.push("normal_path_write".to_string());
            }
            Unknown => {
                allowed.push("view_status".to_string());
                allowed.push("recovery_action".to_string());

                forbidden.push("write".to_string());
                forbidden.push("continue_edit".to_string());
                forbidden.push("content_safety_promise".to_string());
                forbidden.push("high_risk_write".to_string());
            }
        }

        // path_broken 时进一步收紧
        if continuity_state == ContinuityState::PathBroken {
            forbidden.push("normal_main_path".to_string());
        }

        (allowed, forbidden)
    }

    /// 验证契约约束。
    ///
    /// 检查契约中的各种组合是否违反规则。
    ///
    /// # 返回
    /// - `Ok(())` - 所有约束满足。
    /// - `Err(String)` - 发现非法组合，返回错误描述。
    ///
    /// # 验证规则
    /// - 规则 8.2.1: `safe` 时 `continuity_state` 不能是 `path_broken`
    /// - 规则 8.2.4: `needs_user_action` 时 `next_action` 不能是 `none`
    /// - 规则 8.2.5: `next_action=none` 时 `recovery_stage` 只能是 `stable/waiting/retrying`
    /// - 规则 8.2.8: `path_broken` 时必须有明确断裂证据
    pub fn validate(&self) -> Result<(), String> {
        // 规则 8.2.1: safe 时 continuity_state 不能是 path_broken
        if self.local_content_safety == LocalContentSafety::Safe
            && self.continuity_state == ContinuityState::PathBroken
        {
            return Err("Illegal combination: safe + path_broken".to_string());
        }

        // 规则 8.2.4: needs_user_action 时 next_action 不能是 none
        if self.recovery_stage == RecoveryStage::NeedsUserAction
            && self.next_action == NextAction::None
        {
            return Err("Illegal combination: needs_user_action + next_action=none".to_string());
        }

        // 规则 8.2.5: next_action=none 时 recovery_stage 只能是 stable/waiting/retrying
        if self.next_action == NextAction::None {
            match self.recovery_stage {
                RecoveryStage::Stable | RecoveryStage::Waiting | RecoveryStage::Retrying => {}
                _ => {
                    return Err(
                        "Illegal combination: next_action=none with invalid recovery_stage"
                            .to_string(),
                    );
                }
            }
        }

        // 规则 8.2.8: path_broken 时必须有明确断裂证据
        if self.continuity_state == ContinuityState::PathBroken
            && self.local_content_safety == LocalContentSafety::Safe
        {
            return Err(
                "Illegal combination: path_broken requires non-safe local_content_safety"
                    .to_string(),
            );
        }

        Ok(())
    }
}

/// 从旧版状态转换到 Phase 2 契约。
///
/// 这是兼容层，用于逐步迁移旧系统的状态表示。
///
/// # 参数
/// * `sync_state` - 旧版同步状态字符串。
/// * `projection_state` - 旧版投影状态字符串。
/// * `has_error` - 是否有错误标志。
///
/// # 返回
/// 转换后的 `RecoveryContract` 实例。
///
/// # 映射规则
/// - `"idle"` / `"connected"` → `"ready"`
/// - `"sync_failed"` / `has_error=true` → `"blocked"`
/// - 其他 → `"recovering"`
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api::recovery_contract::legacy_to_phase2_contract;
///
/// let contract = legacy_to_phase2_contract("idle", "projection_ready", false);
/// assert_eq!(contract.sync_state.as_str(), "ready");
/// ```
pub fn legacy_to_phase2_contract(
    sync_state: &str,
    projection_state: &str,
    has_error: bool,
) -> RecoveryContract {
    // 映射旧状态到新子状态
    // "idle" 和 "connected" 都表示稳定状态，映射为 "ready"
    // "sync_failed" 或错误状态映射为 "blocked"
    // 其他中间状态映射为 "recovering"
    let sync_substate = if sync_state == "sync_failed" || has_error {
        "blocked"
    } else if sync_state == "idle" || sync_state == "connected" {
        "ready"
    } else {
        "recovering"
    };

    let query_substate = if projection_state == "projection_pending" {
        "pending"
    } else if projection_state == "projection_ready" {
        "ready"
    } else {
        "blocked"
    };

    // 实例连续性默认 ready（需要独立证据源）
    let instance_substate = "ready";

    RecoveryContract::from_evidence(
        sync_substate,
        query_substate,
        instance_substate,
        false, // 旧系统没有明确风险证据时假设安全
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_safe_with_ready_substates_is_stable() {
        let contract = RecoveryContract::from_evidence("ready", "ready", "ready", false);
        assert_eq!(contract.local_content_safety, LocalContentSafety::Safe);
        assert_eq!(contract.recovery_stage, RecoveryStage::Stable);
        assert_eq!(contract.continuity_state, ContinuityState::SamePath);
        assert_eq!(contract.next_action, NextAction::None);
        assert!(contract.validate().is_ok());
    }

    #[test]
    fn test_safe_with_pending_query_is_path_at_risk() {
        let contract = RecoveryContract::from_evidence("ready", "pending", "ready", false);
        assert_eq!(contract.local_content_safety, LocalContentSafety::Safe);
        assert_eq!(contract.query_convergence_state, SubState::Pending);
        assert_eq!(contract.continuity_state, ContinuityState::PathAtRisk);
        assert!(contract.validate().is_ok());
    }

    #[test]
    fn test_blocked_sync_is_read_only_risk() {
        let contract = RecoveryContract::from_evidence("blocked", "ready", "ready", false);
        assert_eq!(
            contract.local_content_safety,
            LocalContentSafety::ReadOnlyRisk
        );
        assert_eq!(contract.recovery_stage, RecoveryStage::NeedsUserAction);
        assert_eq!(contract.continuity_state, ContinuityState::PathAtRisk);
        assert_ne!(contract.next_action, NextAction::None);
        assert!(contract.validate().is_ok());
    }

    #[test]
    fn test_unknown_content_safety_is_unsafe_unknown() {
        let contract = RecoveryContract::from_evidence("ready", "ready", "ready", true);
        assert_eq!(contract.local_content_safety, LocalContentSafety::Unknown);
        assert_eq!(contract.recovery_stage, RecoveryStage::UnsafeUnknown);
        assert!(contract.forbidden_operations.contains(&"write".to_string()));
        assert!(contract.validate().is_ok());
    }

    #[test]
    fn test_illegal_safe_path_broken_is_detected() {
        // 这个测试验证约束检查能捕获非法组合
        let mut contract = RecoveryContract::from_evidence("blocked", "ready", "ready", false);
        // 手动设置为非法组合
        contract.local_content_safety = LocalContentSafety::Safe;
        contract.continuity_state = ContinuityState::PathBroken;
        assert!(contract.validate().is_err());
    }
}
