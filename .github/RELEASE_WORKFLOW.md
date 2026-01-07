# GitHub Actions 发布流程图

本文档说明 CardMind 的自动化发布流程。

## 触发条件

```
推送 tag (v*)
  ↓
GitHub Actions 触发
```

## 整体流程

```
┌─────────────────────────────────────────┐
│  推送 Tag: git push origin v1.0.0       │
└──────────────┬──────────────────────────┘
               ↓
┌──────────────────────────────────────────┐
│  Job 1: Create Release                   │
│  - 创建 GitHub Release                   │
│  - 生成 release 说明                     │
└──────────┬───────────────────────────────┘
           ↓
  ┌────────┴────────┐
  │ 并行执行 5 个构建 │
  └────────┬────────┘
           ↓
┌──────────┴──────────────────────────────────┐
│                                             │
├─────────┬─────────┬─────────┬──────┬───────┤
│         │         │         │      │       │
▼         ▼         ▼         ▼      ▼       ▼
┌───────┐ ┌───────┐ ┌───────┐ ┌────┐ ┌─────┐
│Android│ │ Linux │ │Windows│ │macOS│ │ iOS │
│Ubuntu │ │Ubuntu │ │Windows│ │macOS│ │macOS│
└───┬───┘ └───┬───┘ └───┬───┘ └──┬─┘ └──┬──┘
    │         │         │        │      │
    ▼         ▼         ▼        ▼      ▼
┌───────┐ ┌───────┐ ┌───────┐ ┌────┐ ┌─────┐
│ .apk  │ │.tar.gz│ │  .zip │ │.zip│ │ .zip│
└───┬───┘ └───┬───┘ └───┬───┘ └──┬─┘ └──┬──┘
    │         │         │        │      │
    └─────────┴─────────┴────────┴──────┘
                    │
                    ▼
      ┌─────────────────────────┐
      │ 上传到 Release Assets   │
      └─────────────────────────┘
                    │
                    ▼
              ┌──────────┐
              │ 完成发布 │
              └──────────┘
```

## 各平台详细流程

### Android (Ubuntu Runner)
```
1. 安装 Java 17
2. 安装 Flutter 3.27.2
3. 安装 Rust (stable)
4. 添加 Android targets
   - aarch64-linux-android
   - armv7-linux-androideabi
   - x86_64-linux-android
   - i686-linux-android
5. 安装 cargo-ndk
6. 配置 Android NDK (r26d)
7. 运行: dart tool/build_all.dart --android
8. 打包: app-release.apk → cardmind-{version}-android.apk
9. 上传到 Release
```

### Linux (Ubuntu Runner)
```
1. 安装系统依赖 (GTK3, CMake, Ninja, etc.)
2. 安装 Flutter 3.27.2
3. 安装 Rust (stable)
4. 运行: dart tool/build_all.dart --linux
5. 打包: tar -czf bundle → cardmind-{version}-linux.tar.gz
6. 上传到 Release
```

### Windows (Windows Runner)
```
1. 安装 Flutter 3.27.2
2. 安装 Rust (stable)
3. 运行: dart tool/build_all.dart --windows
4. 打包: Compress-Archive → cardmind-{version}-windows.zip
5. 上传到 Release
```

### macOS (macOS Runner)
```
1. 安装 Flutter 3.27.2
2. 安装 Rust (stable)
3. 运行: dart tool/build_all.dart --macos
4. 打包: zip -r cardmind.app → cardmind-{version}-macos.zip
5. 上传到 Release
```

### iOS (macOS Runner)
```
1. 安装 Flutter 3.27.2
2. 安装 Rust (stable)
3. 添加 iOS targets
   - aarch64-apple-ios
   - x86_64-apple-ios
4. 运行: dart tool/build_all.dart --ios
5. 打包: zip -r Runner.app → cardmind-{version}-ios.zip
6. 上传到 Release
```

## 缓存策略

每个平台都使用了依赖缓存以加速构建：

### Rust 缓存
```
~/.cargo/bin/
~/.cargo/registry/index/
~/.cargo/registry/cache/
~/.cargo/git/db/
rust/target/
```

### Flutter 缓存
```
~/.pub-cache
.dart_tool
```

缓存键基于 `Cargo.lock` 和 `pubspec.lock` 的哈希值，确保依赖变更时缓存失效。

## 时间估算

| 平台    | 首次构建 | 缓存后 |
|---------|----------|--------|
| Android | 15-20 分钟 | 8-12 分钟 |
| Linux   | 10-15 分钟 | 5-8 分钟  |
| Windows | 10-15 分钟 | 5-8 分钟  |
| macOS   | 12-18 分钟 | 6-10 分钟 |
| iOS     | 12-18 分钟 | 6-10 分钟 |
| **总计** | **30-45 分钟** | **15-25 分钟** |

注：所有平台并行构建，总时间取决于最慢的平台。

## 失败恢复

如果某个平台构建失败：

1. **不影响其他平台**：各平台独立运行
2. **查看日志**：在 Actions 页面查看失败详情
3. **重新触发**：
   ```bash
   git tag -d v1.0.0
   git push origin :refs/tags/v1.0.0
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```
4. **手动上传**：从 Actions Artifacts 下载成功的构建，手动上传失败平台

## 监控和通知

- GitHub Actions 页面：`https://github.com/{user}/{repo}/actions`
- Email 通知：默认发送给仓库所有者
- Status Badge：可添加到 README

## 安全考虑

1. **Secrets 管理**：`GITHUB_TOKEN` 自动提供，无需配置
2. **权限最小化**：仅需要 `contents:write` 权限
3. **依赖锁定**：使用固定版本的 actions
4. **缓存隔离**：各平台使用独立缓存键

## 已实现功能

- ✅ **多平台并行构建**：5 个平台同时构建
- ✅ **依赖缓存**：加速后续构建
- ✅ **自动发布**：tag 触发自动构建和发布
- ✅ **多格式打包**：APK, tar.gz, zip 等

## 后续优化建议

1. **代码签名**：添加 iOS/macOS 签名支持
2. **AAB 格式**：Android 可生成 App Bundle（Google Play 推荐）
3. **DMG 打包**：macOS 可打包为 DMG 格式（更专业的安装体验）
4. **TestFlight**：自动上传 iOS 到 TestFlight
5. **Notarization**：macOS 公证支持（需要 Apple 开发者账号）
6. **增量构建**：利用更细粒度的缓存
7. **Universal Binary**：支持 Apple Silicon 和 Intel 的通用二进制
8. **Windows MSIX**：Windows 商店格式打包

## 相关文档

- 构建脚本：`tool/build_all.dart`
- 发布指南：`.github/RELEASE.md`
- 构建指南：`tool/BUILD_GUIDE.md`
- 工作流配置：`.github/workflows/release.yml`
