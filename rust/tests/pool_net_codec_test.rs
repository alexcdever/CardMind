// input: 构造的 PoolMessage::Hello 消息对象与编解码函数调用。
// output: 断言消息经二进制编码后解码可无损还原原始内容。
// pos: 覆盖组网消息编解码一致性场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
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
