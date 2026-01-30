use loro::{ExportMode, LoroDoc};
use std::sync::Arc;

fn main() {
    let doc = LoroDoc::new();
    let map = doc.get_map("test");

    // Test API
    map.insert("key", "value").unwrap();

    // Export using updated API
    let bytes = doc.export(ExportMode::Snapshot).unwrap();

    // Subscribe using Arc wrapper
    let _sub = doc.subscribe_root(Arc::new(|event| {
        println!("{event:?}");
    }));

    println!(
        "Loro API test completed. Snapshot size: {} bytes",
        bytes.len()
    );
}
