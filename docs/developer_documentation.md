# CardMind 开发者文档 (MVP版本)

## 项目概述

CardMind 是一个基于 Flutter 开发的跨平台卡片管理应用，支持桌面端和移动端。MVP版本专注于基本的卡片管理功能，提供简洁直观的用户体验。

## 技术栈

- **前端框架**：Flutter
- **状态管理**：Riverpod
- **数据库**：SQLite
- **UI组件**：Material Design

## 项目结构

```
app/
├── lib/
│   ├── desktop/       # 桌面端特定代码
│   ├── mobile/        # 移动端特定代码
│   ├── shared/        # 共享代码
│   │   ├── data/      # 数据层
│   │   ├── models/    # 数据模型
│   │   ├── providers/ # 状态提供者
│   │   ├── screens/   # 界面
│   │   ├── services/  # 服务
│   │   └── widgets/   # 共享组件
│   └── main.dart      # 应用入口
```

## 核心组件

### 数据模型

#### Card 模型

卡片是应用的核心数据模型，包含标题、内容等信息。

```dart
class Card {
  /// 卡片ID
  final String id;
  
  /// 卡片标题
  final String title;
  
  /// 卡片内容
  final String content;
  
  /// 创建时间
  final DateTime createdAt;
  
  /// 更新时间
  final DateTime updatedAt;
  
  /// 构造函数
  const Card({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });
}
```

### 服务层

#### CardService

卡片服务负责处理卡片的业务逻辑，包括数据库操作。

主要功能：
- 获取所有卡片
- 根据ID获取卡片
- 创建新卡片
- 更新卡片
- 删除卡片

```dart
class CardService {
  // 获取所有卡片
  Future<List<Card>> getAllCards();
  
  // 根据ID获取卡片
  Future<Card?> getCardById(String id);
  
  // 创建新卡片
  Future<Card> createCard(String title, String content);
  
  // 更新卡片
  Future<Card> updateCard(String id, String title, String content);
  
  // 删除卡片
  Future<bool> deleteCard(String id);
}
```

## 数据库设计

应用使用 SQLite 数据库实现本地数据存储。

### 主要表结构

- **cards**：存储卡片信息
  - id: TEXT PRIMARY KEY
  - title: TEXT NOT NULL
  - content: TEXT
  - created_at: INTEGER NOT NULL
  - updated_at: INTEGER NOT NULL

## 开发指南

### 环境设置

1. 安装 Flutter SDK
2. 克隆项目仓库
3. 运行 `flutter pub get` 安装依赖

### 构建和运行

```bash
# 运行桌面版
flutter run -d windows

# 运行移动版
flutter run -d android
```

### 添加新功能

1. **添加新的数据模型**：在 `shared/models` 目录下创建模型类
2. **添加新的服务**：在 `shared/services` 目录下创建服务类
3. **添加新的界面**：在 `shared/screens` 或平台特定目录下创建界面

### 调试技巧

- 使用 Flutter DevTools 进行调试
- 检查数据库操作
- 使用 `print` 或日志工具记录关键信息

## 未来扩展计划

在MVP基础上，未来可以考虑添加以下功能：

1. **数据同步**：添加基于CRDT的多设备数据同步
2. **卡片分类**：支持卡片分类和标签
3. **搜索功能**：实现全文搜索
4. **富文本编辑**：支持富文本和图片
5. **导入导出**：支持数据导入导出