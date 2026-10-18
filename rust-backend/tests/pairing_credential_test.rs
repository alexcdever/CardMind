//! 签名配对凭证协议测试（任务 Q 验收标准 1-13）。
//!
//! 协议层（无网络）：canonical layout、base64url、验签、篡改拒绝、
//! 长度/前缀/版本/时间窗口校验。
//! 行为层（SyncService 集成）：新凭证替换旧会话、单次使用、nonce 强制校验
//! 与失败计数、凭证直连（内嵌 node id、不经 mDNS）、6 位码+mDNS 路径
//! 使用广播 nonce、凭证不进调试日志、空/全零 nonce 拒绝。

mod common;

use std::sync::Arc;

use cardmind_backend::debug_log::{CollectingSink, LogEvent};
use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::{
    credential_from_string, credential_to_string, encode_credential, encode_credential_v2,
    parse_credential, PairingCredentialErrorKind, PairingTarget, ParsedCredentialFields,
    SyncService, CREDENTIAL_FINAL_LEN,
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

use common::{requester, rt, temp_dir};

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
            ips: Vec::new(),
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
    assert_eq!(roundtrip.as_slice(), raw.as_slice());
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
    // 未知版本（v1/v2 之外）
    let mut bad = raw;
    bad[2] = 3;
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

// ━━━ v2 凭证：内嵌直连地址（task pairing-credential-ip）━━━

/// A2：v2 往返——N 个 IP 原样取回且顺序一致；签名覆盖含 IP 的完整 payload。
#[test]
fn credential_v2_roundtrips_ips_in_order() {
    let sk = fixed_sk();
    let node_id = fixed_node_id(&sk);
    let nonce = fixed_nonce();
    let ips = vec![
        "192.168.31.43:62023".to_string(),
        "10.0.0.7:12345".to_string(),
        "127.0.0.1:9999".to_string(),
    ];

    let raw = encode_credential_v2(&sk, ISSUED, EXPIRES, &nonce, &node_id, CODE, &ips).unwrap();
    // canonical payload = 73 + Σ(2 + len)，后接 64 字节签名
    let expected_payload = 73 + ips.iter().map(|s| 2 + s.len()).sum::<usize>();
    assert_eq!(raw.len(), expected_payload + 64);
    assert_eq!(raw[2], 2, "v2 版本字节必须为 2");
    assert_eq!(&raw[0..2], b"CM");
    assert_eq!(&raw[71..73], &(ips.len() as u16).to_be_bytes());

    let parsed = parse_credential(&raw, ISSUED + 1).unwrap();
    assert_eq!(parsed.ips, ips, "IP 列表与顺序必须原样取回");
    assert_eq!(parsed.pairing_code, CODE);
    assert_eq!(parsed.node_id_bytes, node_id);
    assert_eq!(parsed.nonce, nonce);
    assert_eq!(parsed.expires_at, EXPIRES);

    // base64url 字符串编解码同样往返一致
    let s = credential_to_string(&raw);
    let back = credential_from_string(&s).unwrap();
    assert_eq!(back.as_slice(), raw.as_slice());
}

/// A2 边界：ip_count = 0 的 v2 凭证可正常解析。
#[test]
fn credential_v2_with_zero_ips_parses() {
    let sk = fixed_sk();
    let node_id = fixed_node_id(&sk);
    let nonce = fixed_nonce();
    let raw = encode_credential_v2(&sk, ISSUED, EXPIRES, &nonce, &node_id, CODE, &[]).unwrap();
    assert_eq!(raw.len(), 73 + 64);
    assert_eq!(&raw[71..73], &0u16.to_be_bytes());

    let parsed = parse_credential(&raw, ISSUED + 1).unwrap();
    assert!(parsed.ips.is_empty(), "ip_count=0 时 ips 应为空");
    assert_eq!(parsed.pairing_code, CODE);
}

/// A2：篡改任一 IP 字节或 ip_count → 验签失败或解析失败。
#[test]
fn credential_v2_rejects_tampered_ips_and_count() {
    let sk = fixed_sk();
    let node_id = fixed_node_id(&sk);
    let nonce = fixed_nonce();
    let ips = vec![
        "192.168.31.43:62023".to_string(),
        "10.0.0.7:12345".to_string(),
    ];
    let raw = encode_credential_v2(&sk, ISSUED, EXPIRES, &nonce, &node_id, CODE, &ips).unwrap();

    // 逐字节翻转 IP 数据区 [73..len-64]
    for idx in 73..raw.len() - 64 {
        let mut t = raw.clone();
        t[idx] ^= 0xFF;
        assert!(
            parse_credential(&t, ISSUED + 1).is_err(),
            "篡改 IP payload 字节 {idx} 应被拒（验签或解析）"
        );
    }
    // 篡改 ip_count 两个字节
    for idx in [71, 72] {
        let mut t = raw.clone();
        t[idx] ^= 0x01;
        assert!(
            parse_credential(&t, ISSUED + 1).is_err(),
            "篡改 ip_count 字节 {idx} 应被拒"
        );
    }
    // 篡改签名字节
    for idx in [raw.len() - 64, raw.len() - 1] {
        let mut t = raw.clone();
        t[idx] ^= 0x01;
        assert!(parse_credential(&t, ISSUED + 1).is_err(), "篡改签名 {idx}");
    }
}

/// A2：超长 IP 字符串（> u16 上限）不得 panic，返回 Err。
#[test]
fn credential_v2_rejects_overlong_ip_without_panic() {
    let sk = fixed_sk();
    let node_id = fixed_node_id(&sk);
    let nonce = fixed_nonce();
    let huge = "a".repeat(u16::MAX as usize + 1);
    let result = encode_credential_v2(&sk, ISSUED, EXPIRES, &nonce, &node_id, CODE, &[huge]);
    assert!(result.is_err(), "超长 IP 应返回 Err 而非 panic");
}

/// A3：`begin_pairing_credential` 产物的 `ips` 等于 `svc.local_addrs()`。
///
/// 前提：凭证生成的 v2 载荷内嵌本机直连地址。若测试环境无 IPv4 网络接口，
/// `local_addrs()` 为空 → v2 凭证 `ips` 也为空（仍是合法 v2 凭证），
/// 此时按契约显式标注该环境前提，断言退化为相等断言而非非空断言。
#[test]
fn generated_credential_contains_local_addrs() {
    rt().block_on(async {
        let svc = SyncService::new().await.unwrap();
        let display = svc.begin_pairing_credential().unwrap();
        let parsed = svc.parse_pairing_credential(&display.credential).unwrap();

        let local = svc.local_addrs();
        assert_eq!(parsed.ips, local, "凭证内嵌 IP 必须等于 svc.local_addrs()");

        if local.is_empty() {
            eprintln!(
                "NOTE[A3]: 本测试环境无 IPv4 网络接口，local_addrs() 为空；\
                 已按契约显式标注该前提，未放宽为非空断言"
            );
        } else {
            for ip in &parsed.ips {
                assert!(ip.contains(':'), "IP 必须为 ip:port 格式，实际: {ip}");
                assert!(
                    ip.parse::<std::net::SocketAddr>().is_ok(),
                    "IP 必须可解析为 SocketAddr，实际: {ip}"
                );
            }
        }
    });
}

/// A4（seam）：连接目标 `PairingTarget.ips` 来自凭证解析结果，而非 `vec![]`。
///
/// seam = `SyncService::pairing_target_for_credential`：`begin_pairing_connect_with_credential`
/// 内部唯一使用的「parse → 构造 PairingTarget」步骤。把该步骤暴露为可观测方法后，
/// 无需发起真实连接即可断言 target.ips 来自 parsed.ips。若有人把 ips 硬编码回 `vec![]`，
/// 本断言（parsed.ips == 显示方 local_addrs，非空）立即变红。
/// 另断言 `build_connect_addr(node_id, &non_empty_ips)` 返回的 EndpointAddr 含 IP 传输地址。
#[test]
fn credential_connect_target_ips_come_from_credential() {
    rt().block_on(async {
        let confirmer = SyncService::new().await.unwrap();
        let initiator = SyncService::new().await.unwrap();

        let display = confirmer.begin_pairing_credential().unwrap();
        let confirmer_local = confirmer.local_addrs();

        let target = initiator
            .pairing_target_for_credential(&display.credential)
            .unwrap();
        assert_eq!(
            target.ips, confirmer_local,
            "PairingTarget.ips 必须来自凭证内嵌 IP（回归：曾被硬编码为 vec![]）"
        );
        assert_eq!(target.device_id, confirmer.device_id());

        // build_connect_addr：非空 ips → EndpointAddr 含等量 IP 传输地址
        let node_id: iroh::EndpointId = target.device_id.parse().unwrap();
        let addr = initiator.build_connect_addr(node_id, &target.ips).unwrap();
        if !target.ips.is_empty() {
            let ip_addrs: Vec<_> = addr.ip_addrs().copied().collect();
            assert_eq!(
                ip_addrs.len(),
                target.ips.len(),
                "非空 ips 必须映射为等量 TransportAddr::Ip"
            );
        } else {
            eprintln!(
                "NOTE[A4]: 本测试环境无 IPv4 网络接口，local_addrs() 为空；\
                 已按契约显式标注该前提"
            );
        }
    });
}

/// A4（真实链路）：发起方仅凭凭证（内嵌 IP）完成连接 + 配对握手。
///
/// 若 `begin_pairing_connect_with_credential` 用 `vec![]`，在无 relay 的测试环境下
/// 只剩 n0 DNS 解析路径，必然超时 → 本用例变红。这是「忘了传 ips」回归的端到端捕获。
#[test]
fn credential_connect_end_to_end_uses_embedded_ips() {
    rt().block_on(async {
        let mut confirmer = SyncService::new().await.unwrap();
        confirmer.set_device_name("Trusted PC");
        let initiator = SyncService::new().await.unwrap();
        initiator.set_device_name("New Phone");
        let confirmer_store = NoteStore::new(":memory:").unwrap();
        let initiator_store = NoteStore::new(":memory:").unwrap();

        assert!(
            !confirmer.local_addrs().is_empty(),
            "前提：测试环境需至少一个 IPv4 网络接口（local_addrs 非空），否则本链路用例不适用"
        );

        let display = confirmer.begin_pairing_credential().unwrap();
        let parsed = confirmer
            .parse_pairing_credential(&display.credential)
            .unwrap();

        let confirmer_id = confirmer.device_id();
        let confirmer_code = parsed.code.clone();
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
            (result, request)
        });

        let credential = display.credential.clone();
        let initiator_handle = tokio::spawn(async move {
            let result = tokio::time::timeout(
                std::time::Duration::from_secs(20),
                initiator.begin_pairing_connect_with_credential(&initiator_store, &credential),
            )
            .await
            .expect("initiator credential connect 挂起")
            .expect("凭证直连应成功（凭证内嵌 IP）");
            // drain 确认方首次全量同步推送
            let _ =
                tokio::time::timeout(std::time::Duration::from_secs(10), initiator.accept_push())
                    .await
                    .ok();
            result
        });

        let (confirm_result, request) =
            tokio::time::timeout(std::time::Duration::from_secs(40), confirmer_handle)
                .await
                .expect("confirmer task 挂起")
                .unwrap();
        let connect_result =
            tokio::time::timeout(std::time::Duration::from_secs(40), initiator_handle)
                .await
                .expect("initiator task 挂起")
                .unwrap();

        assert_eq!(
            connect_result.peer_id, confirmer_id,
            "发起方握手响应应回填确认方 node id"
        );
        assert_eq!(
            confirm_result.peer_id, request.device_id,
            "确认方配对结果应为发起方 node id"
        );
    });
}

// ━━━ 任务 pairing-credential-used-kind：握手期拒绝的稳定分类 ━━━
/// 事件里某个安全字段的取值。
fn event_field<'a>(event: &'a LogEvent, key: &str) -> Option<&'a str> {
    event
        .fields
        .iter()
        .find(|(k, _)| k == key)
        .map(|(_, v)| v.as_str())
}

/// 渲染事件序列为可搜索文本（隐私断言：所有字段都会出现在其中）。
fn render_events(events: &[LogEvent]) -> String {
    events
        .iter()
        .map(|e| format!("{e:?}"))
        .collect::<Vec<_>>()
        .join("\n")
}

/// 取「指定事件名 + action」的事件（稳定契约断言用）。
fn find_event<'a>(events: &'a [LogEvent], event: &str, action: &str) -> Option<&'a LogEvent> {
    events
        .iter()
        .find(|e| e.event == event && event_field(e, "action") == Some(action))
}

/// 验收 1：**用过的凭证**再次配对 → `usedOrReplaced`（不再是 `unreachable`）。
///
/// 真实链路（进程内 QUIC 握手）：显示方生成凭证 A → 发起方用 A 配对成功（会话被清空）
/// → 发起方**再次**用同一张 A → 确认方以「会话已清空」拒绝，拒绝原因必须回传到发起方。
///
/// 同时覆盖验收 6：拒绝路径的 `pairing.connect` / `pairing.confirm` 事件名与 action 取值
/// 不变、只携带稳定原因码，nonce / 6 位码 / 凭证全文 / 完整节点 ID 都不进日志。
#[test]
fn used_credential_is_classified_as_used_or_replaced() {
    use std::time::Duration;

    rt().block_on(async {
        let confirmer_sink = Arc::new(CollectingSink::new());
        let initiator_sink = Arc::new(CollectingSink::new());
        let mut confirmer = SyncService::new_with_log_sink(confirmer_sink.clone())
            .await
            .unwrap();
        confirmer.set_device_name("Trusted PC");
        let initiator = SyncService::new_with_log_sink(initiator_sink.clone())
            .await
            .unwrap();
        initiator.set_device_name("New Phone");
        let confirmer_store = NoteStore::new(":memory:").unwrap();
        let initiator_store = NoteStore::new(":memory:").unwrap();

        assert!(
            !confirmer.local_addrs().is_empty(),
            "前提：测试环境需至少一个 IPv4 网络接口（local_addrs 非空）"
        );

        let display = confirmer.begin_pairing_credential().unwrap();
        let parsed = confirmer
            .parse_pairing_credential(&display.credential)
            .unwrap();
        let credential = display.credential.clone();
        let code = parsed.code.clone();
        let confirmer_id = confirmer.device_id();

        // ── 第一轮：正常配对成功（凭证被用掉 → 会话清空）──
        let confirmer_store_first = confirmer_store.clone();
        let code_first = code.clone();
        let confirmer_handle = tokio::spawn(async move {
            let request =
                tokio::time::timeout(Duration::from_secs(15), confirmer.accept_pairing_request())
                    .await
                    .expect("confirmer accept 挂起")
                    .expect("confirmer 应收到配对请求");
            let result = tokio::time::timeout(
                Duration::from_secs(15),
                confirmer.confirm_pairing(&confirmer_store_first, &code_first, &request),
            )
            .await
            .expect("confirmer confirm 挂起")
            .expect("首次配对应成功");
            (confirmer, result)
        });
        let initiator_store_first = initiator_store.clone();
        let credential_first = credential.clone();
        let initiator_handle = tokio::spawn(async move {
            let result = tokio::time::timeout(
                Duration::from_secs(20),
                initiator.begin_pairing_connect_with_credential(
                    &initiator_store_first,
                    &credential_first,
                ),
            )
            .await
            .expect("initiator 凭证连接挂起")
            .expect("凭证直连应成功（凭证内嵌 IP）");
            // drain 确认方首次全量同步推送
            let _ = tokio::time::timeout(Duration::from_secs(10), initiator.accept_push()).await;
            (initiator, result)
        });

        let (mut confirmer, confirm_first) =
            tokio::time::timeout(Duration::from_secs(40), confirmer_handle)
                .await
                .expect("confirmer task 挂起")
                .unwrap();
        let (initiator, connect_first) =
            tokio::time::timeout(Duration::from_secs(40), initiator_handle)
                .await
                .expect("initiator task 挂起")
                .unwrap();
        assert_eq!(connect_first.peer_id, confirmer_id);
        assert_eq!(confirm_first.peer_id, initiator.device_id());
        assert!(
            confirmer.current_pairing_session().is_none(),
            "配对成功后会话应清空（凭证单次使用）"
        );
        let baseline_initiator = initiator_sink.snapshot().len();
        let baseline_confirmer = confirmer_sink.snapshot().len();

        // ── 第二轮：同一张用过的凭证 → usedOrReplaced ──
        let confirmer_store_second = confirmer_store.clone();
        let code_second = code.clone();
        let confirmer_handle = tokio::spawn(async move {
            let request =
                tokio::time::timeout(Duration::from_secs(15), confirmer.accept_pairing_request())
                    .await
                    .expect("confirmer accept（第二轮）挂起")
                    .expect("confirmer 应收到第二轮的配对请求");
            // UI 契约（决策 25）：confirm 只允许用当前显示的那一份 code
            let err = confirmer
                .confirm_pairing(&confirmer_store_second, &code_second, &request)
                .await
                .expect_err("会话已清空，confirm 必须拒绝");
            (confirmer, err.to_string())
        });

        let started = std::time::Instant::now();
        let err = tokio::time::timeout(
            Duration::from_secs(20),
            initiator.begin_pairing_connect_with_credential(&initiator_store, &credential),
        )
        .await
        .expect("拒绝信号未在 20s 内送达（用过的凭证被当成连不上）")
        .expect_err("用过的凭证不得配对成功");
        let elapsed = started.elapsed();
        let (_confirmer, confirm_err) =
            tokio::time::timeout(Duration::from_secs(30), confirmer_handle)
                .await
                .expect("confirmer task（第二轮）挂起")
                .unwrap();

        assert!(
            confirm_err.contains("no active"),
            "第二轮确认方应因无会话被拒，实际: {confirm_err}"
        );
        assert_eq!(
            err.kind,
            PairingCredentialErrorKind::UsedOrReplaced,
            "用过的凭证应归类 usedOrReplaced；实际 kind={:?} message={}（耗时 {elapsed:?}）",
            err.kind,
            err.message
        );

        // ── 验收 6：事件契约 + 日志隐私 ──
        let initiator_events = initiator_sink.snapshot();
        let tail = &initiator_events[baseline_initiator..];
        assert!(
            find_event(tail, "pairing.connect", "start").is_some(),
            "拒绝路径必须继续发 pairing.connect action=start，实际: {}",
            render_events(tail)
        );
        let failed = find_event(tail, "pairing.connect", "failed").unwrap_or_else(|| {
            panic!(
                "拒绝路径必须继续发 pairing.connect action=failed，实际: {}",
                render_events(tail)
            )
        });
        assert_eq!(
            event_field(failed, "reason"),
            Some("usedOrReplaced"),
            "拒绝原因必须以稳定原因码进日志，实际: {failed:?}"
        );
        let text = render_events(tail);
        assert!(!text.contains(&parsed.nonce), "nonce 不得进日志");
        assert!(!text.contains(&credential), "凭证全文不得进日志");
        assert!(!text.contains(&code), "6 位码不得进日志");
        assert!(!text.contains(&confirmer_id), "完整节点 ID 不得进日志");

        let confirmer_events = confirmer_sink.snapshot();
        let tail = &confirmer_events[baseline_confirmer..];
        let confirm_failed = find_event(tail, "pairing.confirm", "failed").unwrap_or_else(|| {
            panic!(
                "确认方拒绝必须发 pairing.confirm action=failed，实际: {}",
                render_events(tail)
            )
        });
        assert_eq!(
            event_field(confirm_failed, "reason"),
            Some("usedOrReplaced"),
            "确认方拒绝日志应带稳定原因码，实际: {confirm_failed:?}"
        );
        assert_eq!(
            event_field(confirm_failed, "reject_frame"),
            Some("sent"),
            "确认方必须确实把拒绝帧写出（reject_frame=sent），实际: {confirm_failed:?}"
        );
        let text = render_events(tail);
        assert!(!text.contains(&parsed.nonce), "nonce 不得进确认方日志");
        assert!(!text.contains(&credential), "凭证全文不得进确认方日志");
        assert!(!text.contains(&code), "6 位码不得进确认方日志");
        assert!(
            !text.contains(&initiator.device_id()),
            "完整节点 ID 不得进确认方日志"
        );
    });
}

/// 验收 2：**被取代的凭证** → `usedOrReplaced`。
///
/// 显示方生成 A 后「重新生成」B（A 随之失效）。发起方仍用 A：确认方按 UI 契约用
/// 当前那一份 code（B）确认，请求里的码（A）与会话不一致 → 拒绝；发起方必须看到
/// 「已使用或已被替代」，而不是「无法连接到对方设备」。
#[test]
fn replaced_credential_is_classified_as_used_or_replaced() {
    use std::time::Duration;

    rt().block_on(async {
        let mut confirmer = SyncService::new().await.unwrap();
        confirmer.set_device_name("Trusted PC");
        let initiator = SyncService::new().await.unwrap();
        initiator.set_device_name("New Phone");
        let confirmer_store = NoteStore::new(":memory:").unwrap();
        let initiator_store = NoteStore::new(":memory:").unwrap();

        assert!(
            !confirmer.local_addrs().is_empty(),
            "前提：测试环境需至少一个 IPv4 网络接口（local_addrs 非空）"
        );

        let first = confirmer.begin_pairing_credential().unwrap(); // A
        let second = confirmer.begin_pairing_credential().unwrap(); // B（取代 A）
        assert_ne!(first.code, second.code, "重新生成必须换码");
        let second_code = second.code.clone();

        let confirmer_store_confirm = confirmer_store.clone();
        let confirmer_handle = tokio::spawn(async move {
            let request =
                tokio::time::timeout(Duration::from_secs(15), confirmer.accept_pairing_request())
                    .await
                    .expect("confirmer accept 挂起")
                    .expect("confirmer 应收到配对请求");
            let err = confirmer
                .confirm_pairing(&confirmer_store_confirm, &second_code, &request)
                .await
                .expect_err("旧凭证的码与会话不一致，confirm 必须拒绝");
            (confirmer, err.to_string())
        });

        let err = tokio::time::timeout(
            Duration::from_secs(20),
            initiator.begin_pairing_connect_with_credential(&initiator_store, &first.credential),
        )
        .await
        .expect("拒绝信号未在 20s 内送达（被取代的凭证被当成连不上）")
        .expect_err("被取代的凭证不得配对成功");

        let (confirmer, confirm_err) =
            tokio::time::timeout(Duration::from_secs(30), confirmer_handle)
                .await
                .expect("confirmer task 挂起")
                .unwrap();

        assert!(
            confirm_err.contains("code"),
            "被取代的凭证应因码不匹配被拒，实际: {confirm_err}"
        );
        assert_eq!(
            err.kind,
            PairingCredentialErrorKind::UsedOrReplaced,
            "被取代的凭证应归类 usedOrReplaced；实际 kind={:?} message={}",
            err.kind,
            err.message
        );
        assert_eq!(
            confirmer.current_pairing_session().map(|s| s.code),
            Some(second.code.clone()),
            "拒绝旧凭证不得清掉新会话"
        );
    });
}

// ━━━ 守护：不得把「连不上」误报成「已使用」，解析期分类不回归 ━━━

/// 构造「签名有效」的 v2 凭证（测试用；不经过 SyncService 会话）。
///
/// [sk] 同时作为凭证载荷里的 node id 与签名密钥：凭证解析通过后，连接目标身份
/// 与凭证声明一致（用于模拟无监听地址与「旧对端」）。
fn credential_signed_by(sk: &SecretKey, ips: &[String]) -> String {
    let node_id = *sk.public().as_bytes();
    let now = chrono::Utc::now().timestamp() as u64;
    let nonce: [u8; 16] = [9u8; 16];
    let raw = encode_credential_v2(sk, now, now + 600, &nonce, &node_id, 424242, ips).unwrap();
    credential_to_string(&raw)
}

/// 验收 3：目标地址**无监听**（连接被拒）→ 仍归 `unreachable`（「无法连接到对方设备」），
/// **不得**误报成「已使用或已被替代」。
#[test]
fn unreachable_target_with_closed_port_stays_unreachable() {
    use std::time::Duration;

    rt().block_on(async {
        // 关闭端口：loopback 上无监听（与 connect_test 的假设备同款「快速失败」地址）
        let signer = SecretKey::generate();
        let credential = credential_signed_by(&signer, &["127.0.0.1:1".to_string()]);
        let initiator = SyncService::new().await.unwrap();
        let store = NoteStore::new(":memory:").unwrap();

        let started = std::time::Instant::now();
        let err = tokio::time::timeout(
            Duration::from_secs(90),
            initiator.begin_pairing_connect_with_credential(&store, &credential),
        )
        .await
        .expect("连不上路径不得挂住")
        .expect_err("无监听地址不得配对成功");
        let elapsed = started.elapsed();

        assert_eq!(
            err.kind,
            PairingCredentialErrorKind::Unreachable,
            "连不上必须归 unreachable（不得误报已使用）；实际 kind={:?} message={}",
            err.kind,
            err.message
        );
        // 基线（本机实测）：iroh 对「无监听 UDP 端口」的 QUIC 握手超时 ≈ 30.0s，
        // 这不是本次改动引入的等待；这里用 60s 上界防止后续再叠加固定等待。
        assert!(
            elapsed < Duration::from_secs(60),
            "连不上不得叠加额外等待（基线 ~30s），实际 {elapsed:?}"
        );
    });
}

/// 验收 4：**旧对端不发送拒绝帧**（读到流结束 / 无帧）→ 仍归 `unreachable`，
/// 且不得为此新增固定等待时间。
///
/// 用原始 iroh 端点模拟旧对端：收下配对请求帧后开一条**空响应流**并 finish
/// （不回任何帧），保持连接直到发起方读完关闭——正是「旧实现」的线行为。
#[test]
fn legacy_peer_without_rejection_frame_stays_unreachable() {
    use std::time::Duration;

    rt().block_on(async {
        const ALPN: &[u8] = b"cardmind-v2";
        let peer_key = SecretKey::generate();
        let peer = iroh::Endpoint::builder(iroh::endpoint::presets::Minimal)
            .secret_key(peer_key.clone())
            .alpns(vec![ALPN.to_vec()])
            .relay_mode(iroh::RelayMode::Disabled)
            .bind()
            .await
            .expect("旧对端 bind");
        let ips: Vec<String> = peer
            .addr()
            .ip_addrs()
            .filter(|a| a.is_ipv4())
            .map(|a| a.to_string())
            .collect();
        assert!(!ips.is_empty(), "前提：原始端点需至少一个 IPv4 地址");

        let peer_task = tokio::spawn(async move {
            let incoming = peer.accept().await.expect("旧对端 accept");
            let conn = incoming
                .accept()
                .expect("旧对端 accept conn")
                .await
                .expect("旧对端连接建立");
            let mut recv = conn.accept_uni().await.expect("旧对端 accept uni");
            let _ = recv.read_to_end(1024 * 1024).await.expect("旧对端读请求");
            // 旧行为：不回任何帧，只开一条空流并结束
            let mut send = conn.open_uni().await.expect("旧对端 open uni");
            send.finish().expect("旧对端 finish");
            let _ = tokio::time::timeout(Duration::from_secs(10), conn.closed()).await;
        });

        let credential = credential_signed_by(&peer_key, &ips);
        let initiator = SyncService::new().await.unwrap();
        let store = NoteStore::new(":memory:").unwrap();

        let started = std::time::Instant::now();
        let err = tokio::time::timeout(
            Duration::from_secs(20),
            initiator.begin_pairing_connect_with_credential(&store, &credential),
        )
        .await
        .expect("无帧路径不得挂住")
        .expect_err("旧对端不回帧时不得配对成功");
        let elapsed = started.elapsed();

        assert_eq!(
            err.kind,
            PairingCredentialErrorKind::Unreachable,
            "无帧（流结束）必须仍归 unreachable；实际 kind={:?} message={}",
            err.kind,
            err.message
        );
        assert!(
            elapsed < Duration::from_secs(5),
            "无帧路径不得引入固定等待，实际 {elapsed:?}"
        );
        peer_task.await.unwrap();
    });
}

/// 验收 5：解析期分类不回归——格式错 / 签名错 / 已过期三类仍各自归类，
/// 不被握手期新增的「已使用/已被替代」吸收。
#[test]
fn credential_parse_classification_does_not_regress() {
    use std::time::Duration;

    rt().block_on(async {
        let initiator = SyncService::new().await.unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        let started = std::time::Instant::now();

        // 格式错：前缀对但载荷无效
        let err = initiator
            .begin_pairing_connect_with_credential(&store, "cm1.not-a-credential")
            .await
            .unwrap_err();
        assert_eq!(
            err.kind,
            PairingCredentialErrorKind::InvalidFormat,
            "格式错应归 invalidFormat，实际 {:?} / {}",
            err.kind,
            err.message
        );

        // 签名错：载荷 node id 与签名私钥不一致
        let signer = SecretKey::generate();
        let claimed = SecretKey::generate();
        let now = chrono::Utc::now().timestamp() as u64;
        let raw = encode_credential_v2(
            &signer,
            now,
            now + 600,
            &[5u8; 16],
            claimed.public().as_bytes(),
            111111,
            &[],
        )
        .unwrap();
        let err = initiator
            .begin_pairing_connect_with_credential(&store, &credential_to_string(&raw))
            .await
            .unwrap_err();
        assert_eq!(
            err.kind,
            PairingCredentialErrorKind::InvalidSignature,
            "签名错应归 invalidSignature，实际 {:?} / {}",
            err.kind,
            err.message
        );

        // 已过期：签发在过去、过期时间已越过
        let signer = SecretKey::generate();
        let past = now - 700;
        let raw = encode_credential_v2(
            &signer,
            past,
            past + 600,
            &[6u8; 16],
            signer.public().as_bytes(),
            222222,
            &[],
        )
        .unwrap();
        let err = initiator
            .begin_pairing_connect_with_credential(&store, &credential_to_string(&raw))
            .await
            .unwrap_err();
        assert_eq!(
            err.kind,
            PairingCredentialErrorKind::Expired,
            "过期应归 expired，实际 {:?} / {}",
            err.kind,
            err.message
        );

        assert!(
            started.elapsed() < Duration::from_secs(5),
            "解析期失败必须先于任何连接尝试（无等待）"
        );
    });
}
