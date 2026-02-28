// input: rust/tests/pool_net_codec_test.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 测试模块，验证关键行为、边界条件与错误路径。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 测试模块，验证关键行为、边界条件与错误路径。
use cardmind_rust::net::codec::{decode_message, encode_message};
use cardmind_rust::net::messages::PoolMessage;
use uuid::Uuid;

#[test]
fn it_should_encode_and_decode_pool_message() -> Result<(), Box<dyn std::error::Error>> {
    let pool_id = Uuid::now_v7();
    let msg = PoolMessage::Hello {
        pool_id,
        endpoint_id: "ep".to_string(),
        nickname: "nick".to_string(),
        os: "os".to_string(),
    };
    let bytes = encode_message(&msg)?;
    let decoded = decode_message(&bytes)?;
    assert_eq!(decoded, msg);
    Ok(())
}
