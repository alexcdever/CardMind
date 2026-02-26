// input: 
// output: 
// pos: 
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
