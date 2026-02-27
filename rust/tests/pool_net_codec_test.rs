// input: PoolMessage 与编码器
// output: 消息序列化/反序列化结果
// pos: 组网消息编解码测试（修改本文件需同步更新文件头与所属 DIR.md）
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
