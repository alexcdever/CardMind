// input: 临时文件路径、写入标题字段后的 LoroDoc 与保存/加载调用。
// output: 断言文档持久化后可恢复且标题字段类型和值正确。
// pos: 覆盖 Loro 文档持久化读写链路场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::store::loro_store::{load_loro_doc, save_loro_doc};
use loro::{LoroDoc, LoroValue};
use tempfile::tempdir;

#[test]
fn it_should_save_and_load_loro_doc() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let path = dir.path().join("doc.loro");

    let doc = LoroDoc::new();
    doc.get_map("card").insert("title", "t")?;
    doc.commit();

    save_loro_doc(&path, &doc)?;

    let loaded = load_loro_doc(&path)?;
    let value = loaded.get_map("card").get("title").ok_or_else(|| {
        std::io::Error::new(std::io::ErrorKind::Other, "missing title")
    })?;
    match value.get_deep_value() {
        LoroValue::String(text) => assert_eq!(text.as_str(), "t"),
        _ => {
            return Err(std::io::Error::new(
                std::io::ErrorKind::Other,
                "title not string",
            )
            .into())
        }
    }
    Ok(())
}
