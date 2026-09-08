---
name: pipeline-project-lessons
description: "CardMind 项目专属流水线经验（programming-pipeline 全局技能的 repo overlay）。派发 CardMind 编码任务前加载。"
---

# CardMind 项目专属流水线经验

全局规则见 Hermes 技能 `autonomous-ai-agents/programming-pipeline`。本文件只放 CardMind 特有事实与经验；与全局技能冲突时以全局技能为准。

## Provider 策略（2026-08-18 定稿）

- CardMind OpenCode 只走 `xkiro` provider；默认 `xkiro/openai/gpt-5.6-luna`。官方 DeepSeek 余额已耗尽，禁止作为回退。
- Luna 空响应 / socket-close / 网关错误 / 瞬时上游失败时：保留现有 worktree 和未提交 executor 改动 → 用同模型重试 → 会话卡死则同模型新会话续跑 → 永不切换到官方 DeepSeek。
- 这是 provider 可用性策略，不是「xkiro 永远可靠」的一般性结论。

## 角色边界与实机 QA

- Hermes 负责：探索、根因诊断、设计、任务单、验收标准、看门狗、终审、合并、打包、实机验证。OpenCode 是唯一业务代码 executor。实机 bug 变成红优先的 continuation 任务单；Hermes 不直接改产品代码，即使修复看起来很小。
- 证据分级独立报告：① Rust/live 网络 E2E（经配置 relay）② Flutter widget/FRB 回归 ③ 真实 Windows + Android UI 流程与数据投影。①②通过不能证明③。
- 配对成功 ≠ 在线：配对行只证明身份交换与持久化；`last_seen` 推导的 UI presence 可能在配对成功后仍显示离线。观察到的调度失败模式：两端都 `push → 短 accept 窗口`，相位错开则互相超时。正确设计需要一个幂等、有界、可停止的 receive owner，且不得持有阻塞编辑或出站 push 的 FRB 写锁。
- Android 模拟器网络启动规则：Hermes shell 可能导出 `HTTP_PROXY=http://127.0.0.1:2333`，模拟器继承后 guest loopback ≠ Windows loopback，造成假离线/TLS 失败。启动模拟器前清空全部代理变量。隔离 LAN/mDNS 测试见 Hermes 技能 `p2p-relay-hosting`。

## 双实例实机测试（Windows 桌面 + Android 模拟器）

用于验证多设备 P2P 功能。2026-08-15 首次实战抓到 66 测试全绿的配对缺陷（mDNS 自动发现从未接线）；第二轮验证了模拟器 NAT 对 mDNS 的隔离。

```bash
# 1. Android 模拟器（后台长驻，无 notify）
"$LOCALAPPDATA/Android/Sdk/emulator/emulator.exe" -avd medium_phone -no-snapshot-load -no-boot-anim
# 2. 等 boot（wait-for-device + sys.boot_completed 轮询，勿盲 sleep）
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" wait-for-device shell \
  'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done; echo BOOTED'
# 3. 装 APK —— 必须 Windows 风格路径（D:\...），MSYS /d/ 风格报 failed to stat
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" install -r \
  "D:\Projects\CardMind\build\app\outputs\flutter-apk\app-release.apk"
# 4. 起两端，各自验证进程活着
adb shell "dumpsys activity activities | grep -i com.cardmind.v2"
cd /d/Projects/CardMind && flutter run -d windows --release
```

## relay 可选配置与实机验证（任务 K 定稿）

- 公共 relay `relay.n0.iroh.link`/`dns.n0.iroh.link` 大陆直连与经 Clash 均不可达（Clash 判 DIRECT，代理无效）。relay 因此定位为**可选项**：默认零配置仅局域网，跨网段由客户自部署；发布物不携带 relay 地址。
- 客户端约定：数据目录 `relay.txt` 单行 URL；无文件/空 = `RelayMode::Disabled`；无效 URL → `new_persistent` 返回 Err（fail fast）；内存版 `SyncService::new()` 恒 Disabled（测试隔离）。
- iroh 客户端关键坑：`EndpointAddr::new(node_id)` 空 ips 时走 n0 DNS TXT 解析（被墙）——所有无直连 IP 的连接路径必须 `.with_relay_url(relay_url)` 显式附加 relay。
- 自建 relay 部署配方（dogcloud，iroh-relay v1.0.3 官方二进制）见 Hermes 技能 `p2p-relay-hosting`。

## 本地优先发布工作流

- 依赖/发布工作流/打包变更：先在隔离 worktree 本地验证——确认依赖与 lockfile 身份、跑相关测试、构建真实产物（Windows `flutter build windows` + Inno Setup `.exe`、Android release APK、Rust/FRB 运行态库）。本地全过才合并推送 GitHub Actions。CI 是第二道环境检查，不是本地验证的替代。
- worktree 缺原生运行库时：从真实 crate 目录构建现有 Rust host 产物并复制到既有运行态路径；不得为让测试加载而改业务代码。

## 卡死的流水线（2026-08-13 实例）

- 根因之一：worktree 放在主仓库的**兄弟目录**（`D:/Projects/CardMind-wt-a`）——opencode 把项目目录之外的一切视为 external，权限墙静默触发。兄弟目录 worktree 约定来自 Codex CLI 时代（`D:/Projects/CardMind-worktrees/*`，分支 `codex/platform-*`）；迁移到 opencode 后该继承约定成了隐形墙。教训：工作流迁移后要逐项重新校验继承的约定（路径、权限、spawn 模式），不要照搬。当前正确做法：worktree 放主仓库内部 `.worktrees/` 下（历史上残留的 `D:/Projects/CardMind-worktrees/*` 同级目录仍在，注意区分）。
