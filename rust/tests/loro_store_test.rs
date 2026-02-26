// input: 
// output: 
// pos: 
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use cardmind_rust::store::loro_store::{note_doc_path, pool_doc_path};
use std::path::Path;
use uuid::Uuid;

#[test]
fn it_should_build_note_path() {
    let id = Uuid::now_v7();
    let path = note_doc_path(&id);
    let expected = Path::new("data")
        .join("loro")
        .join("note")
        .join(URL_SAFE_NO_PAD.encode(id.as_bytes()));
    assert!(path.ends_with(expected));
}

#[test]
fn it_should_build_pool_path() {
    let id = Uuid::now_v7();
    let path = pool_doc_path(&id);
    let expected = Path::new("data")
        .join("loro")
        .join("pool")
        .join(URL_SAFE_NO_PAD.encode(id.as_bytes()));
    assert!(path.ends_with(expected));
}
