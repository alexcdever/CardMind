//! Frozen security acceptance tests for inbound authorization, bounded frames, and pairing identity.

use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::{
    decode_device_name_frame, decode_pairing_request, decode_pairing_response,
    encode_pairing_request, pairing_identity_matches, validate_pairing_request_identity,
    PairingRequest, PairingResponse, SyncService,
};

fn rt() -> tokio::runtime::Runtime {
    tokio::runtime::Runtime::new().unwrap()
}

fn valid_request(device_id: &str) -> PairingRequest {
    PairingRequest {
        code: "123456".to_string(),
        device_id: device_id.to_string(),
        device_name: "Test device".to_string(),
        relay_info: String::new(),
        ips: vec!["127.0.0.1:1234".to_string()],
        nonce: "00112233445566778899aabbccddeeff".to_string(),
    }
}

#[test]
fn unauthorized_peer_cannot_import_or_update_presence() {
    rt().block_on(async {
        let target = SyncService::new().await.unwrap();
        let target_store = NoteStore::new(":memory:").unwrap();
        let mut unknown = SyncService::new().await.unwrap();
        unknown
            .create_note("remote".to_string(), "# hostile\\n\\nbody")
            .unwrap();
        target.start_receiver(target_store.clone()).await.unwrap();

        let push = unknown
            .push_to_peer(&target.device_id(), target.local_addrs())
            .await;
        assert!(
            push.is_ok(),
            "transport delivery may succeed while authorization rejects import"
        );
        assert_eq!(target.get_note("remote"), None);
        assert!(target_store.list_paired_devices().unwrap().is_empty());
        target.stop_receiver().await.unwrap();
    });
}

#[test]
fn oversized_inbound_frames_are_rejected() {
    let mut request = valid_request("peer");
    request.device_name = "x".repeat(5000);
    let result =
        std::panic::catch_unwind(|| decode_pairing_request(&encode_pairing_request(&request)));
    assert!(result.is_ok());
    assert!(result.unwrap().is_err());

    let mut over_count = vec![0x01];
    for _ in 0..4 {
        over_count.extend_from_slice(&0u32.to_le_bytes());
    }
    over_count.extend_from_slice(&u32::MAX.to_le_bytes());
    let result = std::panic::catch_unwind(|| decode_pairing_request(&over_count));
    assert!(result.is_ok());
    assert!(result.unwrap().is_err());

    let mut name = vec![0x03];
    name.extend_from_slice(&(5000u32).to_le_bytes());
    name.extend(std::iter::repeat_n(b'x', 5000));
    let result = std::panic::catch_unwind(|| decode_device_name_frame(&name));
    assert!(result.is_ok());
    assert!(result.unwrap().is_err());
}

#[test]
fn pairing_identity_must_match_transport() {
    rt().block_on(async {
        let mut receiver = SyncService::new().await.unwrap();
        let sender = SyncService::new().await.unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        let code = receiver.begin_pairing_accept().unwrap();
        let request = PairingRequest {
            code,
            device_id: "spoofed-identity".to_string(),
            device_name: "spoofed".to_string(),
            relay_info: String::new(),
            ips: vec![],
            nonce: receiver.session_nonce_hex(),
        };
        let target = cardmind_backend::sync::PairingTarget {
            device_id: receiver.device_id(),
            ips: receiver.local_addrs(),
            nonce: request.nonce.clone(),
        };
        let accept = tokio::spawn(async move {
            receiver
                .receive_pairing_request_for_test(std::time::Duration::from_secs(2))
                .await
        });
        assert!(sender
            .send_pairing_request_for_test(target, request)
            .await
            .is_ok());
        let rejected = accept.await.unwrap().unwrap_err();
        assert!(rejected.to_string().contains("identity"));
        assert!(store.list_paired_devices().unwrap().is_empty());
        assert!(pairing_identity_matches(
            "authenticated-remote",
            "authenticated-remote"
        ));
        assert!(!validate_pairing_request_identity(
            "authenticated-remote",
            &valid_request("spoofed-identity")
        )
        .is_ok());
    });
}

#[test]
fn pairing_response_decoder_rejects_oversized_fields() {
    let response = PairingResponse {
        device_id: "x".repeat(5000),
        device_name: "name".to_string(),
    };
    let mut data = vec![0x02];
    data.extend_from_slice(&(5000u32).to_le_bytes());
    data.extend(std::iter::repeat_n(b'x', 5000));
    data.extend_from_slice(&4u32.to_le_bytes());
    data.extend_from_slice(b"name");
    let _ = response;
    let result = std::panic::catch_unwind(|| decode_pairing_response(&data));
    assert!(result.is_ok());
    assert!(result.unwrap().is_err());
}
