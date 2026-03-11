// input: 可注入投影失败的 CardStore、临时目录与一次创建卡片业务动作。
// output: 断言 Loro 写入已成功、SQLite 查询尚未收敛，并返回可恢复的投影失败语义。
// pos: 覆盖业务写成功与投影失败分离语义的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::models::error::CardMindError;
use cardmind_rust::store::card_store::CardStore;
use cardmind_rust::store::loro_store::{load_loro_doc, note_doc_path};
use loro::LoroValue;
use tempfile::tempdir;
use uuid::Uuid;

#[test]
fn projection_failure_should_not_disguise_business_write_success() {
    let dir = tempdir().unwrap();
    let store =
        CardStore::new_with_projection_failure(dir.path().to_string_lossy().as_ref()).unwrap();

    let result = store.create_card("title", "body");

    let card_id = match result {
        Err(CardMindError::ProjectionNotConverged {
            entity,
            entity_id,
            retry_action,
        }) => {
            assert_eq!(entity, "card");
            assert_eq!(retry_action, "retry_projection");
            Uuid::parse_str(&entity_id).expect("projection error should carry card id")
        }
        other => panic!("expected projection semantic, got {other:?}"),
    };
    let doc = load_loro_doc(&dir.path().join(note_doc_path(&card_id))).unwrap();
    let title = doc
        .get_map("card")
        .get("title")
        .expect("missing loro title")
        .get_deep_value();
    match title {
        LoroValue::String(text) => assert_eq!(text.as_str(), "title"),
        other => panic!("unexpected loro title value: {other:?}"),
    }

    match store.get_card(&card_id) {
        Err(CardMindError::ProjectionNotConverged {
            entity,
            entity_id,
            retry_action,
        }) => {
            assert_eq!(entity, "card");
            assert_eq!(entity_id, card_id.to_string());
            assert_eq!(retry_action, "retry_projection");
        }
        other => panic!("expected query-side projection semantic, got {other:?}"),
    }
}
