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

/// 扫描 `tests/` 下所有 `.rs`（含 `common/`），收集满足 `pred` 的「文件:行」。
fn scan_tests<F>(pred: F) -> Vec<String>
where
    F: Fn(&str) -> bool,
{
    let mut hits = Vec::new();
    let mut stack = vec![tests_dir()];
    while let Some(dir) = stack.pop() {
        let entries = std::fs::read_dir(&dir)
            .unwrap_or_else(|e| panic!("读取目录 {} 失败: {e}", dir.display()));
        for entry in entries {
            let path = entry.expect("目录项").path();
            if path.is_dir() {
                stack.push(path);
                continue;
            }
            if path.extension().and_then(|e| e.to_str()) != Some("rs") {
                continue;
            }
            let src = read_source(&path);
            let name = path
                .strip_prefix(tests_dir())
                .unwrap_or(&path)
                .to_string_lossy()
                .replace('\\', "/");
            for (idx, line) in src.lines().enumerate() {
                if pred(line) {
                    hits.push(format!("{name}:{}", idx + 1));
                }
            }
        }
    }
    hits.sort();
    hits
}

/// 测试函数名必须描述「被测行为 + 预期」，禁止无信息量的 `test_` 前缀。
#[test]
fn no_test_prefix_fn_names() {
    let offenders = scan_tests(|line| line.trim_start().starts_with("fn test_"));
    assert!(
        offenders.is_empty(),
        "以下测试函数仍用 `test_` 前缀，应改为描述行为与预期的名字：{offenders:#?}"
    );
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
