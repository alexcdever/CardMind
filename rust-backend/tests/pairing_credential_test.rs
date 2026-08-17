//! 签名配对凭证协议测试（任务 Q 验收标准 1-13）。
//!
//! 协议层（无网络）：canonical layout、base64url、验签、篡改拒绝、
//! 长度/前缀/版本/时间窗口校验。
//! 行为层（SyncService 集成）：新凭证替换旧会话、单次使用、nonce 强制校验
//! 与失败计数、凭证直连（内嵌 node id、不经 mDNS）、6 位码+mDNS 路径
//! 使用广播 nonce、凭证不进调试日志、空/全零 nonce 拒绝。

use std::sync::Arc;

use cardmind_backend::debug_log::CollectingSink;
use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::{
    credential_from_string, credential_to_string, encode_credential, parse_credential,
    PairingRequest, PairingTarget, ParsedCredentialFields, SyncService, CREDENTIAL_FINAL_LEN,
};

use iroh::SecretKey;

fn fixed_sk() -> SecretKey {
    let mut seed = [7u8; 32];
    seed[0] = 1;
    SecretKey::from_bytes(&seed)
}

fn fixed_node_id(sk: &SecretKey) -> [u8; 32] {
    *sk.public().as_bytes()
}

const ISSUED: u64 = 1_700_000_000;
const EXPIRES: u64 = ISSUED + 600; // 10 min
const CODE: u32 = 654321;

fn fixed_nonce() -> [u8; 16] {
    let mut n = [0u8; 16];
    for (i, b) in n.iter_mut().enumerate() {
        *b = i as u8;
    }
    n
}

fn rt() -> tokio::runtime::Runtime {
    tokio::runtime::Runtime::new().unwrap()
}

/// 构造一个发起方请求（测试用）。nonce 必须与会话 nonce 一致
/// （confirm 侧强制校验：空/全零/不匹配均拒绝）。
fn requester(code: &str, id: &str, name: &str, nonce: &str) -> PairingRequest {
    PairingRequest {
        code: code.to_string(),
        device_id: id.to_string(),
        device_name: name.to_string(),
        relay_info: String::new(),
        // 指向关闭端口：无真实握手（无 pending 连接）时 confirm 不触发推送
        ips: vec!["127.0.0.1:1".to_string()],
        nonce: nonce.to_string(),
    }
}

fn temp_dir(label: &str) -> std::path::PathBuf {
    let path = std::env::temp_dir().join(format!("cardmind-cred-{label}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&path);
    std::fs::create_dir_all(&path).unwrap();
    path
}

#[test]
fn credential_v1_has_exact_canonical_layout_and_roundtrips() {
    let sk = fixed_sk();
    let node_id = fixed_node_id(&sk);
    let nonce = fixed_nonce();

    let raw = encode_credential(&sk, ISSUED, EXPIRES, &nonce, &node_id, CODE).unwrap();
    assert_eq!(raw.len(), CREDENTIAL_FINAL_LEN);
    assert_eq!(CREDENTIAL_FINAL_LEN, 135);

    // magic "CM"
    assert_eq!(&raw[0..2], b"CM");
    // version = 1
    assert_eq!(raw[2], 1);
    // issued_at 大端
    assert_eq!(&raw[3..11], &ISSUED.to_be_bytes());
    // expires_at 大端
    assert_eq!(&raw[11..19], &EXPIRES.to_be_bytes());
    // nonce 16 字节
    assert_eq!(&raw[19..35], &nonce);
    // node_id 32 字节
    assert_eq!(&raw[35..67], &node_id);
    // pairing_code u32 大端
    assert_eq!(&raw[67..71], &CODE.to_be_bytes());
    // 签名区在 [71..135]
    assert_eq!(raw[71..].len(), 64);

    let parsed = parse_credential(&raw, ISSUED + 1).unwrap();
    assert_eq!(
        parsed,
        ParsedCredentialFields {
            node_id_bytes: node_id,
            pairing_code: CODE,
            expires_at: EXPIRES,
            nonce,
        }
    );
}

#[test]
fn credential_qr_text_is_canonical_base64url_without_padding() {
    let sk = fixed_sk();
    let node_id = fixed_node_id(&sk);
    let nonce = fixed_nonce();
    let raw = encode_credential(&sk, ISSUED, EXPIRES, &nonce, &node_id, CODE).unwrap();

    let s = credential_to_string(&raw);
    assert!(s.starts_with("cm1."));
    let body = &s[4..];
    assert!(!body.is_empty());
    assert!(
        body.bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_'),
        "body must be base64url charset, got: {body}"
    );
    assert!(!s.contains('='), "no padding allowed");
    assert!(!s.contains(char::is_whitespace), "no whitespace");

    // 重新编码逐字节一致
    let roundtrip = credential_from_string(&s).unwrap();
    assert_eq!(roundtrip, raw);
}

#[test]
fn credential_signature_is_verified_by_endpoint_id() {
    let sk = fixed_sk();
    let node_id = fixed_node_id(&sk);
    let nonce = fixed_nonce();
    let raw = encode_credential(&sk, ISSUED, EXPIRES, &nonce, &node_id, CODE).unwrap();
    // parse 从 payload node_id 构造公钥验签，无额外公钥
    let parsed = parse_credential(&raw, ISSUED + 1).unwrap();
    assert_eq!(parsed.node_id_bytes, node_id);

    // 用错误私钥签名 → 验签失败
    let mut bad_seed = [7u8; 32];
    bad_seed[0] = 2;
    let bad_sk = SecretKey::from_bytes(&bad_seed);
    let bad_raw = encode_credential(&bad_sk, ISSUED, EXPIRES, &nonce, &node_id, CODE).unwrap();
    assert!(parse_credential(&bad_raw, ISSUED + 1).is_err());
}

#[test]
fn credential_rejects_tampered_payload_and_signature() {
    let sk = fixed_sk();
    let node_id = fixed_node_id(&sk);
    let nonce = fixed_nonce();
    let raw = encode_credential(&sk, ISSUED, EXPIRES, &nonce, &node_id, CODE).unwrap();

    // 翻转 node_id 任一字节
    for idx in [35, 40, 66] {
        let mut t = raw;
        t[idx] ^= 0xFF;
        assert!(
            parse_credential(&t, ISSUED + 1).is_err(),
            "node_id byte {idx}"
        );
    }
    // 翻转 code
    for idx in [67, 70] {
        let mut t = raw;
        t[idx] ^= 0xFF;
        assert!(parse_credential(&t, ISSUED + 1).is_err(), "code byte {idx}");
    }
    // 翻转 expires
    for idx in [11, 18] {
        let mut t = raw;
        t[idx] ^= 0x01;
        assert!(
            parse_credential(&t, ISSUED + 1).is_err(),
            "expires byte {idx}"
        );
    }
    // 翻转 nonce
    for idx in [19, 34] {
        let mut t = raw;
        t[idx] ^= 0x01;
        assert!(
            parse_credential(&t, ISSUED + 1).is_err(),
            "nonce byte {idx}"
        );
    }
    // 翻转签名
    for idx in [71, 134] {
        let mut t = raw;
        t[idx] ^= 0x01;
        assert!(
            parse_credential(&t, ISSUED + 1).is_err(),
            "signature byte {idx}"
        );
    }
}

#[test]
fn credential_rejects_wrong_prefix_version_length_and_trailing_bytes() {
    let sk = fixed_sk();
    let node_id = fixed_node_id(&sk);
    let nonce = fixed_nonce();
    let raw = encode_credential(&sk, ISSUED, EXPIRES, &nonce, &node_id, CODE).unwrap();
    let s = credential_to_string(&raw);

    // 错误前缀
    assert!(credential_from_string(&format!("cm2.{}", &s[4..])).is_err());
    assert!(credential_from_string("cm1").is_err());
    // 未知版本
    let mut bad = raw;
    bad[2] = 2;
    assert!(parse_credential(&bad, ISSUED + 1).is_err());
    // 截断
    assert!(credential_from_string(&s[..s.len() - 4]).is_err());
    // 超长/尾随字节
    let mut extra = raw.to_vec();
    extra.push(0);
    assert!(parse_credential(&extra, ISSUED + 1).is_err());
}

#[test]
fn credential_rejects_expired_future_and_invalid_ttl() {
    let sk = fixed_sk();
    let node_id = fixed_node_id(&sk);
    let nonce = fixed_nonce();

    // 过期：now >= expires
    let raw = encode_credential(&sk, ISSUED, EXPIRES, &nonce, &node_id, CODE).unwrap();
    assert!(parse_credential(&raw, EXPIRES).is_err());
    assert!(parse_credential(&raw, EXPIRES + 1).is_err());

    // issued_at 未来超 60s
    let future_issued = 1_700_000_000u64 + 200;
    let future_exp = future_issued + 600;
    let raw = encode_credential(&sk, future_issued, future_exp, &nonce, &node_id, CODE).unwrap();
    assert!(parse_credential(&raw, ISSUED).is_err()); // now 比 issued_at 早 >60s

    // 允许 60s 内偏差
    let skew_issued = ISSUED + 30;
    let skew_exp = skew_issued + 600;
    let raw = encode_credential(&sk, skew_issued, skew_exp, &nonce, &node_id, CODE).unwrap();
    assert!(parse_credential(&raw, ISSUED).is_ok());

    // expires <= issued
    let raw = encode_credential(&sk, ISSUED, ISSUED, &nonce, &node_id, CODE).unwrap();
    assert!(parse_credential(&raw, ISSUED + 1).is_err());

    // TTL > 10 min
    let too_long = ISSUED + 601;
    let raw = encode_credential(&sk, ISSUED, too_long, &nonce, &node_id, CODE).unwrap();
    assert!(parse_credential(&raw, ISSUED + 1).is_err());
} // ━━━ 行为层（任务 Q 验收标准 7-13）━━━

/// 验收 7：新凭证原子替换旧会话——旧码/旧 nonce 失效，新码/新 nonce 生效。
#[test]
fn new_credential_replaces_previous_session() {
    rt().block_on(async {
        let confirmer = SyncService::new().await.unwrap();
        let store = NoteStore::new(":memory:").unwrap();

        let first = confirmer.begin_pairing_credential().unwrap();
        let second = confirmer.begin_pairing_credential().unwrap();

        // 会话已被 second 替换（code + nonce 同时更新）
        let session = confirmer.current_pairing_session().unwrap();
        assert_eq!(session.code, second.code);
        assert_ne!(session.code, first.code, "重新生成后旧码应失效");

        let first_parsed = confirmer
            .parse_pairing_credential(&first.credential)
            .unwrap();
        let second_parsed = confirmer
            .parse_pairing_credential(&second.credential)
            .unwrap();
        assert_ne!(
            first_parsed.nonce, second_parsed.nonce,
            "每次生成必须重新随机 nonce"
        );

        // 旧凭证（旧 code + 旧 nonce）→ 拒绝（码不匹配当前会话）
        let old_req = requester(
            &first_parsed.code,
            "initiator-old",
            "Old Phone",
            &first_parsed.nonce,
        );
        let err = confirmer
            .confirm_pairing(&store, &first_parsed.code, &old_req)
            .await
            .unwrap_err();
        assert!(
            err.to_string().contains("code"),
            "旧凭证应因码不匹配被拒，实际: {err:#}"
        );

        // 新凭证 → 成功
        let new_req = requester(
            &second_parsed.code,
            "initiator-new",
            "New Phone",
            &second_parsed.nonce,
        );
        let result = confirmer
            .confirm_pairing(&store, &second_parsed.code, &new_req)
            .await
            .unwrap();
        assert_eq!(result.peer_id, "initiator-new");
    });
}

/// 验收 8：凭证单次使用——配对成功后会话清除，同一凭证第二次 confirm 失败。
#[test]
fn credential_is_single_use() {
    rt().block_on(async {
        let confirmer = SyncService::new().await.unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        let display = confirmer.begin_pairing_credential().unwrap();
        let parsed = confirmer
            .parse_pairing_credential(&display.credential)
            .unwrap();

        let req = requester(&parsed.code, "initiator-single", "New Phone", &parsed.nonce);
        let first = confirmer.confirm_pairing(&store, &parsed.code, &req).await;
        assert!(first.is_ok(), "首次使用应成功，实际: {first:?}");

        // 会话已清除 → 同凭证再次 confirm 失败
        let second = confirmer.confirm_pairing(&store, &parsed.code, &req).await;
        assert!(second.is_err(), "凭证单次使用：第二次应失败");
        assert!(
            confirmer.current_pairing_session().is_none(),
            "配对成功后会话应清除"
        );
    });
}

/// 验收 9：格式合法但与会话不匹配的 nonce 计入 failed_attempts，满 5 清会话。
#[test]
fn credential_nonce_mismatch_counts_toward_attempt_limit() {
    rt().block_on(async {
        let confirmer = SyncService::new().await.unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        let display = confirmer.begin_pairing_credential().unwrap();
        let parsed = confirmer
            .parse_pairing_credential(&display.credential)
            .unwrap();

        // 格式合法（32 hex 字符）但与会话不匹配的 nonce
        let wrong = if parsed.nonce == "11111111111111111111111111111111" {
            "22222222222222222222222222222222"
        } else {
            "11111111111111111111111111111111"
        };
        for i in 0..5 {
            let req = requester(&parsed.code, "initiator-brute", "New Phone", wrong);
            assert!(
                confirmer
                    .confirm_pairing(&store, &parsed.code, &req)
                    .await
                    .is_err(),
                "第 {} 次错误 nonce 应失败",
                i + 1
            );
        }
        assert!(
            confirmer.current_pairing_session().is_none(),
            "连续 5 次错误 nonce 应清会话"
        );
        // 会话已清 → 正确凭证也失败
        let ok_req = requester(&parsed.code, "initiator-brute", "New Phone", &parsed.nonce);
        let err = confirmer
            .confirm_pairing(&store, &parsed.code, &ok_req)
            .await
            .unwrap_err();
        assert!(
            err.to_string().contains("no active"),
            "会话清除后应提示无有效配对码，实际: {err:#}"
        );
    });
}

/// 验收 10：凭证直连——目标身份来自凭证内嵌 node id（不经 mDNS）；
/// 无效凭证在连接/发现之前即失败；凭证的 code+nonce 被确认方接受。
#[test]
fn credential_connect_uses_embedded_node_id_without_mdns() {
    rt().block_on(async {
        // 发起方注入日志 sink：断言凭证路径不触发 mDNS 发现事件
        let initiator_sink = Arc::new(CollectingSink::new());
        let confirmer = SyncService::new().await.unwrap();
        confirmer.set_device_name("Trusted PC");
        let initiator = SyncService::new_with_log_sink(initiator_sink.clone())
            .await
            .unwrap();
        let confirmer_store = NoteStore::new(":memory:").unwrap();
        let initiator_store = NoteStore::new(":memory:").unwrap();

        let display = confirmer.begin_pairing_credential().unwrap();

        // 1. 凭证内嵌确认方 node id——无需 mDNS 即可确定目标身份
        let parsed = initiator
            .parse_pairing_credential(&display.credential)
            .unwrap();
        assert_eq!(
            parsed.device_id,
            confirmer.device_id(),
            "凭证必须内嵌确认方 node id（base32），不得依赖 mDNS"
        );

        // 2. 无效凭证：parse 失败先于任何连接/发现（错误是凭证解析错误）
        let err = initiator
            .begin_pairing_connect_with_credential(&initiator_store, "cm1.not-a-credential")
            .await
            .unwrap_err();
        assert!(
            err.to_string().contains("invalid credential")
                || err.to_string().contains("base64")
                || err.to_string().contains("length"),
            "无效凭证应先 parse 失败（不得触发 mDNS/连接），实际: {err:#}"
        );

        // 3. 凭证的 code + nonce 能通过确认方校验（驱动配对握手的数据全来自凭证）
        let req = requester(&parsed.code, "initiator-cred", "New Phone", &parsed.nonce);
        let result = confirmer
            .confirm_pairing(&confirmer_store, &parsed.code, &req)
            .await
            .unwrap();
        assert_eq!(result.peer_id, "initiator-cred");

        // 4. 凭证路径全程未触发 mDNS 发现（无 pairing.discovery 事件）
        let text = initiator_sink
            .snapshot()
            .iter()
            .map(|e| format!("{e:?}"))
            .collect::<Vec<_>>()
            .join("\n");
        assert!(
            !text.contains("pairing.discovery"),
            "凭证路径不得触发 mDNS 发现；实际事件:\n{text}"
        );
    });
}

/// 验收 11：6 位码 + mDNS 路径——TXT 广播携带会话 nonce，发起方回填
/// PairingTarget.nonce 才能配对成功；无 nonce 的旧 TXT（空 nonce）不得配对。
#[test]
fn legacy_six_digit_mdns_pairing_requires_and_accepts_advertised_nonce() {
    rt().block_on(async {
        let mut confirmer = SyncService::new().await.unwrap();
        confirmer.set_device_name("Trusted PC");
        let initiator = SyncService::new().await.unwrap();
        initiator.set_device_name("New Phone");
        let confirmer_store = NoteStore::new(":memory:").unwrap();
        let initiator_store = NoteStore::new(":memory:").unwrap();

        // 6 位码 + mDNS 广播（TXT 携带会话 nonce）
        let code = confirmer
            .begin_pairing_accept_with_advertising()
            .await
            .unwrap();
        let advertised_nonce = confirmer.session_nonce_hex();
        assert!(
            !advertised_nonce.is_empty(),
            "广播的 TXT 必须携带会话 nonce"
        );

        // 若 mDNS 能发现对端（Windows 单机可能 0 台）：PeerInfo.nonce 必须非空
        let peers = initiator.discover_peers().await.unwrap();
        for p in &peers {
            assert!(
                !p.nonce.is_empty(),
                "旧 TXT 无 nonce 不得参与配对，实际 nonce={:?}",
                p.nonce
            );
        }

        // 成功路径：target 携带广播 nonce（等价 PeerInfo.nonce → PairingTarget.nonce）
        let confirmer_id = confirmer.device_id();
        let addrs = confirmer.local_addrs();
        assert!(!addrs.is_empty(), "确认方应至少有一个本地 IPv4 地址");
        let confirmer_code = code.clone();
        // NoteStore 是共享句柄（内部 Arc），clone 供 spawn 后继续用
        let confirmer_store_for_confirm = confirmer_store.clone();
        let confirmer_handle = tokio::spawn(async move {
            let request = tokio::time::timeout(
                std::time::Duration::from_secs(15),
                confirmer.accept_pairing_request(),
            )
            .await
            .expect("confirmer accept 挂起")
            .unwrap();
            let result = tokio::time::timeout(
                std::time::Duration::from_secs(15),
                confirmer.confirm_pairing(&confirmer_store_for_confirm, &confirmer_code, &request),
            )
            .await
            .expect("confirmer confirm 挂起")
            .unwrap();
            (result, request, confirmer)
        });
        let target_ok = PairingTarget {
            device_id: confirmer_id.clone(),
            ips: addrs,
            nonce: advertised_nonce.clone(),
        };
        let initiator_handle = tokio::spawn(async move {
            let result = tokio::time::timeout(
                std::time::Duration::from_secs(15),
                initiator.begin_pairing_connect(&initiator_store, &code, target_ok),
            )
            .await
            .expect("initiator connect 挂起")
            .unwrap();
            // drain 确认方首次全量同步推送
            let _ =
                tokio::time::timeout(std::time::Duration::from_secs(10), initiator.accept_push())
                    .await
                    .ok();
            result
        });
        let (confirm_result, request, confirmer) =
            tokio::time::timeout(std::time::Duration::from_secs(30), confirmer_handle)
                .await
                .expect("confirmer task 挂起")
                .unwrap();
        let connect_result =
            tokio::time::timeout(std::time::Duration::from_secs(30), initiator_handle)
                .await
                .expect("initiator task 挂起")
                .unwrap();
        assert_eq!(connect_result.peer_id, confirmer_id);
        assert_eq!(
            request.nonce, advertised_nonce,
            "6 位码路径请求必须携带 TXT 广播的 nonce"
        );
        assert_eq!(confirm_result.peer_id, request.device_id);

        // 无 nonce 的旧 TXT 不得配对：空 nonce 请求即使码正确也被拒
        let code2 = confirmer.begin_pairing_accept().unwrap();
        let req_no_nonce = requester(&code2, "initiator-old-txt", "Old Phone", "");
        let err = confirmer
            .confirm_pairing(&confirmer_store, &code2, &req_no_nonce)
            .await
            .unwrap_err();
        assert!(
            err.to_string().contains("nonce"),
            "旧 TXT 无 nonce 应被拒，实际: {err:#}"
        );
    });
}

/// 验收 12：凭证（完整串 / base64 body / 6 位码）绝不进入调试日志。
#[test]
fn credential_never_enters_debug_logs() {
    rt().block_on(async {
        let dir = temp_dir("no-leak");
        let sink = Arc::new(CollectingSink::new());
        let confirmer = SyncService::new_persistent_with_log_sink(&dir, sink.clone())
            .await
            .unwrap();

        let display = confirmer.begin_pairing_credential().unwrap();
        // 解析动作本身也不得把凭证写入日志
        let _parsed = confirmer
            .parse_pairing_credential(&display.credential)
            .unwrap();

        let text = sink
            .snapshot()
            .iter()
            .map(|e| format!("{e:?}"))
            .collect::<Vec<_>>()
            .join("\n");
        assert!(!text.contains(&display.credential), "完整凭证不得进入日志");
        let body = &display.credential[4..];
        assert!(!text.contains(body), "凭证 body（base64url）不得进入日志");
        assert!(!text.contains(&display.code), "6 位码不得进入日志");
        let _ = std::fs::remove_dir_all(&dir);
    });
}

/// 验收 13：空 nonce、全零 nonce、格式错误 nonce 一律拒绝并计入失败次数。
#[test]
fn empty_and_zero_nonce_are_rejected() {
    rt().block_on(async {
        let confirmer = SyncService::new().await.unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        let code = confirmer.begin_pairing_accept().unwrap();

        // 空 nonce
        let req_empty = requester(&code, "initiator-empty", "New Phone", "");
        let err = confirmer
            .confirm_pairing(&store, &code, &req_empty)
            .await
            .unwrap_err();
        assert!(
            err.to_string().contains("nonce"),
            "空 nonce 应被拒，实际: {err:#}"
        );

        // 全零 nonce（旧帧缺省值）
        let req_zero = requester(
            &code,
            "initiator-zero",
            "New Phone",
            "00000000000000000000000000000000",
        );
        let err = confirmer
            .confirm_pairing(&store, &code, &req_zero)
            .await
            .unwrap_err();
        assert!(
            err.to_string().contains("nonce"),
            "全零 nonce 应被拒，实际: {err:#}"
        );

        // 格式错误（非 hex / 长度非法）
        let req_bad = requester(&code, "initiator-bad", "New Phone", "zzzz");
        let err = confirmer
            .confirm_pairing(&store, &code, &req_bad)
            .await
            .unwrap_err();
        assert!(
            err.to_string().contains("nonce"),
            "格式错误 nonce 应被拒，实际: {err:#}"
        );

        // 错误 nonce 计入 failed_attempts：已累计 3 次，再错 2 次满 5 → 清会话
        for _ in 0..2 {
            let _ = confirmer.confirm_pairing(&store, &code, &req_zero).await;
        }
        assert!(
            confirmer.current_pairing_session().is_none(),
            "满 5 次错误 nonce 应清会话"
        );
    });
}
