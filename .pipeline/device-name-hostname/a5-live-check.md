# A5 实机验证：设备名修复

- task-id: `device-name-hostname`
- role: main-agent
- 日期：2026-09-28
- HEAD（验证时）：`662619d3`

## 1. 决定性实验：直接打印设备名

在 `rust-backend/tests/` 临时加测试（用后已删）：

```rust
#[test]
fn print_device_name() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let svc = cardmind_backend::sync::SyncService::new().await.unwrap();
        println!("PROBE device_name={}", svc.device_name());
        println!("PROBE COMPUTERNAME={:?}", std::env::var("COMPUTERNAME").ok());
        println!("PROBE HOSTNAME={:?}", std::env::var("HOSTNAME").ok());
    });
}
```

**正常环境**：

```
PROBE device_name=Alexc-MBA
PROBE COMPUTERNAME=None
PROBE HOSTNAME=None
test result: ok. 1 passed; 0 failed
```

**`env -u HOSTNAME -u COMPUTERNAME`（模拟 Finder 启动的 GUI 进程）**：

```
PROBE device_name=Alexc-MBA
PROBE COMPUTERNAME=None
PROBE HOSTNAME=None
test result: ok. 1 passed; 0 failed
```

### 为什么这是决定性证据

`COMPUTERNAME=None` **且** `HOSTNAME=None` —— 这正是 GUI 进程的真实环境（主代理早先 `ps eww` 实测确认）。

在此环境下：

- **旧实现必然返回 `"CardMind Device"`**（两个 `env::var` 都失败 → 落兜底）
- **新实现返回 `"Alexc-MBA"`**（走 `libc::gethostname`）

两者在同一环境下结果不同，说明修复确实改变了行为，且新行为正确。

对照系统真实主机名：

```
scutil --get ComputerName : Alexc-MBA
hostname                  : Alexc-MBA.local
```

`gethostname` 返回 `Alexc-MBA.local`，经 `normalize_hostname` 去掉 `.local` → `Alexc-MBA`。与预期一致。

## 2. 实机应用启动验证

用新代码重新构建并安装到 `/Applications`：

```
cargo build --release   → EXIT=0，dylib 26,192,264 bytes
flutter build macos --release → EXIT=0，cardmind.app 77.9MB
```

启动（cwd=`/tmp`，模拟 Finder 路径）：

```
flutter: event=startup.rustlib     action=start
flutter: event=startup.rustlib     action=success
flutter: event=startup.bridge      action=success
flutter: event=startup.sync_service action=success
```

无错误。应用正常运行。

## 3. 未能直接截图设备列表（证据边界）

**设备名在 UI 设备列表中的显示未直接截图确认。** 原因：

- 列表显示的是**已配对设备**的 `peer_name`，来自数据库 `paired_devices` 表
- 之前配对时存的是旧值 `CardMind Device`，新逻辑只影响**此后新配对**写入的名字
- 要看到 `Alexc-MBA`，需清库重新配对，或在另一台设备上配对

因此本任务的直接证据是 §1 的 `device_name()` 返回值（那是 UI 的数据源），而非 UI 截图。

## 4. 环境说明

- `/Applications/cardmind.app` 现为**新构建**（含主机名修复）
- 旧构建备份在 `/tmp/cm-prev-app`（未删除）
- rustup 默认工具链已切到 `system`（Homebrew Rust 1.98.1）

## 结论

**A5 PASS**：在无 `COMPUTERNAME` / 无 `HOSTNAME` 的环境下，`device_name()` 返回真实主机名 `Alexc-MBA` 而非兜底串 `CardMind Device`。