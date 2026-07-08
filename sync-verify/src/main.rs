use loro::{ExportMode, LoroDoc, VersionVector};

fn main() {
    println!("=== LoroDoc 基本操作验证 ===\n");

    // 1. 创建文档，写入笔记内容
    let doc = LoroDoc::new();
    let text = doc.get_text("content");
    text.insert(0, "# 第一条笔记\n\n今天天气不错。").unwrap();
    println!("[创建] 写入了笔记内容");

    // 2. 导出全量快照
    let snapshot = doc.export(ExportMode::snapshot()).unwrap();
    println!("[快照] 大小: {} bytes", snapshot.len());

    // 3. 模拟第二台设备收到快照
    let doc2 = LoroDoc::new();
    doc2.import(&snapshot).unwrap();
    println!(
        "[导入] 设备 B 内容: {}",
        doc2.get_text("content").to_string().trim()
    );

    // 4. 两台设备同时修改，导出增量变更
    //    设备 A 追加
    text.insert(text.len_unicode(), "下午开始下雨了。").unwrap();
    let changes_a = doc.export(ExportMode::all_updates()).unwrap();
    println!("[增量] 设备 A 所有变更: {} bytes", changes_a.len());

    //    设备 B 追加另一行
    let text2 = doc2.get_text("content");
    text2.insert(text2.len_unicode(), "晚上吃了火锅。").unwrap();
    let changes_b = doc2.export(ExportMode::all_updates()).unwrap();
    println!("[增量] 设备 B 所有变更: {} bytes", changes_b.len());

    // 5. 互相导入对方变更（CRDT 无冲突合并）
    doc.import(&changes_b).unwrap();
    doc2.import(&changes_a).unwrap();
    println!("\n[合并] 互相导入对方变更后:");

    let final_text = doc.get_text("content").to_string();
    println!("设备 A: {}", final_text.trim());
    println!("设备 B: {}", doc2.get_text("content").to_string().trim());

    // 6. 验证两边一致
    assert_eq!(
        doc.get_text("content").to_string(),
        doc2.get_text("content").to_string(),
        "CRDT 合并结果不一致！"
    );

    println!("\n✅ 验证通过：LoroDoc 基本读写、快照、增量同步、无冲突合并全部正常。");

    // 7. 演示增量导出：只导出"对方没有"的变更
    let vv_a = doc.oplog_vv();
    println!("\n[版本] 设备 A 版本向量: {:?}", vv_a);
    // 导出从某个版本之后的增量
    let incremental = doc.export(ExportMode::updates(&VersionVector::new())).unwrap();
    println!("[增量导出] 从空白版本之后的变更: {} bytes", incremental.len());
}
