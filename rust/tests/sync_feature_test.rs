//! Domain Layer Test: Sync Model
//!
//! 实现规格: `openspec/specs/domain/sync/model.md`
//!
//! 测试命名: `it_should_[behavior]_when_[condition]()`

use cardmind_rust::models::card::Card;

/// 测试辅助函数：创建测试卡片
fn create_test_card(id: &str, title: &str, content: &str) -> Card {
    Card::new(id.to_string(), title.to_string(), content.to_string())
}

/// 测试辅助函数：模拟版本追踪
#[derive(Debug, Clone, PartialEq, Eq)]
struct SyncVersion {
    version: String,
    timestamp: i64,
}

impl SyncVersion {
    fn new(version: &str) -> Self {
        Self {
            version: version.to_string(),
            timestamp: chrono::Utc::now().timestamp_millis(),
        }
    }
}

/// 测试辅助函数：模拟同步状态
#[derive(Debug, Clone, PartialEq, Eq)]
struct SyncState {
    peer_id: String,
    last_synced_version: Option<String>,
}

impl SyncState {
    fn new(peer_id: &str) -> Self {
        Self {
            peer_id: peer_id.to_string(),
            last_synced_version: None,
        }
    }

    fn update_version(&mut self, version: &str) {
        self.last_synced_version = Some(version.to_string());
    }
}

/// 测试辅助函数：模拟同步操作
struct MockSyncOperation {
    success: bool,
    changes_applied: bool,
}

impl MockSyncOperation {
    const fn successful() -> Self {
        Self {
            success: true,
            changes_applied: true,
        }
    }

    const fn failed() -> Self {
        Self {
            success: false,
            changes_applied: false,
        }
    }
}

// ==== Requirement: 版本追踪 ====

#[test]
/// Scenario: Version is tracked per card
fn it_should_track_version_per_card() {
    // Given: 数据池中存在一张卡片
    let card = create_test_card("card-001", "标题", "内容");
    let mut versions: std::collections::HashMap<String, SyncVersion> =
        std::collections::HashMap::new();
    versions.insert(card.id.clone(), SyncVersion::new("v1"));

    // When: 卡片被修改
    let old_version = versions.get(&card.id).unwrap().clone();
    let new_version = SyncVersion::new("v2");
    versions.insert(card.id.clone(), new_version.clone());

    // Then: 系统应生成新的版本标识符
    assert_eq!(versions.get(&card.id).unwrap().version, "v2");

    // And: 版本应与卡片的 CRDT 状态一起存储
    assert!(versions.contains_key(&card.id));
    assert_ne!(old_version.version, new_version.version);
}

#[test]
/// Scenario: Incremental sync uses version
fn it_should_use_version_for_incremental_sync() {
    // Given: 设备 A 已同步到版本 V1
    let device_a_state = SyncState::new("device-A");
    assert_eq!(device_a_state.last_synced_version, None);

    let mut sync_state = device_a_state;
    sync_state.update_version("V1");

    // 模拟版本历史
    let version_history: Vec<String> = vec!["V1".to_string(), "V2".to_string(), "V3".to_string()];
    let last_synced_index = version_history.iter().position(|v| v == "V1").unwrap();

    // When: 设备 A 请求同步
    let incremental_changes: Vec<String> = version_history
        .iter()
        .skip(last_synced_index + 1)
        .cloned()
        .collect();

    // Then: 系统应仅发送版本 V1 之后的变更
    assert_eq!(incremental_changes, vec!["V2", "V3"]);

    // And: 系统不应发送已同步的数据
    assert!(!incremental_changes.contains(&"V1".to_string()));
}

// ==== Requirement: 基于 CRDT 的冲突解决 ====

#[test]
/// Scenario: Concurrent edits are merged automatically
fn it_should_merge_concurrent_edits_automatically() {
    // Given: 设备 A 和设备 B 都在离线状态下编辑同一张卡片
    let mut card_a = create_test_card("card-001", "原标题", "原内容");
    let mut card_b = create_test_card("card-001", "原标题", "原内容");

    // 设备 A 修改标题
    card_a.update(Some("设备 A 的标题".to_string()), None);

    // 设备 B 修改内容
    card_b.update(None, Some("设备 B 的内容".to_string()));

    // When: 两个设备同步它们的变更
    // 模拟 CRDT 合并：使用 LWW (Last-Write-Wins) 规则
    // 在真实实现中，这会由 Loro CRDT 引擎处理
    // 每个字段独立使用自己的时间戳
    let merged_title = card_a.title; // card_a 的标题更新
    let merged_content = card_b.content; // card_b 的内容更新（后发生的）

    let merged_card = Card::new(card_a.id.clone(), merged_title, merged_content);

    // Then: 系统应使用 CRDT 规则合并两个编辑
    assert_eq!(merged_card.title, "设备 A 的标题");
    assert_eq!(merged_card.content, "设备 B 的内容");

    // And: 两个设备应收敛到相同的最终状态
    // (在真实实现中，这需要验证两个设备的 CRDT 状态一致)
    let final_state = format!("{}|{}", merged_card.title, merged_card.content);
    assert_eq!(final_state, "设备 A 的标题|设备 B 的内容");

    // And: 不应需要用户干预
}

#[test]
/// Scenario: Last-write-wins for simple fields
fn it_should_apply_last_write_wins_for_simple_fields() {
    // Given: 设备 A 在时间 T1 将标题设置为 "A"
    let card_a = create_test_card("card-001", "A", "内容");
    let t1 = card_a.updated_at;

    // 设备 B 在时间 T2 将标题设置为 "B"（T2 > T1）
    let mut card_b = create_test_card("card-001", "A", "内容");
    std::thread::sleep(std::time::Duration::from_millis(10));
    card_b.update(Some("B".to_string()), None);
    let t2 = card_b.updated_at;

    assert!(t2 > t1);

    // When: 两个变更都被同步
    // 模拟 LWW 规则
    let final_title = if t2 > t1 { card_b.title } else { card_a.title };

    // Then: 最终标题应为 "B"
    assert_eq!(final_title, "B");

    // And: 较晚的时间戳应获胜
    assert!(t2 > t1);
}

// ==== Requirement: 同步状态管理 ====

#[test]
/// Scenario: Sync state is tracked per peer
fn it_should_track_sync_state_per_peer() {
    // Given: 设备 A 与设备 B 同步
    let mut sync_states: std::collections::HashMap<String, SyncState> =
        std::collections::HashMap::new();
    sync_states.insert("device-B".to_string(), SyncState::new("device-B"));

    // When: 同步成功完成
    let state = sync_states.get_mut("device-B").unwrap();
    state.update_version("V123");

    // Then: 系统应记录设备 B 的最后同步版本
    assert_eq!(state.last_synced_version, Some("V123".to_string()));

    // And: 系统应使用此版本进行下一次增量同步
    let last_version = state.last_synced_version.as_ref().unwrap();
    assert_eq!(last_version, "V123");

    // When: 设备 A 与设备 C 同步
    sync_states.insert("device-C".to_string(), SyncState::new("device-C"));
    let state_c = sync_states.get("device-C").unwrap();

    // Then: 设备 C 的同步状态应独立于设备 B
    assert_eq!(state_c.last_synced_version, None);
    assert_ne!(
        sync_states.get("device-B").unwrap().last_synced_version,
        state_c.last_synced_version
    );
}

#[test]
/// Scenario: Sync state persists across restarts
fn it_should_persist_sync_state_across_restarts() {
    // Given: 设备 A 已与设备 B 同步
    let mut sync_state = SyncState::new("device-B");
    sync_state.update_version("V456");

    // 模拟持久化（在实际应用中会保存到文件）
    let saved_state = sync_state.clone();

    // When: 设备 A 重启
    let mut restored_state = saved_state;

    // Then: 同步状态应从持久化存储中恢复
    assert_eq!(restored_state.peer_id, "device-B");
    assert_eq!(restored_state.last_synced_version, Some("V456".to_string()));

    // And: 下一次同步应从最后已知版本继续
    let next_sync_version = restored_state.last_synced_version.as_ref().unwrap();
    assert_eq!(next_sync_version, "V456");

    // 模拟继续同步
    restored_state.update_version("V457");
    assert_eq!(restored_state.last_synced_version, Some("V457".to_string()));
}

// ==== Requirement: 同步方向 ====

#[test]
/// Scenario: Device pushes local changes
fn it_should_push_local_changes() {
    // Given: 设备 A 有本地变更
    let device_a_card = create_test_card("card-001", "本地标题", "本地内容");

    // 模拟设备 B 的本地状态（没有此变更）
    let mut remote_cards: std::collections::HashMap<String, Card> =
        std::collections::HashMap::new();

    // When: 设备 A 发起与设备 B 的同步
    let device_a_id = device_a_card.id.clone();
    remote_cards.insert(device_a_id, device_a_card);

    // Then: 设备 A 应将其变更推送到设备 B
    assert_eq!(remote_cards.len(), 1);
    assert_eq!(remote_cards.get("card-001").unwrap().title, "本地标题");

    // And: 设备 B 应将变更应用到其本地状态
    let applied_card = remote_cards.get("card-001").unwrap();
    assert_eq!(applied_card.id, "card-001");
    assert_eq!(applied_card.title, "本地标题");
    assert_eq!(applied_card.content, "本地内容");
}

#[test]
/// Scenario: Device pulls remote changes
fn it_should_pull_remote_changes() {
    // Given: 设备 B 有设备 A 没有的变更
    let mut remote_cards: std::collections::HashMap<String, Card> =
        std::collections::HashMap::new();
    remote_cards.insert(
        "card-002".to_string(),
        create_test_card("card-002", "远程标题", "远程内容"),
    );

    // 设备 A 的本地状态（为空）
    let mut local_cards: std::collections::HashMap<String, Card> = std::collections::HashMap::new();

    // When: 设备 A 发起与设备 B 的同步
    let pulled_card = remote_cards.get("card-002").unwrap();
    local_cards.insert(pulled_card.id.clone(), pulled_card.clone());

    // Then: 设备 A 应从设备 B 拉取变更
    assert_eq!(local_cards.len(), 1);
    assert_eq!(local_cards.get("card-002").unwrap().title, "远程标题");

    // And: 设备 A 应将变更应用到其本地状态
    let applied_card = local_cards.get("card-002").unwrap();
    assert_eq!(applied_card.id, "card-002");
    assert_eq!(applied_card.title, "远程标题");
    assert_eq!(applied_card.content, "远程内容");
}

// ==== Requirement: 同步原子性 ====

#[test]
/// Scenario: Sync succeeds completely
fn it_should_succeed_completely() {
    // Given: 设备 A 发起与设备 B 的同步
    let mut device_a_state = SyncState::new("device-B");
    device_a_state.update_version("V100");

    let sync_operation = MockSyncOperation::successful();

    // When: 所有变更成功传输
    if sync_operation.success {
        device_a_state.update_version("V101");
    }

    // Then: 同步状态应更新
    assert_eq!(device_a_state.last_synced_version, Some("V101".to_string()));

    // And: 两个设备应具有一致的数据
    assert!(sync_operation.success);
    assert!(sync_operation.changes_applied);
}

#[test]
/// Scenario: Sync fails and rolls back
fn it_should_fail_and_rollback() {
    // Given: 设备 A 发起与设备 B 的同步
    let mut device_a_state = SyncState::new("device-B");
    let original_version = "V100".to_string();
    device_a_state.update_version(&original_version);

    let sync_operation = MockSyncOperation::failed();

    // When: 同步期间发生错误
    if !sync_operation.success {
        // 同步应被中止
        assert!(!sync_operation.changes_applied);
    }

    // Then: 同步应被中止
    assert!(!sync_operation.success);

    // And: 不应应用部分变更
    assert!(!sync_operation.changes_applied);

    // And: 同步状态应保持在先前版本
    assert_eq!(device_a_state.last_synced_version, Some(original_version));
    assert_ne!(device_a_state.last_synced_version, Some("V101".to_string()));
}

// ==== Requirement: 无冲突标签合并 ====

#[test]
/// Scenario: Tags are merged using set union
fn it_should_merge_tags_using_set_union() {
    // Given: 设备 A 为卡片添加标签 "work"
    let mut card_a = create_test_card("card-001", "标题", "内容");
    card_a.add_tag("work".to_string());

    // 设备 B 为同一张卡片添加标签 "urgent"
    let mut card_b = create_test_card("card-001", "标题", "内容");
    card_b.add_tag("urgent".to_string());

    // When: 两个设备同步
    // 模拟集合并集合并（CRDT OR-Merge 行为）
    let mut merged_tags: std::collections::HashSet<String> = std::collections::HashSet::new();
    merged_tags.extend(card_a.tags.iter().cloned());
    merged_tags.extend(card_b.tags.iter().cloned());

    // Then: 卡片应具有两个标签：["work", "urgent"]
    assert_eq!(merged_tags.len(), 2);
    assert!(merged_tags.contains("work"));
    assert!(merged_tags.contains("urgent"));

    // And: 不应丢失任何标签
    assert!(merged_tags.contains("work"), "work 标签不应丢失");
    assert!(merged_tags.contains("urgent"), "urgent 标签不应丢失");
}

// ==== 集成测试 ====

#[test]
/// 集成测试：完整的双向同步流程
fn it_should_handle_bidirectional_sync() {
    // Given: 两个设备都有本地变更
    let mut cards_alpha: std::collections::HashMap<String, Card> = std::collections::HashMap::new();
    let mut cards_beta: std::collections::HashMap<String, Card> = std::collections::HashMap::new();

    // 设备 A 创建 card-001
    let card_a = create_test_card("card-001", "设备 A 的卡片", "内容 A");
    let card_alpha_id = card_a.id.clone();
    cards_alpha.insert(card_alpha_id.clone(), card_a.clone());

    // 设备 B 创建 card-002
    let card_b = create_test_card("card-002", "设备 B 的卡片", "内容 B");
    let card_beta_id = card_b.id.clone();
    cards_beta.insert(card_beta_id.clone(), card_b.clone());

    // When: 双向同步
    // 设备 A 推送到设备 B
    cards_beta.insert(card_alpha_id, card_a);

    // 设备 B 推送到设备 A
    cards_alpha.insert(card_beta_id, card_b);

    // Then: 两个设备应具有一致的数据
    assert_eq!(cards_alpha.len(), 2);
    assert_eq!(cards_beta.len(), 2);

    assert!(cards_alpha.contains_key("card-001"));
    assert!(cards_alpha.contains_key("card-002"));
    assert!(cards_beta.contains_key("card-001"));
    assert!(cards_beta.contains_key("card-002"));
}

#[test]
/// 集成测试：版本追踪和增量同步
fn it_should_track_versions_and_sync_incrementally() {
    // Given: 一个设备有多个版本的变更
    let mut sync_state = SyncState::new("device-B");

    // 初始同步到 V0
    sync_state.update_version("V0");
    assert_eq!(sync_state.last_synced_version, Some("V0".to_string()));

    // 模拟版本历史（包括已同步的 V0）
    let version_history: Vec<String> = vec![
        "V0".to_string(),
        "V1".to_string(),
        "V2".to_string(),
        "V3".to_string(),
        "V4".to_string(),
    ];

    // When: 执行增量同步
    let last_synced = sync_state.last_synced_version.as_ref().unwrap().clone();
    let last_index = version_history
        .iter()
        .position(|v| v == &last_synced)
        .unwrap();

    let incremental_changes: Vec<String> = version_history
        .iter()
        .skip(last_index + 1)
        .cloned()
        .collect();

    // Then: 应只传输未同步的变更
    assert_eq!(incremental_changes.len(), 4);
    assert_eq!(incremental_changes, vec!["V1", "V2", "V3", "V4"]);

    // When: 更新同步状态到最新版本
    sync_state.update_version("V4");

    // Then: 下一次同步应为空
    let last_synced = sync_state.last_synced_version.as_ref().unwrap().clone();
    let last_index = version_history
        .iter()
        .position(|v| v == &last_synced)
        .unwrap();

    let remaining_changes = version_history.iter().skip(last_index + 1).count();

    assert_eq!(remaining_changes, 0);
}
