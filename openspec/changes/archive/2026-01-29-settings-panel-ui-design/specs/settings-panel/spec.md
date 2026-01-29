## ADDED Requirements

### Requirement: Display platform-specific settings interface
The system SHALL display appropriate settings interface based on platform (mobile full screen, desktop dialog).

#### Scenario: Show mobile full-screen settings
- **WHEN** user opens settings on mobile device
- **THEN** system displays full-screen settings page
- **AND** shows navigation bar with "设置" title
- **AND** displays settings sections in scrollable content area
- **AND** provides bottom navigation for app-wide access

#### Scenario: Show desktop dialog settings
- **WHEN** user opens settings on desktop device
- **THEN** system displays settings dialog with 600px width
- **AND** shows modal overlay with blur background
- **AND** provides title bar with close button
- **AND** limits max height to 80vh

#### Scenario: Organize settings in logical sections
- **WHEN** displaying settings interface
- **THEN** system groups settings into logical sections
- **AND** displays sections in order: Notifications, Appearance, Data Management, About
- **AND** shows appropriate icons for each section

### Requirement: Implement instant toggle settings
The system SHALL provide toggle settings that take effect immediately without confirmation.

#### Scenario: Toggle sync notifications
- **WHEN** user toggles sync notification switch
- **THEN** system immediately applies new setting
- **AND** saves setting to persistent storage
- **AND** shows success toast notification
- **AND** updates notification registration accordingly

#### Scenario: Toggle dark mode
- **WHEN** user toggles dark mode switch
- **THEN** system immediately applies theme change
- **AND** shows smooth transition animation (300ms)
- **AND** saves theme preference to storage
- **AND** updates all UI components accordingly

#### Scenario: Handle setting toggle failures
- **WHEN** setting toggle operation fails
- **THEN** system shows error toast message
- **AND** reverts toggle to previous state
- **AND** provides retry option

### Requirement: Support Loro format data import/export
The system SHALL support importing and exporting data in Loro binary format.

#### Scenario: Export all data to Loro file
- **WHEN** user clicks "导出数据" button
- **THEN** system calls Rust FFI to get snapshot data
- **AND** generates file with name format `cardmind-export-{YYYY-MM-DD-HHmmss}.loro`
- **AND** opens file save dialog
- **AND** shows progress indicator during export (< 5s for 1000 cards)
- **AND** displays success toast upon completion

#### Scenario: Import data from Loro file
- **WHEN** user clicks "导入数据" button
- **THEN** system opens file picker for .loro files
- **AND** validates file format and size (< 100MB)
- **AND** previews file content with card count
- **AND** shows confirmation dialog with merge warning
- **AND** merges data into existing database (no overwrite)

#### Scenario: Handle data import/export errors
- **WHEN** file format is invalid or corrupted
- **THEN** system shows appropriate error message
- **AND** prevents operation from proceeding
- **AND** provides clear instructions for resolution

### Requirement: Display comprehensive app information
The system SHALL display detailed app information in About section.

#### Scenario: Show app version and build info
- **WHEN** user views About section
- **THEN** system displays app version and build number
- **AND** shows technical stack info (Flutter + Rust + libp2p + loro)
- **AND** formats version as "1.0.0 (Build 100)"

#### Scenario: Show open source license and repository
- **WHEN** user views About section
- **THEN** system displays license information (e.g., MIT)
- **AND** shows GitHub repository link
- **AND** provides clickable link with external launch

#### Scenario: Display contributors and changelog
- **WHEN** user views About section
- **THEN** system shows list of contributors
- **AND** displays recent 3 version changelog entries
- **AND** formats changelog with version, date, and changes
- **AND** provides link to view full changelog history

### Requirement: Provide safe data operation confirmations
The system SHALL provide confirmation dialogs for critical data operations.

#### Scenario: Show export confirmation dialog
- **WHEN** user initiates data export
- **THEN** system shows confirmation dialog
- **AND** displays warning about data file size and format
- **AND** provides "确认导出" and "取消" buttons
- **AND** proceeds only after user confirmation

#### Scenario: Show import confirmation dialog
- **WHEN** user selects .loro file for import
- **THEN** system shows preview dialog with file details
- **AND** displays card count and merge warning
- **AND** provides "确认导入" and "取消" buttons
- **AND** prevents accidental data overwrites

#### Scenario: Handle confirmation dialog cancellation
- **WHEN** user cancels any confirmation dialog
- **THEN** system closes dialog without performing operation
- **AND** returns to previous screen
- **AND** discards any processed data

### Requirement: Implement settings persistence and loading
The system SHALL properly persist settings and handle loading states.

#### Scenario: Load settings on startup
- **WHEN** application starts
- **THEN** system loads settings from persistent storage
- **AND** applies settings to UI immediately
- **AND** handles missing/invalid values with defaults
- **AND** shows loading indicator during load (< 300ms)

#### Scenario: Save settings on change
- **WHEN** any setting value changes
- **THEN** system immediately saves to persistent storage
- **AND** provides visual feedback for save operation
- **AND** handles save failures gracefully

#### Scenario: Handle missing or corrupt settings
- **WHEN** settings data is missing or corrupted
- **THEN** system applies safe default values
- **AND** logs error for debugging
- **AND** shows reset notification to user
- **AND** continues normal operation with defaults

### Requirement: Support keyboard shortcuts and accessibility
The system SHALL support keyboard shortcuts and accessibility features.

#### Scenario: Handle keyboard shortcuts on desktop
- **WHEN** user presses Ctrl/Cmd+, on desktop
- **THEN** system opens settings dialog
- **WHEN** user presses Escape in dialog
- **THEN** system closes dialog
- **WHEN** user presses Enter in text field
- **THEN** system confirms current action

#### Scenario: Provide screen reader support
- **WHEN** screen reader encounters settings elements
- **THEN** system provides semantic labels for all interactive elements
- **AND** announces setting changes and action results
- **AND** supports navigation via screen reader

#### Scenario: Ensure color contrast compliance
- **WHEN** displaying settings interface
- **THEN** system maintains 4.5:1 text contrast ratio
- **AND** provides sufficient icon contrast (3:1)
- **AND** supports both light and dark modes

### Requirement: Handle edge cases and errors gracefully
The system SHALL handle edge cases and provide clear error feedback.

#### Scenario: Handle missing app information
- **WHEN** app version or build info is unavailable
- **THEN** system displays "未知版本" for version
- **AND** shows "Build 未知" for build number
- **AND** continues with other available information

#### Scenario: Handle empty contributor list
- **WHEN** no contributors are available
- **THEN** system displays "暂无贡献者" text
- **AND** maintains consistent layout structure
- **AND** continues with other About content

#### Scenario: Handle empty changelog
- **WHEN** no changelog entries are available
- **THEN** system hides changelog section
- **AND** maintains consistent About page layout
- **AND** does not show empty state for changelog

#### Scenario: Handle file permission errors
- **WHEN** file access permission is denied
- **THEN** system shows "文件访问被拒绝，请选择其他文件" toast
- **AND** provides clear instructions for resolution
- **AND** offers alternative access methods

## Visual Design Specifications

### Mobile Page Layout

#### Page Structure
- **Page Type**: Full-screen page
- **Top Navigation Bar**:
  - Height: 56px
  - Title: "设置" (18px bold, centered)
  - Background: Theme primary color
  - Text color: White
- **Content Area**:
  - Background color: Light gray (#F5F5F5)
  - Padding: 16px
  - Scrollable content
- **Component Spacing**: 16px between sections

#### Setting Section Card
- **Background**: White
- **Border Radius**: 12px
- **Padding**: 16px
- **Shadow**: 0 2px 8px rgba(0,0,0,0.08)
- **Section Title**:
  - Font size: 16px
  - Font weight: Bold
  - Color: #333333
  - Icon size: 20px
  - Icon-text spacing: 8px

#### Toggle Setting Item
- **Layout**: Horizontal (label left, switch right)
- **Height**: Minimum 56px
- **Label**:
  - Font size: 15px
  - Font weight: Bold
  - Color: #333333
- **Description**:
  - Font size: 13px
  - Font weight: Regular
  - Color: #666666
  - Margin top: 4px
- **Switch Control**:
  - Size: 51x31px
  - Track color (off): #E0E0E0
  - Track color (on): Theme primary color
  - Thumb color: White
  - Animation: 200ms ease-in-out

#### Button Setting Item
- **Layout**: Vertical (label and description on top, buttons below)
- **Label + Description**: Same as toggle item
- **Button Group**:
  - Layout: Horizontal
  - Spacing: 12px
  - Margin top: 12px
- **Button**:
  - Height: 36px
  - Border radius: 8px
  - Border: 1px solid theme primary color
  - Background: Transparent
  - Text color: Theme primary color
  - Font size: 14px
  - Padding: 0 16px
  - Active state: Background theme primary color, text white

#### About App Card
- **Version Info**:
  - Layout: Horizontal (label: value)
  - Label font: 14px regular, #666666
  - Value font: 14px bold, #333333
  - Spacing: 8px
- **Tech Stack**:
  - Layout: Vertical (label on top, value below)
  - Label font: 14px regular, #666666
  - Value font: 13px regular, #333333
  - Line height: 1.6
- **GitHub Link**:
  - Font size: 14px
  - Color: Theme primary color
  - Icon: ExternalLink (16px)
  - Underline on hover
- **Contributors**:
  - Font size: 13px
  - Color: #333333
  - Comma-separated, auto-wrap
- **Changelog**:
  - Version: 14px bold, #333333
  - Date: 12px regular, #999999
  - Changes: 13px regular, #666666
  - Bullet points with 4px spacing

### Desktop Dialog Layout

#### Dialog Structure
- **Width**: 600px
- **Max Height**: 80vh
- **Background**: White
- **Border Radius**: 16px
- **Shadow**: 0 8px 32px rgba(0,0,0,0.12)
- **Overlay**: rgba(0,0,0,0.4) with backdrop blur

#### Title Bar
- **Height**: 64px
- **Padding**: 0 24px
- **Border Bottom**: 1px solid #E0E0E0
- **Title**:
  - Font size: 20px
  - Font weight: Bold
  - Color: #333333
- **Close Button**:
  - Size: 32x32px
  - Icon: X (20px)
  - Color: #666666
  - Hover: Background #F5F5F5, rounded

#### Content Area
- **Padding**: 24px
- **Scrollable**: Yes
- **Max Height**: calc(80vh - 64px)

#### Setting Section
- **Margin Bottom**: 24px
- **Section Title**:
  - Font size: 16px
  - Font weight: Bold
  - Color: #333333
  - Margin bottom: 16px
  - Icon size: 20px

#### Toggle Setting Item (Desktop)
- **Height**: Minimum 48px
- **Switch Size**: 44x24px
- **Other specs**: Same as mobile

#### Button Setting Item (Desktop)
- **Button Spacing**: 8px
- **Other specs**: Same as mobile

### Color Specifications

#### Light Mode
- **Background**: #FFFFFF
- **Secondary Background**: #F5F5F5
- **Text Primary**: #333333
- **Text Secondary**: #666666
- **Text Tertiary**: #999999
- **Border**: #E0E0E0
- **Primary Color**: Theme primary (e.g., #2196F3)
- **Success**: #4CAF50
- **Error**: #F44336

#### Dark Mode
- **Background**: #1E1E1E
- **Secondary Background**: #2C2C2C
- **Text Primary**: #FFFFFF
- **Text Secondary**: #B0B0B0
- **Text Tertiary**: #808080
- **Border**: #404040
- **Primary Color**: Theme primary (lighter variant)
- **Success**: #66BB6A
- **Error**: #EF5350

### Animation Specifications

- **Switch Toggle**: 200ms ease-in-out
- **Theme Transition**: 300ms ease-in-out
- **Dialog Open**: 250ms ease-out (scale 0.95 to 1.0, opacity 0 to 1)
- **Dialog Close**: 200ms ease-in (scale 1.0 to 0.95, opacity 1 to 0)
- **Button Hover**: 150ms ease-in-out
- **Toast Appear**: 300ms ease-out (slide up + fade in)

## Detailed Interaction Flows

### Flow 1: Open Settings Panel

#### Mobile
1. User taps "设置" tab in bottom navigation bar
2. System navigates to settings page with slide transition (300ms)
3. System loads settings from storage (< 300ms)
4. System displays settings page with all sections
5. System applies current theme and setting values

#### Desktop
1. User presses Ctrl/Cmd+, OR clicks settings menu item
2. System shows modal overlay with fade-in (250ms)
3. System displays settings dialog with scale-up animation
4. System loads settings from storage (< 300ms)
5. System displays all sections with current values

### Flow 2: Toggle Sync Notification

1. User clicks/taps sync notification switch
2. System immediately updates switch visual state (< 100ms)
3. System saves new value to persistent storage
4. System updates notification registration in background
5. System shows success toast: "同步通知已开启/关闭"
6. **On Failure**:
   - System reverts switch to previous state
   - System shows error toast: "设置保存失败，请重试"
   - System logs error for debugging

### Flow 3: Toggle Dark Mode

1. User clicks/taps dark mode switch
2. System immediately updates switch visual state (< 100ms)
3. System starts theme transition animation (300ms)
4. System updates all UI components with new theme
5. System saves theme preference to storage
6. System shows success toast: "深色模式已开启/关闭"
7. **On Failure**:
   - System reverts to previous theme with animation
   - System shows error toast: "主题切换失败，请重试"

### Flow 4: Export Data

1. User clicks "导出数据" button
2. System shows ExportConfirmDialog:
   - Title: "确认导出数据"
   - Message: "将导出所有笔记数据为 Loro 格式文件（.loro）"
   - Buttons: "确认导出", "取消"
3. **If user clicks "取消"**:
   - System closes dialog
   - System returns to settings page
4. **If user clicks "确认导出"**:
   - System closes confirmation dialog
   - System opens file save dialog
   - Default filename: `cardmind-export-{YYYY-MM-DD-HHmmss}.loro`
5. **If user cancels file dialog**:
   - System returns to settings page
6. **If user selects save location**:
   - System shows progress indicator
   - System calls Rust FFI to get Loro snapshot
   - System writes data to selected file
   - System shows success toast: "数据导出成功"
7. **On Failure**:
   - System shows error toast with specific message:
     - "文件写入失败，请检查权限"
     - "数据导出失败，请重试"
   - System logs error details

### Flow 5: Import Data

1. User clicks "导入数据" button
2. System opens file picker dialog (filter: .loro files)
3. **If user cancels file picker**:
   - System returns to settings page
4. **If user selects .loro file**:
   - System validates file size (< 100MB)
   - **If file too large**:
     - System shows error toast: "文件过大（限制 100MB），请选择其他文件"
     - System returns to settings page
5. System calls Rust FFI to parse file and get card count
6. **If file format invalid**:
   - System shows error toast: "文件格式错误，请选择有效的 .loro 文件"
   - System returns to settings page
7. System shows ImportConfirmDialog:
   - Title: "确认导入数据"
   - File name: {selected_file_name}
   - Card count: "将导入 {count} 张卡片"
   - Warning: "数据将合并到现有数据，不会覆盖"
   - Buttons: "确认导入", "取消"
8. **If user clicks "取消"**:
   - System closes dialog
   - System discards parsed data
   - System returns to settings page
9. **If user clicks "确认导入"**:
   - System closes confirmation dialog
   - System shows progress indicator
   - System calls Rust FFI to merge data
   - System updates UI with new data
   - System shows success toast: "数据导入成功，已导入 {count} 张卡片"
10. **On Failure**:
    - System shows error toast with specific message:
      - "文件读取失败，请检查权限"
      - "数据导入失败，请重试"
    - System logs error details

### Flow 6: Click GitHub Link

1. User clicks GitHub repository link in About section
2. System calls url_launcher to open link in external browser
3. **On Success**:
   - System opens link in default browser
4. **On Failure**:
   - System shows error toast: "无法打开链接，请手动访问"
   - System logs error

### Flow 7: Close Settings Panel

#### Mobile
1. User taps back button or other navigation tab
2. System navigates away from settings page
3. System saves any pending settings changes

#### Desktop
1. User clicks close button OR presses Escape key OR clicks outside dialog
2. System starts dialog close animation (200ms)
3. System fades out overlay
4. System removes dialog from DOM
5. System saves any pending settings changes

## Data Boundaries and Constraints

| Scenario | Constraint | Handling | Default Value |
|----------|-----------|----------|---------------|
| Sync notification status is null | Not allowed | Use default value | true (enabled) |
| Dark mode status is null | Not allowed | Use default value | false (follow system) |
| App version is empty | Not allowed | Show fallback text | "未知版本" |
| Build number is empty | Not allowed | Show fallback text | "Build 未知" |
| Contributors list is empty | Allowed | Show placeholder | "暂无贡献者" |
| Changelog is empty | Allowed | Hide changelog section | N/A |
| Import file size > 100MB | Not allowed | Show error toast | N/A |
| Import file format invalid | Not allowed | Show error toast | N/A |
| Import card count = 0 | Allowed | Show warning in dialog | N/A |
| Export fails due to permissions | Error | Show error toast + retry | N/A |
| Settings load timeout (> 5s) | Error | Use defaults + show warning | All defaults |
| GitHub URL is empty | Allowed | Hide link | N/A |
| License info is empty | Allowed | Show "未知协议" | "未知协议" |

## Performance Constraints

| Operation | Target | Maximum | Measurement |
|-----------|--------|---------|-------------|
| Settings panel load time | < 200ms | 300ms | Time from open to fully rendered |
| Switch toggle response | < 50ms | 100ms | Time from tap to visual feedback |
| Theme transition animation | 300ms | 300ms | Fixed duration |
| Settings save operation | < 100ms | 500ms | Time to persist to storage |
| Data export (1000 cards) | < 3s | 5s | Time from confirm to completion |
| Data import (1000 cards) | < 5s | 10s | Time from confirm to completion |
| File validation | < 500ms | 1s | Time to validate file format/size |
| Dialog open animation | 250ms | 250ms | Fixed duration |
| Dialog close animation | 200ms | 200ms | Fixed duration |
| Toast display duration | 2s | 3s | Auto-dismiss time |

## Component Specifications

### SettingsPanelMobile Component

```dart
class SettingsPanelMobile extends StatelessWidget {
  /// 同步通知开关状态
  final bool syncNotificationEnabled;

  /// 深色模式开关状态
  final bool darkModeEnabled;

  /// 应用版本号
  final String appVersion;

  /// 同步通知开关回调
  final OnToggleSyncNotification onToggleSyncNotification;

  /// 深色模式开关回调
  final OnToggleDarkMode onToggleDarkMode;

  /// 导出数据回调
  final OnExportData onExportData;

  /// 导入数据回调
  final OnImportData onImportData;

  const SettingsPanelMobile({
    required this.syncNotificationEnabled,
    required this.darkModeEnabled,
    required this.appVersion,
    required this.onToggleSyncNotification,
    required this.onToggleDarkMode,
    required this.onExportData,
    required this.onImportData,
  });
}
```

### SettingsPanelDesktop Component

```dart
class SettingsPanelDesktop extends StatelessWidget {
  /// 同步通知开关状态
  final bool syncNotificationEnabled;

  /// 深色模式开关状态
  final bool darkModeEnabled;

  /// 应用版本号
  final String appVersion;

  /// 同步通知开关回调
  final OnToggleSyncNotification onToggleSyncNotification;

  /// 深色模式开关回调
  final OnToggleDarkMode onToggleDarkMode;

  /// 导出数据回调
  final OnExportData onExportData;

  /// 导入数据回调
  final OnImportData onImportData;

  const SettingsPanelDesktop({
    required this.syncNotificationEnabled,
    required this.darkModeEnabled,
    required this.appVersion,
    required this.onToggleSyncNotification,
    required this.onToggleDarkMode,
    required this.onExportData,
    required this.onImportData,
  });
}
```

### SettingSection Component

```dart
class SettingSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const SettingSection({
    required this.title,
    required this.icon,
    required this.children,
  });
}
```

### SettingItem Component

```dart
class SettingItem extends StatelessWidget {
  final String label;
  final String description;
  final IconData? icon;
  final Widget? trailing;

  const SettingItem({
    required this.label,
    required this.description,
    this.icon,
    this.trailing,
  });
}
```

### ExportConfirmDialog Component

```dart
class ExportConfirmDialog extends StatelessWidget {
  final OnConfirmExport onConfirm;

  const ExportConfirmDialog({
    required this.onConfirm,
  });
}
```

### ImportConfirmDialog Component

```dart
class ImportConfirmDialog extends StatelessWidget {
  final String fileName;
  final int cardCount;
  final OnConfirmImport onConfirm;

  const ImportConfirmDialog({
    required this.fileName,
    required this.cardCount,
    required this.onConfirm,
  });
}
```

## Data Models

### AppInfo Model

```dart
class AppInfo {
  final String version;           // 版本号（如 "1.0.0"）
  final String buildNumber;       // 构建号（如 "100"）
  final String license;           // 开源协议（如 "MIT"）
  final String githubUrl;         // GitHub 仓库 URL
  final List<String> contributors; // 贡献者列表
  final List<ChangelogEntry> changelog; // 更新日志

  const AppInfo({
    required this.version,
    required this.buildNumber,
    required this.license,
    required this.githubUrl,
    required this.contributors,
    required this.changelog,
  });
}
```

### ChangelogEntry Model

```dart
class ChangelogEntry {
  final String version;           // 版本号
  final DateTime releaseDate;     // 发布日期
  final List<String> changes;     // 变更列表

  const ChangelogEntry({
    required this.version,
    required this.releaseDate,
    required this.changes,
  });
}
```

### Callback Type Definitions

```dart
typedef OnToggleSyncNotification = void Function(bool enabled);
typedef OnToggleDarkMode = void Function(bool enabled);
typedef OnExportData = Future<void> Function();
typedef OnImportData = Future<void> Function();
typedef OnConfirmExport = Future<void> Function();
typedef OnConfirmImport = Future<void> Function();
```

## Implementation Details

### Settings Persistence

**Technology**: `shared_preferences` package

**Storage Keys**:
- `sync_notification_enabled`: bool
- `dark_mode_enabled`: bool

**Implementation**:
```dart
// Save setting
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('sync_notification_enabled', value);

// Load setting
final prefs = await SharedPreferences.getInstance();
final value = prefs.getBool('sync_notification_enabled') ?? true;
```

### Loro File Export/Import

**Export Process**:
1. Call Rust FFI: `loro_export_snapshot()`
2. Get binary data as Uint8List
3. Generate filename: `cardmind-export-{YYYY-MM-DD-HHmmss}.loro`
4. Write to file using file_picker save dialog

**Import Process**:
1. Select file using file_picker
2. Read file as Uint8List
3. Call Rust FFI: `loro_parse_file(data)` to get card count
4. Show confirmation dialog
5. Call Rust FFI: `loro_import_merge(data)` to merge data

**File Naming Format**:
- Pattern: `cardmind-export-{YYYY-MM-DD-HHmmss}.loro`
- Example: `cardmind-export-2026-01-29-143052.loro`
- Invalid characters replaced with underscore

### State Management

**Technology**: Riverpod

**Providers**:
```dart
final syncNotificationProvider = StateNotifierProvider<SyncNotificationNotifier, bool>(...);
final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>(...);
final appInfoProvider = FutureProvider<AppInfo>(...);
```

### Theme Switching

**Implementation**:
```dart
// ThemeProvider manages theme mode
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(...);

// MaterialApp configuration
MaterialApp(
  themeAnimationDuration: Duration(milliseconds: 300),
  themeAnimationCurve: Curves.easeInOut,
  theme: lightTheme,
  darkTheme: darkTheme,
  themeMode: themeMode,
  ...
)
```

### Required Dependencies

```yaml
dependencies:
  file_picker: ^6.0.0        # File selection for import/export
  shared_preferences: ^2.2.0 # Settings persistence
  url_launcher: ^6.2.0       # Open external links
  fluttertoast: ^8.2.0       # Toast notifications
  package_info_plus: ^5.0.0  # App version information
  flutter_riverpod: ^2.4.0   # State management
```

## Test Specifications

### Unit Tests (8 test cases)

- **UT-001**: Test AppInfo model creation with valid data
- **UT-002**: Test ChangelogEntry model creation with valid data
- **UT-003**: Test default setting values (sync notification = true, dark mode = false)
- **UT-004**: Test settings save logic with shared_preferences
- **UT-005**: Test settings load logic with missing/invalid data
- **UT-006**: Test file name generation with current timestamp
- **UT-007**: Test file name invalid character replacement (/, \, :, *, ?, ", <, >, |)
- **UT-008**: Test Loro file format validation (magic bytes, version check)

### Widget Tests (45 test cases)

#### Rendering Tests (15 test cases)
- **WT-001**: Mobile settings page renders with all sections
- **WT-002**: Desktop settings dialog renders with correct dimensions
- **WT-003**: Sync notification switch renders with correct state (on)
- **WT-004**: Sync notification switch renders with correct state (off)
- **WT-005**: Dark mode switch renders with correct state (on)
- **WT-006**: Dark mode switch renders with correct state (off)
- **WT-007**: Export/Import buttons render correctly
- **WT-008**: About section renders with app version
- **WT-009**: About section renders with tech stack info
- **WT-010**: About section renders with contributors list
- **WT-011**: About section renders with changelog (3 versions)
- **WT-012**: About section renders with GitHub link
- **WT-013**: Empty contributors list shows "暂无贡献者"
- **WT-014**: Empty changelog hides changelog section
- **WT-015**: Missing version shows "未知版本"

#### Interaction Tests (20 test cases)
- **WT-016**: Tap sync notification switch toggles state
- **WT-017**: Tap dark mode switch toggles state
- **WT-018**: Tap export button shows confirmation dialog
- **WT-019**: Tap import button opens file picker
- **WT-020**: Confirm export dialog proceeds with export
- **WT-021**: Cancel export dialog closes without action
- **WT-022**: Confirm import dialog proceeds with import
- **WT-023**: Cancel import dialog closes without action
- **WT-024**: Tap GitHub link opens external browser
- **WT-025**: Desktop: Ctrl/Cmd+, opens settings dialog
- **WT-026**: Desktop: Escape key closes settings dialog
- **WT-027**: Desktop: Click outside dialog closes it
- **WT-028**: Desktop: Click close button closes dialog
- **WT-029**: Mobile: Back button closes settings page
- **WT-030**: Switch toggle shows success toast
- **WT-031**: Switch toggle failure shows error toast and reverts
- **WT-032**: Export success shows success toast
- **WT-033**: Export failure shows error toast
- **WT-034**: Import success shows success toast with card count
- **WT-035**: Import failure shows error toast

#### Edge Case Tests (10 test cases)
- **WT-036**: Handle null sync notification value (use default true)
- **WT-037**: Handle null dark mode value (use default false)
- **WT-038**: Handle file size > 100MB (show error)
- **WT-039**: Handle invalid file format (show error)
- **WT-040**: Handle file permission denied (show error)
- **WT-041**: Handle import with 0 cards (show warning)
- **WT-042**: Handle settings load timeout (use defaults)
- **WT-043**: Handle settings save failure (show error)
- **WT-044**: Handle corrupted settings data (use defaults)
- **WT-045**: Handle missing app info (show fallback text)

## Rust FFI Interfaces

### Export Snapshot Interface

```rust
#[flutter_rust_bridge::frb(sync)]
pub fn loro_export_snapshot() -> Result<Vec<u8>, String> {
    // Get current Loro document
    // Export as binary snapshot
    // Return as byte array
}
```

### Import Merge Interface

```rust
#[flutter_rust_bridge::frb(sync)]
pub fn loro_import_merge(data: Vec<u8>) -> Result<(), String> {
    // Parse Loro snapshot from bytes
    // Merge into current document (CRDT merge)
    // Update storage
}
```

### Parse File Preview Interface

```rust
#[flutter_rust_bridge::frb(sync)]
pub fn loro_parse_file(data: Vec<u8>) -> Result<FilePreview, String> {
    // Parse Loro snapshot
    // Count cards/notes
    // Return preview info
}

pub struct FilePreview {
    pub card_count: i32,
    pub version: String,
}
```

## References

- React UI Reference: `react_ui_reference/src/app/components/settings-panel.tsx`
- Flutter file_picker: https://pub.dev/packages/file_picker
- Flutter shared_preferences: https://pub.dev/packages/shared_preferences
- Flutter url_launcher: https://pub.dev/packages/url_launcher
- Flutter fluttertoast: https://pub.dev/packages/fluttertoast
- Flutter package_info_plus: https://pub.dev/packages/package_info_plus
- Material Design Lists: https://m3.material.io/components/lists/overview
- Material Design Dialogs: https://m3.material.io/components/dialogs/overview
- Flutter Riverpod: https://riverpod.dev/
- Loro CRDT: https://loro.dev/