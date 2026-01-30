//! SP-SYNC-007: 同步状态流规格测试
//!
//! 测试 P2P 同步服务的状态广播和 Stream 功能
//!
//! 规格: openspec/changes/sync-service-stream-support/specs/sync-status-stream/spec.md

use cardmind_rust::models::device_config::DeviceConfig;
use cardmind_rust::p2p::sync_service::{P2PSyncService, SyncStatus};
use cardmind_rust::store::card_store::CardStore;
use std::sync::{Arc, Mutex};

/// Spec-SYNC-007-001: 状态广播机制
///
/// `it_should_broadcast_status_to_all_subscribers()`
///
/// 验收标准:
/// - 给定一个同步服务和多个订阅者
/// - 当状态发生变化时
/// - 则所有订阅者都应该收到状态更新
#[test]
fn it_should_broadcast_status_to_all_subscribers() {
    // Given: 创建同步服务
    let card_store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
    let device_config = DeviceConfig::new("test-device-broadcast");
    let service = P2PSyncService::new(card_store, device_config).unwrap();

    // And: 创建多个订阅者
    let mut rx1 = service.status_sender().subscribe();
    let mut rx2 = service.status_sender().subscribe();
    let mut rx3 = service.status_sender().subscribe();

    // When: 触发状态变化
    let new_status = SyncStatus {
        online_devices: 2,
        syncing_devices: 1,
        offline_devices: 0,
    };
    service.notify_status_change(new_status.clone());

    // Then: 所有订阅者都收到状态更新
    assert_eq!(rx1.try_recv().unwrap(), new_status, "订阅者1应该收到状态");
    assert_eq!(rx2.try_recv().unwrap(), new_status, "订阅者2应该收到状态");
    assert_eq!(rx3.try_recv().unwrap(), new_status, "订阅者3应该收到状态");
}

/// Spec-SYNC-007-002: 状态去重
///
/// `it_should_not_broadcast_duplicate_status()`
///
/// 验收标准:
/// - 给定一个同步服务和订阅者
/// - 当连续发送相同的状态时
/// - 则订阅者只应该收到一次状态更新
#[test]
fn it_should_not_broadcast_duplicate_status() {
    // Given: 创建同步服务和订阅者
    let card_store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
    let device_config = DeviceConfig::new("test-device-dedup");
    let service = P2PSyncService::new(card_store, device_config).unwrap();
    let mut rx = service.status_sender().subscribe();

    // When: 连续发送相同的状态
    let status = SyncStatus {
        online_devices: 1,
        syncing_devices: 1,
        offline_devices: 0,
    };
    service.notify_status_change(status.clone());
    service.notify_status_change(status.clone());
    service.notify_status_change(status);

    // Then: 只收到一次状态更新
    assert!(rx.try_recv().is_ok(), "应该收到第一次状态更新");
    assert!(rx.try_recv().is_err(), "不应该收到重复的状态更新");
}

/// Spec-SYNC-007-003: 无订阅者时的处理
///
/// `it_should_handle_no_subscribers_gracefully()`
///
/// 验收标准:
/// - 给定一个同步服务但没有订阅者
/// - 当触发状态变化时
/// - 则不应该发生错误或 panic
#[test]
fn it_should_handle_no_subscribers_gracefully() {
    // Given: 创建同步服务但不创建订阅者
    let card_store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
    let device_config = DeviceConfig::new("test-device-no-sub");
    let service = P2PSyncService::new(card_store, device_config).unwrap();

    // When: 触发状态变化
    let status = SyncStatus {
        online_devices: 1,
        syncing_devices: 0,
        offline_devices: 0,
    };

    // Then: 不应该 panic
    service.notify_status_change(status);
    // 如果没有 panic，测试通过
}

/// Spec-SYNC-007-004: 状态发送器克隆
///
/// `it_should_support_status_sender_cloning()`
///
/// 验收标准:
/// - 给定一个同步服务
/// - 当获取状态发送器并克隆时
/// - 则克隆的发送器应该能够创建新的订阅者
#[test]
fn it_should_support_status_sender_cloning() {
    // Given: 创建同步服务
    let card_store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
    let device_config = DeviceConfig::new("test-device-clone");
    let service = P2PSyncService::new(card_store, device_config).unwrap();

    // When: 获取并克隆状态发送器
    let sender1 = service.status_sender();
    let sender2 = sender1.clone();

    // Then: 两个发送器都能创建订阅者
    let mut rx1 = sender1.subscribe();
    let mut rx2 = sender2.subscribe();

    // And: 发送状态时两个订阅者都能收到
    let status = SyncStatus {
        online_devices: 1,
        syncing_devices: 0,
        offline_devices: 0,
    };
    let _ = sender1.send(status.clone());

    assert_eq!(rx1.try_recv().unwrap(), status);
    assert_eq!(rx2.try_recv().unwrap(), status);
}

/// Spec-SYNC-007-005: 订阅者独立性
///
/// `it_should_maintain_subscriber_independence()`
///
/// 验收标准:
/// - 给定多个订阅者
/// - 当一个订阅者被丢弃时
/// - 则其他订阅者应该继续正常工作
#[test]
fn it_should_maintain_subscriber_independence() {
    // Given: 创建同步服务和多个订阅者
    let card_store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
    let device_config = DeviceConfig::new("test-device-independence");
    let service = P2PSyncService::new(card_store, device_config).unwrap();

    let mut rx1 = service.status_sender().subscribe();
    let rx2 = service.status_sender().subscribe(); // 将被丢弃
    let mut rx3 = service.status_sender().subscribe();

    // When: 丢弃一个订阅者
    drop(rx2);

    // And: 发送状态
    let status = SyncStatus {
        online_devices: 2,
        syncing_devices: 1,
        offline_devices: 0,
    };
    service.notify_status_change(status.clone());

    // Then: 其他订阅者仍然能收到状态
    assert_eq!(rx1.try_recv().unwrap(), status);
    assert_eq!(rx3.try_recv().unwrap(), status);
}

/// Spec-SYNC-007-006: 初始状态
///
/// `it_should_have_disconnected_initial_status()`
///
/// 验收标准:
/// - 给定一个新创建的同步服务
/// - 当获取同步状态时
/// - 则初始状态应该是 disconnected（无在线设备）
#[test]
fn it_should_have_disconnected_initial_status() {
    // Given: 创建同步服务
    let card_store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
    let device_config = DeviceConfig::new("test-device-initial");
    let service = P2PSyncService::new(card_store, device_config).unwrap();

    // When: 获取同步状态
    let status = service.get_sync_status();

    // Then: 初始状态应该是 disconnected
    assert_eq!(status.online_devices, 0, "初始应该没有在线设备");
    assert_eq!(status.syncing_devices, 0, "初始应该没有同步中设备");
    assert_eq!(status.offline_devices, 0, "初始应该没有离线设备");
}

/// Spec-SYNC-007-007: 状态相等性
///
/// `it_should_compare_status_equality_correctly()`
///
/// 验收标准:
/// - 给定两个相同的状态
/// - 当比较它们时
/// - 则应该判定为相等
#[test]
fn it_should_compare_status_equality_correctly() {
    // Given: 两个相同的状态
    let status1 = SyncStatus {
        online_devices: 2,
        syncing_devices: 1,
        offline_devices: 1,
    };
    let status2 = SyncStatus {
        online_devices: 2,
        syncing_devices: 1,
        offline_devices: 1,
    };

    // When & Then: 应该判定为相等
    assert_eq!(status1, status2, "相同的状态应该相等");

    // And: 不同的状态应该不相等
    let status3 = SyncStatus {
        online_devices: 3,
        syncing_devices: 1,
        offline_devices: 1,
    };
    assert_ne!(status1, status3, "不同的状态应该不相等");
}

/// Spec-SYNC-007-008: 状态克隆
///
/// `it_should_clone_status_correctly()`
///
/// 验收标准:
/// - 给定一个状态
/// - 当克隆它时
/// - 则克隆的状态应该与原状态相等
#[test]
fn it_should_clone_status_correctly() {
    // Given: 一个状态
    let original = SyncStatus {
        online_devices: 2,
        syncing_devices: 1,
        offline_devices: 1,
    };

    // When: 克隆状态
    let cloned = original.clone();

    // Then: 克隆的状态应该与原状态相等
    assert_eq!(original, cloned, "克隆的状态应该与原状态相等");
}
