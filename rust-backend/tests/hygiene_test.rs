//! Rust 测试资产卫生的结构断言（读源码文本，防回归）。
//!
//! 这些用例不验证产品行为，而是守住测试自身的健康度：读 `tests/*.rs`
//! 源码断言规则成立，防止历史问题回潮（轮询 sleep、低信息量命名等）。

use std::path::{Path, PathBuf};

/// `rust-backend/tests` 目录（编译期已知 crate 根）。
fn tests_dir() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("tests")
}

fn read_source(path: &Path) -> String {
    std::fs::read_to_string(path).unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()))
}

/// 找出「`loop {` 块内出现 sleep 调用」的行号——轮询等待的特征形态。
///
/// 逐行扫描并跟踪花括号深度：`loop {` 打开一个块，块体内（深度不小于打开后
/// 的深度）出现的 `sleep(` 即为轮询等待。不解析字符串与注释，粗粒度足够，
/// 且失败信息直接指向行号。
fn loop_sleep_lines(src: &str) -> Vec<usize> {
    let mut depth = 0i32;
    let mut open_loops: Vec<i32> = Vec::new();
    let mut offenders = Vec::new();
    for (idx, line) in src.lines().enumerate() {
        depth += line.matches('{').count() as i32 - line.matches('}').count() as i32;
        // 先清理本行已闭合的 loop（深度回落到打开处之前即已结束）
        open_loops.retain(|open_depth| depth >= *open_depth);
        if line.trim_start().starts_with("loop {") {
            open_loops.push(depth);
        }
        if !open_loops.is_empty() && line.contains("sleep(") {
            offenders.push(idx + 1);
        }
    }
    offenders
}

/// 接收器连续接收用例必须用事件等待，不得 `loop { 检查; sleep }` 轮询。
#[test]
fn receiver_continuous_has_no_polling_sleep() {
    let path = tests_dir().join("receiver_continuous_test.rs");
    let offenders = loop_sleep_lines(&read_source(&path));
    assert!(
        offenders.is_empty(),
        "receiver_continuous_test.rs 第 {offenders:?} 行仍在 loop 内 sleep 轮询；\
         事件性等待请用 wait_content_revision / wait_receiver_windows / \
         wait_receiver_incoming，无法事件化的单次 sleep 需就地写明理由"
    );
}
