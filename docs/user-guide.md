# CardMind 用户使用指南

## 简介

CardMind 是一个跨平台的卡片笔记应用，支持本地存储和数据池协作功能。本文档指导用户如何安装、配置和使用 CardMind。

## 目录

1. [安装指南](#安装指南)
2. [快速开始](#快速开始)
3. [基础功能](#基础功能)
4. [数据池协作](#数据池协作)
5. [故障排除](#故障排除)

---

## 安装指南

### 系统要求

- **macOS**: 10.15 或更高版本
- **Linux**: Ubuntu 20.04+ / Debian 10+ / Fedora 34+
- **Windows**: Windows 10 或更高版本

### 从源码构建

#### 1. 安装依赖

**macOS:**
```bash
# 安装 Flutter
brew install flutter

# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 安装 CocoaPods
sudo gem install cocoapods
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa

# 安装 Flutter
sudo snap install flutter --classic

# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

**Windows:**
1. 下载并安装 [Flutter SDK](https://docs.flutter.dev/get-started/install/windows)
2. 下载并安装 [Rust](https://www.rust-lang.org/tools/install)

#### 2. 克隆项目

```bash
git clone https://github.com/alexcdever/CardMind.git
cd CardMind
```

#### 3. 获取依赖

```bash
flutter pub get
cd rust && cargo build --release && cd ..
```

#### 4. 运行应用

**macOS:**
```bash
dart run tool/build.dart run
```

**其他平台:**
```bash
flutter run -d <platform>
```

---

## 快速开始

### 首次启动

1. 启动应用后，系统会自动初始化本地存储
2. 进入主界面，可以看到三个主要功能区：
   - **卡片**: 管理你的笔记卡片
   - **数据池**: 创建或加入协作数据池
   - **设置**: 应用配置选项

### 创建第一张卡片

1. 点击底部导航栏的"卡片"标签
2. 点击右下角的"+"按钮
3. 输入标题和内容
4. 点击"保存"

---

## 基础功能

### 卡片管理

#### 创建卡片
- 点击"+"按钮
- 输入标题（必填）和内容（可选）
- 点击保存

#### 编辑卡片
- 长按卡片或点击编辑图标
- 修改内容
- 点击保存

#### 删除卡片
- 左滑卡片显示删除按钮
- 点击删除确认

#### 搜索卡片
- 在顶部搜索栏输入关键词
- 支持标题和内容搜索

### 数据管理

#### 本地存储
- 所有数据默认存储在本地
- 应用数据目录：
  - macOS: `~/Library/Application Support/com.cardmind/`
  - Linux: `~/.local/share/cardmind/`
  - Windows: `%APPDATA%\CardMind\`

#### 数据备份
- 定期备份应用数据目录
- 或导出卡片为 JSON 格式

---

## 数据池协作

数据池允许多个用户共享和协作编辑卡片。

### 创建数据池

1. 点击底部导航栏的"数据池"标签
2. 点击"创建池"按钮
3. 系统会生成一个唯一的池 ID（邀请码）
4. 将邀请码分享给其他用户

### 加入数据池

1. 点击"数据池"标签
2. 点击"扫码加入"或"输入邀请码"
3. 输入邀请码（池 ID）
4. 等待池主审批（如果需要）

### 数据池管理

#### 作为池主
- **审批成员**: 在成员列表中查看待审批请求，点击"通过"
- **编辑池信息**: 点击"编辑池信息"修改池名称
- **解散池**: 点击"解散池"（会删除所有共享数据）

#### 作为成员
- **查看成员**: 在池页面查看所有成员
- **退出池**: 点击"退出池"（你的本地数据会保留）

### 协作功能

#### 共享卡片
- 在池内创建的卡片会自动同步给所有成员
- 编辑卡片会实时同步（需要网络连接）

#### 离线支持
- 离线时创建的卡片会在恢复连接后自动同步
- 离线编辑会保留，连接后合并更改

#### 冲突解决
- 同时编辑同一卡片时，系统会自动合并更改
- 无法自动合并时会提示手动选择

---

## 故障排除

### 应用无法启动

**症状**: 点击应用图标后无反应或闪退

**解决方案**:
1. 检查系统要求是否满足
2. 重新构建应用：
   ```bash
   flutter clean
   flutter pub get
   dart run tool/build.dart run
   ```
3. 查看日志：
   ```bash
   flutter run -d macos --verbose
   ```

### 无法加载 Rust 库

**症状**: 报错 "Failed to load dynamic library"

**解决方案**:
1. 确保 Rust 库已构建：
   ```bash
   cd rust && cargo build --release
   ```
2. 重新运行构建脚本：
   ```bash
   dart run tool/build.dart run
   ```

### 无法加入数据池

**症状**: 提示 "池不存在" 或 "加入失败"

**解决方案**:
1. 检查邀请码是否正确
2. 确保网络连接正常
3. 联系池主确认池是否仍然存在
4. 检查是否已经达到成员上限

### 同步失败

**症状**: 数据没有同步或提示同步错误

**解决方案**:
1. 检查网络连接
2. 点击"重试同步"按钮
3. 如果持续失败，尝试"重新连接"
4. 退出并重新加入数据池

### 数据丢失

**症状**: 卡片或数据池消失

**解决方案**:
1. 检查是否在正确的数据池中
2. 查看回收站（如果有）
3. 从备份恢复数据
4. 联系其他成员确认数据状态

---

## 高级功能

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Cmd/Ctrl + N` | 新建卡片 |
| `Cmd/Ctrl + S` | 保存卡片 |
| `Cmd/Ctrl + F` | 搜索 |
| `Esc` | 取消/返回 |

### 导入/导出

#### 导出卡片
1. 进入设置
2. 选择"导出数据"
3. 选择导出格式（JSON/Markdown）
4. 选择保存位置

#### 导入卡片
1. 进入设置
2. 选择"导入数据"
3. 选择要导入的文件
4. 确认导入

---

## 获取帮助

### 报告问题

如果你遇到问题，请通过以下方式报告：

1. **GitHub Issues**: [https://github.com/alexcdever/CardMind/issues](https://github.com/alexcdever/CardMind/issues)
2. 提供以下信息：
   - 操作系统版本
   - 应用版本
   - 问题描述
   - 复现步骤
   - 错误日志（如果有）

### 查看日志

**macOS:**
```bash
# 查看应用日志
open ~/Library/Logs/CardMind/
```

**Linux:**
```bash
# 查看应用日志
journalctl -u cardmind
```

**Windows:**
```powershell
# 查看事件查看器
eventvwr.msc
```

---

## 更新日志

### v1.0.0
- ✨ 初始版本发布
- 📝 卡片创建、编辑、删除
- 🔄 数据池协作功能
- 🔍 搜索功能
- 💾 本地存储

---

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](../LICENSE) 文件。

---

**最后更新**: 2026-03-17
