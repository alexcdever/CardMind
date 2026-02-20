use cardmind_rust::store::loro_store::note_doc_path;
use uuid::Uuid;

#[test]
fn it_should_build_note_path() {
    let id = Uuid::now_v7();
    let path = note_doc_path(&id);
    assert!(path.to_string_lossy().contains("data/loro/note"));
}
