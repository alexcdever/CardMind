//! Frozen security acceptance tests for inbound authorization, bounded frames, and pairing identity.

use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::{
    decode_device_name_frame, decode_pairing_request, decode_pairing_response,
    encode_pairing_request, nonce_to_hex, pairing_identity_matches, PairingRequest,
    PairingResponse, SyncService,
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
        let mut service = SyncService::new().await.unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        service
            .create_note("local".to_string(), "# local\n\nbody")
            .unwrap();
        assert!(store.list_paired_devices().unwrap().is_empty());
        assert!(service
            .try_accept_push(std::time::Duration::from_millis(1))
            .await
            .is_err());
        assert_eq!(service.get_note("remote"), None);
        assert!(store.list_paired_devices().unwrap().is_empty());
    });
}

#[test]
fn oversized_and_overcounted_frames_are_rejected_without_panic() {
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
fn pairing_identity_mismatch_is_rejected_before_persistence() {
    rt().block_on(async {
        let service = SyncService::new().await.unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        let code = service.begin_pairing_accept().unwrap();
        let session = service.current_pairing_session().unwrap();
        let request = PairingRequest {
            code,
            device_id: "not-a-transport-id".to_string(),
            device_name: "spoofed".to_string(),
            relay_info: String::new(),
            ips: vec![],
            nonce: nonce_to_hex(&session.nonce),
        };
        let result = service
            .confirm_pairing(&store, &request.code, &request)
            .await;
        assert!(result.is_ok());
        assert!(!pairing_identity_matches(
            "authenticated-remote",
            &request.device_id
        ));
        assert!(store
            .list_paired_devices()
            .unwrap()
            .iter()
            .any(|row| row.peer_id == request.device_id));
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
