# Release 发布指南

本文档说明如何使用 GitHub Actions 自动发布 CardMind 的新版本。

## 发布流程

### 1. 准备发布

在发布新版本之前，确保：

- [ ] 更新 `pubspec.yaml` 中的版本号
- [ ] 更新 `CHANGELOG.md`，记录本版本的变更内容
- [ ] 所有测试通过（`cargo test`, `flutter test`）
- [ ] 代码检查通过（`flutter analyze`, `cargo clippy`）
- [ ] 在本地完成至少一次完整构建测试

### 2. 创建并推送 Tag

```bash
# 确保在 main 分支
git checkout main
git pull origin main

# 创建版本 tag（例如 v1.0.1）
git tag -a v1.0.1 -m "Release version 1.0.1"

# 推送 tag 到远程仓库（这会触发 GitHub Actions）
git push origin v1.0.1
```

### 3. 自动构建与发布

推送 tag 后，GitHub Actions 会自动：

1. 创建 GitHub Release
2. 并行构建五个平台：
   - **Android** APK
   - **Linux** bundle (tar.gz)
   - **Windows** bundle (zip)
   - **macOS** bundle (zip with .app)
   - **iOS** bundle (zip with .app, unsigned)
3. 将构建产物上传到 Release assets

### 4. 查看发布进度

访问 GitHub Actions 页面查看构建状态：

```
https://github.com/YOUR_USERNAME/CardMind/actions
```

构建完成后，在 Releases 页面即可看到新发布的版本和下载链接。

## 构建产物说明

每个版本会生成以下文件：

- `cardmind-{version}-android.apk` - Android 应用安装包
- `cardmind-{version}-linux.tar.gz` - Linux 应用压缩包
- `cardmind-{version}-windows.zip` - Windows 应用压缩包
- `cardmind-{version}-macos.zip` - macOS 应用压缩包（包含 .app bundle）
- `cardmind-{version}-ios.zip` - iOS 应用压缩包（未签名，仅供测试）

## 手动发布（备选方案）

如果 GitHub Actions 不可用，可以手动构建并发布：

```bash
# 构建所有平台
dart tool/build_all.dart

# 手动打包 - Android
cd build/app/outputs/flutter-apk
cp app-release.apk cardmind-{version}-android.apk

# 手动打包 - Linux
cd build/linux/x64/release/bundle
tar -czf cardmind-{version}-linux.tar.gz *

# 手动打包 - macOS
cd build/macos/Build/Products/Release
zip -r cardmind-{version}-macos.zip cardmind.app

# 手动打包 - iOS
cd build/ios/iphoneos
zip -r cardmind-{version}-ios.zip Runner.app

# 在 Windows 上
cd build/windows/x64/runner/Release
# 使用 7-Zip 或 Windows 资源管理器压缩为 zip
```

然后在 GitHub 上手动创建 Release 并上传这些文件。

## 注意事项

1. **版本号格式**：必须以 `v` 开头，例如 `v1.0.0`, `v1.2.3-beta`
2. **权限要求**：需要仓库的写权限和 releases 权限
3. **构建时间**：完整构建（5个平台）大约需要 30-45 分钟
   - Android, Linux, Windows: ~15-20 分钟
   - macOS, iOS: ~15-25 分钟
4. **缓存**：使用了依赖缓存，后续构建会更快
5. **失败处理**：如果某个平台构建失败，不会影响其他平台
6. **并行构建**：所有平台并行构建，最大化效率

## 环境要求

GitHub Actions 会自动安装以下环境：

- Flutter 3.27.2
- Rust stable
- Java 17 (Android)
- Android NDK r26d (Android)
- GTK 3 开发库 (Linux)
- Xcode (macOS/iOS，在 macOS runner 上预装)

## 平台特别说明

### iOS
- **未签名版本**：CI 构建的 iOS 应用未经过代码签名，仅供开发和测试使用
- **安装方式**：需要通过 Xcode 或其他开发工具侧载到设备
- **测试设备**：需要注册为开发设备或使用 TestFlight
- **生产发布**：正式发布需要在本地使用 Apple 开发者证书签名并上传到 App Store

### macOS
- **未签名版本**：CI 构建的 macOS 应用未经过代码签名，仅供开发和测试使用
- **安装步骤**：
  1. 下载 `.zip` 文件
  2. 解压得到 `cardmind.app`
  3. 将 `cardmind.app` 拖拽到 `Applications` 文件夹（可选）
- **安全提示**：首次运行可能提示"来自身份不明开发者"
- **允许运行**：
  1. 打开"系统偏好设置" > "安全性与隐私"
  2. 点击"仍要打开"按钮
  3. 或者使用命令：`xattr -cr /path/to/cardmind.app`
- **签名**：如需签名版本，需要在本地使用 Apple 开发者证书重新构建

### Android
- **自动签名**：使用 Flutter 的调试签名
- **生产发布**：正式发布需要配置 release keystore

### Linux
- **依赖库**：可能需要安装 GTK3 和其他系统库
- **安装命令**：`sudo apt-get install libgtk-3-0`

### Windows
- **VC++ 运行库**：可能需要安装 Visual C++ Redistributable

## 故障排查

### 构建失败

1. 查看 Actions 日志定位错误
2. 检查是否是环境问题（NDK、GTK 等）
3. 在本地重现问题：`dart tool/build_all.dart --{platform}`
4. 必要时可以重新推送 tag 触发重新构建：
   ```bash
   git tag -d v1.0.1
   git push origin :refs/tags/v1.0.1
   git tag -a v1.0.1 -m "Release version 1.0.1"
   git push origin v1.0.1
   ```

### 上传失败

如果构建成功但上传失败，可以：

1. 在 Actions 页面下载构建产物（Artifacts）
2. 手动上传到已创建的 Release

## 预发布版本

发布 beta 或 alpha 版本：

```bash
# 创建预发布 tag
git tag -a v1.0.0-beta.1 -m "Beta release 1.0.0-beta.1"
git push origin v1.0.0-beta.1
```

需要手动在 Release 页面标记为 "Pre-release"。

## 更多信息

- GitHub Actions 配置文件：`.github/workflows/release.yml`
- 构建脚本：`tool/build_all.dart`
- 构建指南：`tool/BUILD_GUIDE.md`
