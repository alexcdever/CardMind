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

/// 找出「循环块内出现 sleep 调用」的行号——轮询等待的特征形态。
///
/// 覆盖 `loop {`、`loop\n{`、`while .. {`、`for .. {` 四种循环开头（含 `'label:`
/// 前缀），并额外把「循环体内调用了某个含 `sleep(` 的辅助函数」也算作轮询
/// （先在本文件收集 `fn 名` → 该 fn 体内有 `sleep(`，再在循环体内匹配这些名字）。
///
/// **已知盲区**（故意保持粗粒度，不引入 syn 依赖）：
/// - 按字符数统计 `{`/`}`，注释与字符串里的括号会轻微污染深度；
/// - 只匹配字面量 `sleep(`（`tokio::time::sleep` / `std::thread::sleep` / 直接用
///   `sleep` 别名都能命中，但完全自定义的等待函数不会）；
/// - 循环与 sleep 分处不同行但中间夹了非括号语句时，仍按所在块深度判断。
fn loop_sleep_lines(src: &str) -> Vec<usize> {
    let lines: Vec<&str> = src.lines().collect();
    // 第一遍：收集「函数体内含 sleep(」的函数名，供第二遍识别 helper 间接轮询。
    let mut sleep_helpers: Vec<String> = Vec::new();
    let mut current_fn: Option<String> = None;
    let mut fn_depth: i32 = 0;
    let mut depth_scan = 0i32;
    for line in &lines {
        let trimmed = line.trim_start();
        if let Some(rest) = strip_fn_modifiers(trimmed).strip_prefix("fn ") {
            let name: String = rest
                .chars()
                .take_while(|c| c.is_alphanumeric() || *c == '_')
                .collect();
            if !name.is_empty() {
                current_fn = Some(name);
                fn_depth = depth_scan;
            }
        }
        depth_scan += line.matches('{').count() as i32 - line.matches('}').count() as i32;
        if let Some(name) = &current_fn {
            if line.contains("sleep(") && !sleep_helpers.contains(name) {
                sleep_helpers.push(name.clone());
            }
            if depth_scan <= fn_depth {
                current_fn = None;
            }
        }
    }

    // 第二遍：找循环块内的 sleep( 调用或 helper 调用。
    let mut depth = 0i32;
    let mut open_loops: Vec<i32> = Vec::new();
    let mut offenders = Vec::new();
    for (idx, line) in lines.iter().enumerate() {
        depth += line.matches('{').count() as i32 - line.matches('}').count() as i32;
        // 先清理本行已闭合的循环（深度回落到打开处之前即已结束）
        open_loops.retain(|open_depth| depth >= *open_depth);
        if starts_loop(line) {
            open_loops.push(depth);
        }
        if !open_loops.is_empty() {
            let has_sleep = line.contains("sleep(");
            let calls_helper = sleep_helpers
                .iter()
                .any(|name| line.contains(&format!("{name}(")));
            if has_sleep || calls_helper {
                offenders.push(idx + 1);
            }
        }
    }
    offenders
}

/// 剥掉 `pub` / `pub(crate)` / `async` / `unsafe` / `const` / `extern "C"` 等前置修饰，
/// 让命名守卫能看见 `async fn test_foo`、`pub fn test_foo` 这类形态。
fn strip_fn_modifiers(mut line: &str) -> &str {
    loop {
        let before = line.len();
        line = line.trim_start();
        for kw in [
            "pub(crate)",
            "pub(super)",
            "pub(self)",
            "pub",
            "async",
            "unsafe",
            "const",
            "default",
        ] {
            if let Some(rest) = line.strip_prefix(kw) {
                if rest.starts_with(char::is_whitespace) {
                    line = rest;
                    break;
                }
            }
        }
        if line.len() == before {
            return line;
        }
    }
}

/// 判断该行是否开启一个循环块：`loop {`、`loop`（`{` 在下一行）、`while .. {`、
/// `for .. {`，均允许带 `'label:` 前缀。
fn starts_loop(line: &str) -> bool {
    let mut t = line.trim_start();
    if let Some(rest) = t.strip_prefix('\'') {
        // 标签：'outer: loop { ... }
        if let Some(pos) = rest.find(':') {
            t = rest[pos + 1..].trim_start();
        }
    }
    if let Some(rest) = t.strip_prefix("loop") {
        // `loop` 后面要么紧跟 `{`（可能换行在下一行，故空串也算），要么不是循环。
        let after = rest.trim_start();
        return after.starts_with('{') || after.is_empty();
    }
    let is_while = t.starts_with("while ") || t.starts_with("while(");
    let is_for = t.starts_with("for ") || t.starts_with("for(");
    if is_while || is_for {
        // 只在确有此行开启块（或块在后续行）时才算；`while` 表达式末尾会有 `{`。
        return t.contains('{') || !t.ends_with(';');
    }
    false
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
    // 先剥掉 pub/pub(crate)/async/unsafe 等修饰，否则 `async fn test_foo`
    // 与 `pub fn test_foo` 会从守卫眼下溜走。
    let offenders =
        scan_tests(|line| strip_fn_modifiers(line.trim_start()).starts_with("fn test_"));
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
        "receiver_continuous_test.rs 第 {offenders:?} 行仍在循环内 sleep 轮询；\
         事件性等待请用 wait_content_revision / wait_receiver_windows / \
         wait_receiver_connections，无法事件化的单次 sleep 需就地写明理由"
    );
}
