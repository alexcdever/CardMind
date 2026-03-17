// input: 包含单个合法成员的会话配置与 unknown endpoint 校验请求。
// output: 断言非成员端点会触发 CardMindError::NotMember 错误。
// pos: 覆盖组网会话成员校验拒绝分支场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::models::error::CardMindError;
use cardmind_rust::models::pool::PoolMember;
use cardmind_rust::net::session::PoolSession;
use uuid::Uuid;

#[test]
fn it_should_reject_non_member() {
    let pool_id = Uuid::now_v7();
    let members = vec![PoolMember {
        endpoint_id: "known".to_string(),
        nickname: "nick".to_string(),
        os: "os".to_string(),
        is_admin: true,
    }];
    let session = PoolSession::new(pool_id, &members);
    let result = session.validate_peer("unknown");
    assert!(matches!(result, Err(CardMindError::NotMember(_))));
}
