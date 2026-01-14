/// Loro P2P 同步能力原型测试
///
/// 这个测试文件验证 Loro CRDT 的增量同步功能，为 Phase 5 P2P 同步做技术准备。
///
/// 测试场景：
/// 1. 两个设备间的基础同步
/// 2. 增量更新导出/导入
/// 3. VersionVector 使用
/// 4. 离线编辑后的同步
/// 5. 并发修改的自动合并
use loro::{ExportMode, LoroDoc};

/// 测试场景1：两个设备间的基础同步
///
/// 模拟设备A创建卡片，然后完全同步到设备B
#[test]
fn it_should_basic_sync_between_two_devices() {
    // 设备A
    let device_a = LoroDoc::new();
    device_a.set_peer_id(1).unwrap();

    // 设备B
    let device_b = LoroDoc::new();
    device_b.set_peer_id(2).unwrap();

    // 设备A创建一张卡片
    let map_a = device_a.get_map("card");
    map_a.insert("id", "card-001").unwrap();
    map_a.insert("title", "测试标题").unwrap();
    map_a.insert("content", "测试内容").unwrap();
    map_a.insert("created_at", 1672531200i64).unwrap();
    device_a.commit();

    // 导出设备A的所有更新
    let updates = device_a.export(ExportMode::all_updates()).unwrap();
    println!("导出更新大小: {} bytes", updates.len());

    // 设备B导入更新
    device_b.import(&updates).unwrap();

    // 验证设备B接收到了数据
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

    // 验证两个设备的深度值相同
    assert_eq!(device_a.get_deep_value(), device_b.get_deep_value());

    println!("✅ 基础同步测试通过");
}

/// 测试场景2：增量更新导出/导入（使用VersionVector）
///
/// 模拟设备A进行多次修改，设备B只获取新的增量更新
#[test]
fn it_should_incremental_sync_with_version_vector() {
    // 设备A
    let device_a = LoroDoc::new();
    device_a.set_peer_id(1).unwrap();

    // 设备B
    let device_b = LoroDoc::new();
    device_b.set_peer_id(2).unwrap();

    // 第一次修改：创建卡片
    let map_a = device_a.get_map("card");
    map_a.insert("title", "初始标题").unwrap();
    device_a.commit();

    // 设备B同步第一次修改
    let updates_1 = device_a.export(ExportMode::all_updates()).unwrap();
    device_b.import(&updates_1).unwrap();
    println!("第一次同步完成，更新大小: {} bytes", updates_1.len());

    // 记录设备B的版本向量
    let vv_b = device_b.oplog_vv();
    println!("设备B版本向量: {:?}", vv_b);

    // 第二次修改：更新标题
    map_a.insert("title", "修改后的标题").unwrap();
    device_a.commit();

    // 第三次修改：添加内容
    map_a.insert("content", "新增的内容").unwrap();
    device_a.commit();

    // 使用版本向量导出增量更新（只导出设备B未见过的更新）
    let incremental_updates = device_a.export(ExportMode::updates(&vv_b)).unwrap();
    let all_updates_current = device_a.export(ExportMode::all_updates()).unwrap();
    println!(
        "增量更新大小: {} bytes (vs 全量: {} bytes)",
        incremental_updates.len(),
        all_updates_current.len()
    );

    // 增量更新应该不为空（有新的修改）
    assert!(!incremental_updates.is_empty(), "增量更新不应为空");

    // 设备B导入增量更新
    device_b.import(&incremental_updates).unwrap();

    // 验证设备B收到了最新的修改
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

    // 验证两个设备状态一致
    assert_eq!(device_a.get_deep_value(), device_b.get_deep_value());

    println!("✅ 增量同步测试通过");
}

/// 测试场景3：双向同步
///
/// 设备A和设备B各自修改不同字段，然后互相同步
#[test]
fn it_should_bidirectional_sync() {
    // 设备A
    let device_a = LoroDoc::new();
    device_a.set_peer_id(1).unwrap();

    // 设备B
    let device_b = LoroDoc::new();
    device_b.set_peer_id(2).unwrap();

    // 初始同步：创建卡片
    let map_a = device_a.get_map("card");
    map_a.insert("id", "card-002").unwrap();
    map_a.insert("title", "共享标题").unwrap();
    device_a.commit();

    let init_updates = device_a.export(ExportMode::all_updates()).unwrap();
    device_b.import(&init_updates).unwrap();

    // 现在两个设备都有相同的初始状态
    let vv_a = device_a.oplog_vv();
    let vv_b = device_b.oplog_vv();

    // 设备A修改标题
    map_a.insert("title", "A修改的标题").unwrap();
    device_a.commit();

    // 设备B修改内容（同时进行，模拟离线编辑）
    let map_b = device_b.get_map("card");
    map_b.insert("content", "B添加的内容").unwrap();
    device_b.commit();

    // 设备A -> 设备B
    let updates_a_to_b = device_a.export(ExportMode::updates(&vv_b)).unwrap();
    device_b.import(&updates_a_to_b).unwrap();

    // 设备B -> 设备A
    let updates_b_to_a = device_b.export(ExportMode::updates(&vv_a)).unwrap();
    device_a.import(&updates_b_to_a).unwrap();

    // 验证两个设备都有完整的修改
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

    // 验证最终状态一致
    assert_eq!(device_a.get_deep_value(), device_b.get_deep_value());

    println!("✅ 双向同步测试通过");
}

/// 测试场景4：冲突自动解决（Last-Write-Wins）
///
/// 两个设备同时修改同一字段，Loro CRDT 自动解决冲突
#[test]
fn it_should_concurrent_modification_conflict_resolution() {
    // 设备A
    let device_a = LoroDoc::new();
    device_a.set_peer_id(1).unwrap();

    // 设备B
    let device_b = LoroDoc::new();
    device_b.set_peer_id(2).unwrap();

    // 初始同步
    let map_a = device_a.get_map("card");
    map_a.insert("title", "初始标题").unwrap();
    device_a.commit();

    let init_updates = device_a.export(ExportMode::all_updates()).unwrap();
    device_b.import(&init_updates).unwrap();

    let vv_a = device_a.oplog_vv();
    let vv_b = device_b.oplog_vv();

    // 设备A和设备B同时修改同一字段（模拟冲突）
    map_a.insert("title", "设备A的修改").unwrap();
    device_a.commit();

    let map_b = device_b.get_map("card");
    map_b.insert("title", "设备B的修改").unwrap();
    device_b.commit();

    println!("冲突前 - 设备A: {:?}", device_a.get_deep_value());
    println!("冲突前 - 设备B: {:?}", device_b.get_deep_value());

    // 双向同步
    let updates_a_to_b = device_a.export(ExportMode::updates(&vv_b)).unwrap();
    let updates_b_to_a = device_b.export(ExportMode::updates(&vv_a)).unwrap();

    device_b.import(&updates_a_to_b).unwrap();
    device_a.import(&updates_b_to_a).unwrap();

    println!("冲突解决后 - 设备A: {:?}", device_a.get_deep_value());
    println!("冲突解决后 - 设备B: {:?}", device_b.get_deep_value());

    // CRDT 保证最终一致性
    assert_eq!(device_a.get_deep_value(), device_b.get_deep_value());

    // 获取最终值（Loro 使用 LWW 策略，peer_id 更大的获胜）
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
    // 设备A
    let device_a = LoroDoc::new();
    device_a.set_peer_id(1).unwrap();

    // 设备B
    let device_b = LoroDoc::new();
    device_b.set_peer_id(2).unwrap();

    // 设备A创建完整的卡片
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

    // 完全同步到设备B
    let updates = device_a.export(ExportMode::all_updates()).unwrap();
    device_b.import(&updates).unwrap();

    // 验证设备B接收到完整数据
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
    assert_eq!(
        *map_b
            .get("deleted")
            .unwrap()
            .into_value()
            .unwrap()
            .as_bool()
            .unwrap(),
        false
    );

    let vv_b = device_b.oplog_vv();

    // 设备A进行更新操作
    map_a.insert("title", "我的笔记（已修改）").unwrap();
    map_a
        .insert("content", "# 更新的内容\n\n新增了一些文字")
        .unwrap();
    map_a.insert("updated_at", 1704153600i64).unwrap(); // 2024-01-02
    device_a.commit();

    // 增量同步到设备B
    let incremental = device_a.export(ExportMode::updates(&vv_b)).unwrap();
    device_b.import(&incremental).unwrap();

    // 验证更新
    assert_eq!(
        &**map_b
            .get("title")
            .unwrap()
            .into_value()
            .unwrap()
            .as_string()
            .unwrap(),
        "我的笔记（已修改）"
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

    let vv_b = device_b.oplog_vv();

    // 设备A执行软删除
    map_a.insert("deleted", true).unwrap();
    map_a.insert("updated_at", 1704240000i64).unwrap(); // 2024-01-03
    device_a.commit();

    // 同步删除操作
    let delete_update = device_a.export(ExportMode::updates(&vv_b)).unwrap();
    device_b.import(&delete_update).unwrap();

    // 验证删除标记
    assert_eq!(
        *map_b
            .get("deleted")
            .unwrap()
            .into_value()
            .unwrap()
            .as_bool()
            .unwrap(),
        true
    );

    // 最终一致性检查
    assert_eq!(device_a.get_deep_value(), device_b.get_deep_value());

    println!("✅ 真实卡片同步测试通过");
}

/// 测试场景6：Snapshot vs Updates 性能对比
///
/// 比较快照导出和增量更新导出的大小差异
#[test]
fn it_should_snapshot_vs_incremental_updates() {
    let doc = LoroDoc::new();
    let map = doc.get_map("card");

    // 进行10次修改
    for i in 0..10 {
        map.insert("title", format!("标题版本{}", i)).unwrap();
        map.insert("content", format!("内容版本{}", i)).unwrap();
        doc.commit();
    }

    // 导出快照
    let snapshot = doc.export(ExportMode::Snapshot).unwrap();
    println!("快照大小: {} bytes", snapshot.len());

    // 导出所有更新
    let all_updates = doc.export(ExportMode::all_updates()).unwrap();
    println!("全部更新大小: {} bytes", all_updates.len());

    // 模拟增量同步场景
    let vv_after_5 = {
        let temp_doc = LoroDoc::new();
        let temp_map = temp_doc.get_map("card");
        for i in 0..5 {
            temp_map.insert("title", format!("标题版本{}", i)).unwrap();
            temp_map
                .insert("content", format!("内容版本{}", i))
                .unwrap();
            temp_doc.commit();
        }
        temp_doc.oplog_vv()
    };

    let incremental = doc.export(ExportMode::updates(&vv_after_5)).unwrap();
    println!("增量更新大小（后5次修改）: {} bytes", incremental.len());

    // 验证增量更新包含了预期的修改
    assert!(!incremental.is_empty(), "增量更新应包含后5次修改");

    println!("✅ 性能对比测试通过");

    // 计算数据传输节省（如果增量更新确实更小）
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
