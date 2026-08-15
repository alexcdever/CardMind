// 一次性工具：从 device.key（SecretKey hex）推导 iroh NodeId 字符串。
// 用法: cargo run --example key_to_nodeid -- <hex64>
use std::env;

fn main() {
    let hex = env::args().nth(1).expect("usage: key_to_nodeid <hex64>");
    let bytes: Vec<u8> = (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect();
    let arr: [u8; 32] = bytes.try_into().expect("32 bytes");
    let secret = iroh::SecretKey::from_bytes(&arr);
    let node_id: iroh::EndpointId = secret.public().into();
    println!("{}", node_id);
}
