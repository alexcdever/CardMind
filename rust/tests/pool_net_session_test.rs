// input: rust/tests/pool_net_session_test.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 测试模块，验证关键行为、边界条件与错误路径。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 测试模块，验证关键行为、边界条件与错误路径。
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
