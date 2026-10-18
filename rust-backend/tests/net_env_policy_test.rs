//! 「无 IPv4 → 静默跳过」的环境策略锚点测试。
//!
//! `CARDMIND_REQUIRE_NETWORK_TESTS=1` 时无 IPv4 必须判为用例失败（panic），
//! 否则维持「eprintln 留痕 + 返回 false → 调用方跳过」。CI 的 cargo test 步骤
//! 设该变量，让假绿无处可藏；本地开发机无网络时仍可跳过。

mod common;

use std::panic::{catch_unwind, AssertUnwindSafe};

/// 策略纯函数两腿：仅 `Some("1")` 为 fatal，None/"0"/"" 均非 fatal。
#[test]
fn ipv4_absence_is_fatal_legs() {
    assert!(common::ipv4_absence_is_fatal(Some("1")));
    assert!(!common::ipv4_absence_is_fatal(None));
    assert!(!common::ipv4_absence_is_fatal(Some("0")));
    assert!(!common::ipv4_absence_is_fatal(Some("")));
}

/// 策略 fatal + 空 addrs → panic（用例失败，而非静默通过）。
#[test]
fn require_ipv4_panics_when_fatal_and_no_addrs() {
    let result = catch_unwind(AssertUnwindSafe(|| {
        common::require_ipv4_inner(&[], Some("1"))
    }));
    assert!(result.is_err(), "fatal 策略下无 IPv4 必须 panic");
}

/// 对照腿：策略非 fatal + 空 addrs → 不 panic 且返回 false（调用方跳过）。
#[test]
fn require_ipv4_skips_when_not_fatal_and_no_addrs() {
    for require_env in [None, Some("0"), Some("")] {
        let result = catch_unwind(AssertUnwindSafe(|| {
            common::require_ipv4_inner(&[], require_env)
        }));
        let ok = result.expect("非 fatal 策略不得 panic");
        assert!(!ok, "无 IPv4 时应返回 false 让调用方跳过");
    }
}

/// 非空 addrs 恒通过，与策略无关。
#[test]
fn require_ipv4_passes_with_addrs() {
    let addrs = vec!["192.168.1.2:1234".to_string()];
    for require_env in [None, Some("0"), Some("1")] {
        assert!(common::require_ipv4_inner(&addrs, require_env));
    }
}
