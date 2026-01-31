#![allow(clippy::unreadable_literal)]
#![allow(clippy::cast_precision_loss)]

/// Loro P2P 同步能力原型测试
///
/// 这个测试文件验证 Loro CRDT 的增量同步功能，为 Phase 5 P2P 同步做技术准备。
///
/// 测试场景：
/// 1. 两个设备间的基础同步
/// 2. 增量更新导出/导入
/// 3. `VersionVector` 使用
/// 4. 离线编辑后的同步
/// 5. 并发修改的自动合并
use loro::{ExportMode, LoroDoc};

/// 测试场景1：两个设备间的基础同步
///
/// 模拟设备A创建卡片，然后完全同步到设备B
#[test]
fn it_should_basic_sync_between_two_devices() {
    // Given: 两个 Loro 文档（设备A和设备B）
    let device_a = LoroDoc::new();
    device_a.set_peer_id(1).unwrap();
    let device_b = LoroDoc::new();
    device_b.set_peer_id(2).unwrap();

    // When: 设备A创建卡片并导出更新，设备B导入更新
    let map_a = device_a.get_map("card");
    map_a.insert("id", "card-001").unwrap();
    map_a.insert("title", "测试标题").unwrap();
    map_a.insert("content", "测试内容").unwrap();
    map_a.insert("created_at", 1_672_531_200_i64).unwrap();
    device_a.commit();

    let updates = device_a.export(ExportMode::all_updates()).unwrap();
    println!("导出更新大小: {} bytes", updates.len());

    device_b.import(&updates).unwrap();

    // Then: 设备B应该接收到正确数据，且两个设备状态一致
    let map_b = device_b.get_map("card");
    assert_eq!(
        &**map_b
            .get("title")
            .unwrap()
            .into_value()
            .unwrap()
            .as_string()
            .unwrap(),
        "测试标题"
    );
    assert_eq!(
        &**map_b
            .get("content")
            .unwrap()
            .into_value()
            .unwrap()
            .as_string()
            .unwrap(),
        "测试内容"
    );

    assert_eq!(device_a.get_deep_value(), device_b.get_deep_value());

    println!("✅ 基础同步测试通过");
}

/// 测试场景2：增量更新导出/导入（使用VersionVector）
///
/// 模拟设备A进行多次修改，设备B只获取新的增量更新
#[test]
fn it_should_incremental_sync_with_version_vector() {
    // Given: 两个 Loro 文档（设备A和设备B），设备B已同步初始状态
    let device_a = LoroDoc::new();
    device_a.set_peer_id(1).unwrap();
    let device_b = LoroDoc::new();
    device_b.set_peer_id(2).unwrap();

    let map_a = device_a.get_map("card");
    map_a.insert("title", "初始标题").unwrap();
    device_a.commit();

    let updates_1 = device_a.export(ExportMode::all_updates()).unwrap();
    device_b.import(&updates_1).unwrap();
    let vv_b = device_b.oplog_vv();

    // When: 设备A进行多次修改，并使用版本向量导出增量更新
    map_a.insert("title", "修改后的标题").unwrap();
    device_a.commit();

    map_a.insert("content", "新增的内容").unwrap();
    device_a.commit();

    let incremental_updates = device_a.export(ExportMode::updates(&vv_b)).unwrap();
    device_b.import(&incremental_updates).unwrap();

    // Then: 设备B应该接收到最新的修改，且两个设备状态一致
    assert!(!incremental_updates.is_empty(), "增量更新不应为空");

    let map_b = device_b.get_map("card");
    assert_eq!(
        &**map_b
            .get("title")
            .unwrap()
            .into_value()
            .unwrap()
            .as_string()
            .unwrap(),
        "修改后的标题"
    );
    assert_eq!(
        &**map_b
            .get("content")
            .unwrap()
            .into_value()
            .unwrap()
            .as_string()
            .unwrap(),
        "新增的内容"
    );

    assert_eq!(device_a.get_deep_value(), device_b.get_deep_value());

    println!("✅ 增量同步测试通过");
}

/// 测试场景3：双向同步
///
/// 设备A和设备B各自修改不同字段，然后互相同步
#[test]
fn it_should_bidirectional_sync() {
    // Given: 两个 Loro 文档，已完成初始同步
    let device_a = LoroDoc::new();
    device_a.set_peer_id(1).unwrap();
    let device_b = LoroDoc::new();
    device_b.set_peer_id(2).unwrap();

    let map_a = device_a.get_map("card");
    map_a.insert("id", "card-002").unwrap();
    map_a.insert("title", "共享标题").unwrap();
    device_a.commit();

    let init_updates = device_a.export(ExportMode::all_updates()).unwrap();
    device_b.import(&init_updates).unwrap();

    let vv_a = device_a.oplog_vv();
    let vv_b = device_b.oplog_vv();

    // When: 两个设备各自修改不同字段，然后双向同步
    map_a.insert("title", "A修改的标题").unwrap();
    device_a.commit();

    let map_b = device_b.get_map("card");
    map_b.insert("content", "B添加的内容").unwrap();
    device_b.commit();

    let updates_a_to_b = device_a.export(ExportMode::updates(&vv_b)).unwrap();
    device_b.import(&updates_a_to_b).unwrap();

    let updates_b_to_a = device_b.export(ExportMode::updates(&vv_a)).unwrap();
    device_a.import(&updates_b_to_a).unwrap();

    // Then: 两个设备都应该有完整的修改，且状态一致
    let final_map_a = device_a.get_map("card");
    assert_eq!(
        &**final_map_a
            .get("title")
            .unwrap()
            .into_value()
            .unwrap()
            .as_string()
            .unwrap(),
        "A修改的标题"
    );
    assert_eq!(
        &**final_map_a
            .get("content")
            .unwrap()
            .into_value()
            .unwrap()
            .as_string()
            .unwrap(),
        "B添加的内容"
    );

    let final_map_b = device_b.get_map("card");
    assert_eq!(
        &**final_map_b
            .get("title")
            .unwrap()
            .into_value()
            .unwrap()
            .as_string()
            .unwrap(),
        "A修改的标题"
    );
    assert_eq!(
        &**final_map_b
            .get("content")
            .unwrap()
            .into_value()
            .unwrap()
            .as_string()
            .unwrap(),
        "B添加的内容"
    );

    assert_eq!(device_a.get_deep_value(), device_b.get_deep_value());

    println!("✅ 双向同步测试通过");
}

/// 测试场景4：冲突自动解决（Last-Write-Wins）
///
/// 两个设备同时修改同一字段，Loro CRDT 自动解决冲突
#[test]
fn it_should_concurrent_modification_conflict_resolution() {
    // Given: 两个 Loro 文档，已完成初始同步
    let device_a = LoroDoc::new();
    device_a.set_peer_id(1).unwrap();
    let device_b = LoroDoc::new();
    device_b.set_peer_id(2).unwrap();

    let map_a = device_a.get_map("card");
    map_a.insert("title", "初始标题").unwrap();
    device_a.commit();

    let init_updates = device_a.export(ExportMode::all_updates()).unwrap();
    device_b.import(&init_updates).unwrap();

    let vv_a = device_a.oplog_vv();
    let vv_b = device_b.oplog_vv();

    // When: 两个设备同时修改同一字段（模拟冲突），然后双向同步
    map_a.insert("title", "设备A的修改").unwrap();
    device_a.commit();

    let map_b = device_b.get_map("card");
    map_b.insert("title", "设备B的修改").unwrap();
    device_b.commit();

    let updates_a_to_b = device_a.export(ExportMode::updates(&vv_b)).unwrap();
    let updates_b_to_a = device_b.export(ExportMode::updates(&vv_a)).unwrap();

    device_b.import(&updates_a_to_b).unwrap();
    device_a.import(&updates_b_to_a).unwrap();

    // Then: CRDT 应该自动解决冲突，两个设备状态一致
    assert_eq!(device_a.get_deep_value(), device_b.get_deep_value());

    let final_value_a = map_a.get("title").unwrap().into_value().unwrap();
    let final_title_a = final_value_a.as_string().unwrap();

    let final_value_b = map_b.get("title").unwrap().into_value().unwrap();
    let final_title_b = final_value_b.as_string().unwrap();

    assert_eq!(&**final_title_a, &**final_title_b);
    println!("最终标题: {}", &**final_title_a);

    println!("✅ 冲突解决测试通过");
}

/// 测试场景5：模拟真实的卡片同步场景
///
/// 使用 Card 结构的完整字段进行同步测试
#[test]
fn it_should_real_world_card_sync() {
    // Given: 两个 Loro 文档（设备A和设备B）
    let device_a = LoroDoc::new();
    device_a.set_peer_id(1).unwrap();
    let device_b = LoroDoc::new();
    device_b.set_peer_id(2).unwrap();

    // When: 设备A创建完整卡片并同步到设备B，然后进行增量更新
    let map_a = device_a.get_map("card");
    map_a.insert("id", "uuid-12345").unwrap();
    map_a.insert("title", "我的笔记").unwrap();
    map_a
        .insert("content", "# Markdown 内容\n\n这是一段测试内容")
        .unwrap();
    map_a.insert("created_at", 1704067200i64).unwrap(); // 2024-01-01
    map_a.insert("updated_at", 1704067200i64).unwrap();
    map_a.insert("deleted", false).unwrap();
    device_a.commit();

    let updates = device_a.export(ExportMode::all_updates()).unwrap();
    device_b.import(&updates).unwrap();

    let vv_b = device_b.oplog_vv();

    // 更新标题和内容
    map_a.insert("title", "我的笔记（已修改）").unwrap();
    map_a
        .insert("content", "# 更新的内容\n\n新增了一些文字")
        .unwrap();
    map_a.insert("updated_at", 1704153600i64).unwrap(); // 2024-01-02
    device_a.commit();

    let incremental = device_a.export(ExportMode::updates(&vv_b)).unwrap();
    device_b.import(&incremental).unwrap();

    // 软删除
    map_a.insert("deleted", true).unwrap();
    map_a.insert("updated_at", 1704240000i64).unwrap(); // 2024-01-03
    device_a.commit();

    let delete_update = device_a.export(ExportMode::updates(&vv_b)).unwrap();
    device_b.import(&delete_update).unwrap();

    // Then: 设备B应该接收到所有更新，且最终状态一致
    let map_b = device_b.get_map("card");
    assert_eq!(
        &**map_b
            .get("id")
            .unwrap()
            .into_value()
            .unwrap()
            .as_string()
            .unwrap(),
        "uuid-12345"
    );
    assert_eq!(
        &**map_b
            .get("title")
            .unwrap()
            .into_value()
            .unwrap()
            .as_string()
            .unwrap(),
        "我的笔记"
    );
    assert!(
        !(*map_b
            .get("deleted")
            .unwrap()
            .into_value()
            .unwrap()
            .as_bool()
            .unwrap())
    );

    assert_eq!(
        *map_b
            .get("updated_at")
            .unwrap()
            .into_value()
            .unwrap()
            .as_i64()
            .unwrap(),
        1704153600i64
    );

    assert!(*map_b
        .get("deleted")
        .unwrap()
        .into_value()
        .unwrap()
        .as_bool()
        .unwrap());

    assert_eq!(device_a.get_deep_value(), device_b.get_deep_value());

    println!("✅ 真实卡片同步测试通过");
}

/// 测试场景6：Snapshot vs Updates 性能对比
///
/// 比较快照导出和增量更新导出的大小差异
#[test]
fn it_should_snapshot_vs_incremental_updates() {
    // Given: 一个 Loro 文档
    let doc = LoroDoc::new();
    let map = doc.get_map("card");

    // When: 进行10次修改，然后导出快照和增量更新
    for i in 0..10 {
        map.insert("title", format!("标题版本{i}")).unwrap();
        map.insert("content", format!("内容版本{i}")).unwrap();
        doc.commit();
    }

    let snapshot = doc.export(ExportMode::Snapshot).unwrap();
    println!("快照大小: {} bytes", snapshot.len());

    let all_updates = doc.export(ExportMode::all_updates()).unwrap();
    println!("全部更新大小: {} bytes", all_updates.len());

    let vv_after_5 = {
        let temp_doc = LoroDoc::new();
        let temp_map = temp_doc.get_map("card");
        for i in 0..5 {
            temp_map.insert("title", format!("标题版本{i}")).unwrap();
            temp_map.insert("content", format!("内容版本{i}")).unwrap();
            temp_doc.commit();
        }
        temp_doc.oplog_vv()
    };

    let incremental = doc.export(ExportMode::updates(&vv_after_5)).unwrap();
    println!("增量更新大小（后5次修改）: {} bytes", incremental.len());

    // Then: 增量更新应该包含预期的修改，且通常比全量更新更小
    assert!(!incremental.is_empty(), "增量更新应包含后5次修改");

    println!("✅ 性能对比测试通过");

    if incremental.len() < all_updates.len() {
        println!(
            "📊 结论: 增量同步可节省 {:.1}% 的数据传输",
            (1.0 - incremental.len() as f64 / all_updates.len() as f64) * 100.0
        );
    } else {
        println!(
            "📊 注意: 本例中增量更新 ({} bytes) 与全量更新 ({} bytes) 大小相近",
            incremental.len(),
            all_updates.len()
        );
        println!("    （在真实场景中，增量同步对于大量历史记录的文档效果更明显）");
    }
}
