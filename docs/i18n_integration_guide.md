# 国际化集成指南

## 概述

本文档说明如何在 CardMind 项目中集成和使用国际化（i18n）功能。

## 当前状态

✅ **已完成**：
- 创建了中文资源文件：`lib/l10n/app_zh.arb`
- 创建了英文资源文件：`lib/l10n/app_en.arb`
- 定义了所有 NoteCard 相关的文本键

⏳ **待完成**：
- 配置 Flutter 国际化
- 替换硬编码文本为国际化字符串
- 生成国际化代码

## 集成步骤

### 1. 配置 pubspec.yaml

在 `pubspec.yaml` 中添加国际化配置：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any

flutter:
  generate: true
```

### 2. 创建 l10n.yaml

在项目根目录创建 `l10n.yaml`：

```yaml
arb-dir: lib/l10n
template-arb-file: app_zh.arb
output-localization-file: app_localizations.dart
```

### 3. 生成国际化代码

运行命令生成代码：

```bash
flutter gen-l10n
```

这将生成 `lib/generated/l10n/` 目录下的代码。

### 4. 配置 MaterialApp

在 `main.dart` 中配置：

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/l10n/app_localizations.dart';

MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [
    Locale('zh', ''), // 中文
    Locale('en', ''), // 英文
  ],
  // ...
)
```

### 5. 使用国际化字符串

在组件中使用：

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Text(l10n.noteCardUntitled);
  }
}
```

## 需要替换的硬编码文本

### NoteCard 组件

**文件**：`lib/widgets/note_card_desktop.dart`, `lib/widgets/note_card_mobile.dart`

| 硬编码文本 | 国际化键 |
|-----------|---------|
| `'无标题'` | `l10n.noteCardUntitled` |
| `'点击添加内容...'` | `l10n.noteCardEmptyContent` |
| `'Note card: ${title}'` | `l10n.noteCardSemanticLabel(title)` |
| `'编辑'` | `l10n.noteCardContextMenuEdit` |
| `'删除'` | `l10n.noteCardContextMenuDelete` |
| `'查看详情'` | `l10n.noteCardContextMenuViewDetails` |
| `'复制内容'` | `l10n.noteCardContextMenuCopy` |
| `'分享'` | `l10n.noteCardContextMenuShare` |

### TimeFormatter 工具类

**文件**：`lib/utils/time_formatter.dart`

| 硬编码文本 | 国际化键 |
|-----------|---------|
| `'刚刚'` | `l10n.noteCardJustNow` |
| `'${seconds}秒前'` | `l10n.noteCardSecondsAgo(seconds)` |
| `'${minutes}分钟前'` | `l10n.noteCardMinutesAgo(minutes)` |
| `'${hours}小时前'` | `l10n.noteCardHoursAgo(hours)` |
| `'未知时间'` | `l10n.noteCardUnknownTime` |

### CardEditDialog 组件

**文件**：`lib/screens/card_edit_dialog.dart`

| 硬编码文本 | 国际化键 |
|-----------|---------|
| `'编辑笔记'` | `l10n.cardEditDialogTitle` |
| `'标题'` | `l10n.cardEditDialogTitleLabel` |
| `'输入笔记标题'` | `l10n.cardEditDialogTitleHint` |
| `'内容'` | `l10n.cardEditDialogContentLabel` |
| `'输入笔记内容（支持 Markdown）'` | `l10n.cardEditDialogContentHint` |
| `'保存'` | `l10n.cardEditDialogSave` |
| `'取消'` | `l10n.cardEditDialogCancel` |
| `'放弃更改？'` | `l10n.cardEditDialogDiscardTitle` |
| `'您有未保存的更改，确定要放弃吗？'` | `l10n.cardEditDialogDiscardMessage` |
| `'放弃'` | `l10n.cardEditDialogDiscardConfirm` |
| `'标题不能为空'` | `l10n.cardEditDialogTitleRequired` |
| `'关闭 (ESC)'` | `l10n.cardEditDialogCloseTooltip` |

## 示例：替换 NoteCardDesktop 中的文本

### 替换前

```dart
Text(
  widget.card.title.isEmpty ? '无标题' : widget.card.title,
  style: theme.textTheme.titleLarge,
)
```

### 替换后

```dart
Text(
  widget.card.title.isEmpty
    ? AppLocalizations.of(context)!.noteCardUntitled
    : widget.card.title,
  style: theme.textTheme.titleLarge,
)
```

## 测试国际化

### 1. 切换语言测试

```dart
testWidgets('should display Chinese text', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NoteCard(card: testCard, onDelete: (_) {}),
    ),
  );

  expect(find.text('无标题'), findsOneWidget);
});

testWidgets('should display English text', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NoteCard(card: testCard, onDelete: (_) {}),
    ),
  );

  expect(find.text('Untitled'), findsOneWidget);
});
```

## 注意事项

1. **性能影响**：国际化会增加少量运行时开销，但影响可以忽略不计
2. **测试更新**：所有硬编码文本的测试都需要更新
3. **向后兼容**：确保现有功能不受影响
4. **代码审查**：替换文本时要仔细检查，避免遗漏

## 为什么暂不实施

当前项目中硬编码的中文文本较少，且主要用户群体为中文用户。完整的国际化实施需要：

1. 更新所有组件代码
2. 更新所有测试用例
3. 配置构建流程
4. 进行全面测试

这些工作量较大，建议在以下情况下实施：

- 需要支持多语言用户
- 项目进入国际化阶段
- 有充足的测试时间

## 参考资料

- [Flutter 国际化官方文档](https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization)
- [ARB 文件格式规范](https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification)
- [Flutter intl 包文档](https://pub.dev/packages/intl)
