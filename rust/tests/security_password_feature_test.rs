//! Security Layer Test: Password Management (Minimal)
//!
//! 实现规格: `docs/specs/architecture/security/password.md`
//!
//! 测试命名: `it_should_[behavior]_when_[condition]()`

use cardmind_rust::security::password::{hash_secretkey, verify_secretkey_hash};

#[test]
/// Scenario: Hash secretkey with SHA-256
fn it_should_hash_secretkey_with_sha256() {
    let hash = hash_secretkey("secret").unwrap();
    assert_eq!(
        hash,
        "2bb80d537b1da3e38bd30361aa855686bde0eacd7162fef6a25fe97bf527a25b"
    );
}

#[test]
/// Scenario: Verify secretkey hash success
fn it_should_verify_secretkey_hash_successfully() {
    let provided_hash = "2bb80d537b1da3e38bd30361aa855686bde0eacd7162fef6a25fe97bf527a25b";
    let is_valid = verify_secretkey_hash("secret", provided_hash).unwrap();
    assert!(is_valid);
}

#[test]
/// Scenario: Verify secretkey hash failure
fn it_should_verify_secretkey_hash_failure() {
    let provided_hash = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
    let is_valid = verify_secretkey_hash("secret", provided_hash).unwrap();
    assert!(!is_valid);
}
