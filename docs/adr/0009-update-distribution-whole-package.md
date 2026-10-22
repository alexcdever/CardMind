# ADR 0009 — 更新分发定案：整包替换，不做模块级热更

- **日期**：2026-10-22
- **状态**：已采纳
- **决策者**：@alexc

---

> 来源：`docs/migration-nsh.md`「更新分发：NSH 签名包 vs 现有 msix」一节 + 风险表 R11。
> 施工项：`docs/migration-nsh-construction.md` 4.3（更新分发整包替换定案）。
> 同步网络与打包链路上下文见 [ADR 0006](0006-lan-sync-loro-iroh-mdns.md)、`docs/sync-network.md`。

## 背景

CardMind 从 Flutter 壳迁到 NSH 壳后，「怎么把新版本发到用户设备」需要重新定案。旧版
（Flutter）走 **msix + 自重分发**：Windows 安装包用自签名证书 `CN=CardMind`
（`install_certificate: false`，用户要先手动导入证书才信任），应用内
`update_service` 拉 GitHub Releases 上的 `manifestUrl`（`stable.json` / `beta.json`，
见 `lib/models/update_channel.dart`）比版本号 → 下载 → 调平台安装器
（`lib/services/platform_update_installer.dart` 的 `_startWindowsInstaller` /
`_startAndroidInstaller` / `_openMacosFile` / `_openLinuxFile`）。

NSH 提供了第二条路：`nsh publish` 出 `.nshpkg`（**Ed25519 签名模块包**，离线 root key
认证 release key，设备端校验吊销列表），应用内嵌 nsh 运行时后经 `loadPackage` 验签并
**只加载界面模块**，宿主（含 Rust 后端 DLL）不动。

两条路的差别**不是「哪个更好」，而是「更新的是整个应用还是只有界面」**：

- 整包（msix 或 `nsh package` 的 zip/exe）换的是**完整应用二进制**；
- `.nshpkg` 换的是**宿主内的界面模块**，前提是应用改造成「内嵌 nsh 的宿主 + 可换模块」。

本阶段的目标是「把 UI 换成 NSH」，价值在壳本身，不在模块级热更能力。

## 决策

### 1. 本期走整包替换

- **打包产物**：`nsh package --target <platform>` 出的整包。已实测
  `nsh package --target windows` exit 0，产 `cardmind.exe`（31.4 MB）+ `cardmind.zip`
  （13.1 MB）。
- **`nsh publish` / `.nshpkg` 本期不用**：整包替换与 msix 同类，代价是少了安装器体验
  （开始菜单项、卸载项、系统集成），换到的是与 msix 同等的「换整套二进制」语义。

### 2. 保留 `update_service` 的「发现 + 下载」逻辑

- `lib/services/update_service.dart` 的 `check`（拉 `manifestUrl` → `UpdateManifest.tryParse`
  → `_isNewer` 比 `build`/`version`）与包格式无关，**原样保留**。版本比较
  （`_compareVersions` 三段 core + prerelease）也不动。
- manifest 渠道（`stable` / `beta` 的 `manifestUrl`）继续指向 GitHub Releases 上的
  channel JSON；只是把资产从 msix 换成新包。

### 3. 只替换「安装」那一步

- 把 `PlatformUpdateInstaller` 里「下载 msix → `Process.start` 调安装器 / Android
  `installApk` / macOS `open` / Linux `xdg-open`」的落点，从「平台安装器装包」换成
  「下载新包并替换」。包内是自包含二进制，无安装器协议要履行。
- 各平台的「打开/启动」入口（Windows `Process.start`、macOS `open`、Linux `xdg-open`、
  Android 的 `MethodChannel('com.cardmind.v2/update-installer')`）按新包形态逐个对齐，
  但**调用契约（`install(asset, verifiedFile)` → `InstallResult`）不变**。

### 4. 不做模块级热更（R11 关闭方式）

- **本期不做**「内嵌 nsh 运行时 + `loadPackage` 换界面模块」。那条路已探明
  （`.nshpkg` = Ed25519 签名模块包，宿主验签后 `loadPackage`），留作后续演进，不在本
  ADR 范围内重新论证。

## 拒绝的方案

### 内嵌 nsh + `loadPackage` 模块级热更（留作演进）

- **理由**：把应用变成「宿主 + 可换模块」显著增加架构与验证面（要新增内嵌运行时、
  验签与吊销列表检查、宿主↔模块边界契约）；本阶段价值在「把 UI 换成 NSH」，不在
  「后端不动只换界面」。
- **触发重估的条件**：将来出现「后端稳定、频繁只更 UI」的分发诉求，或 NSH 的
  `.nshpkg` 签名/吊销机制被产品端正式需要时，再回到这条路（已探明，无需重调研）。

### `nsh publish` 出的 `.nshpkg` 当整包发

- **理由**：`.nshpkg` 是**模块**包，设计上要内嵌运行时验签加载，不是完整应用；把它
  当整包发没有宿主可装，语义对不上。整包由 `nsh package` 承担。

## 后果

- **正向**：
  - 更新路径与旧版同语义（换整套二进制），验证面最小——`update_service` 的
    「拉 manifest / 比版本 / 下载」全部复用，只有「安装」落点改；
  - 不引入内嵌运行时，架构保持在「单壳 + 后端」，符合本阶段迁移目标；
  - `.nshpkg` 模块热更的路已探明，将来要做不用重新调研。
- **约束 / 负向**：
  - 整包替换没有 msix 的安装器体验（无开始菜单项 / 卸载项 / 系统集成），
    Windows 端等于退回「解压/替换 exe」级；
  - 每次发版换整套二进制，下载体积大于「只换 UI 模块」；
  - `PlatformUpdateInstaller` 的平台分支要按新包形态逐个对齐（尤其 Android 的
    `installApk`/`prepareApk` MethodChannel 与桌面三端的 `open`/`xdg-open`/`Process.start`），
    这部分的实机验证依赖真窗口运行（本任务以整包构建 + 链路接通为准）。

## 非目标

- **不做模块级热更**（不是「保留待议」，是本期的明确关闭——R11 按整包替换定案）。
- **不改变 manifest 渠道与版本比较语义**：`stable`/`beta` 的 `manifestUrl`、
  `UpdateManifest` 解析、`_isNewer`/`_compareVersions` 都是既有契约，不动。
- **不引入服务端 rendezvous / 云更新服务**，也不改同步网络层（ADR 0006 的边界）。
- **不覆盖移动端打包细节**：本定案锁定「整包替换」方向；Android/iOS 的具体产物形态
  （apk/aab/ipa）与安装渠道属平台工程，另立任务。
