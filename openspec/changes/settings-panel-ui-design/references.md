# Settings Panel References

## Internal References

### Design Documents
- **Original Design Document**: `docs/plans/2026-01-26-settings-panel-ui-design.md`
- **React UI Reference**: `react_ui_reference/src/app/components/settings-panel.tsx`

### Related Features
- **Device Manager Mobile UI**: `docs/plans/2026-01-26-device-manager-mobile-ui-design.md`
- **Device Manager Desktop UI**: Similar design patterns for platform-specific interfaces

## Flutter Packages

### Core Dependencies

#### file_picker (^6.0.0)
- **Purpose**: File selection for import/export operations
- **Documentation**: https://pub.dev/packages/file_picker
- **Key Features**:
  - Cross-platform file picking
  - Save file dialog support
  - File type filtering (.loro extension)
  - File size information
- **Usage**: Import/export Loro data files

#### shared_preferences (^2.2.0)
- **Purpose**: Persistent storage for settings
- **Documentation**: https://pub.dev/packages/shared_preferences
- **Key Features**:
  - Simple key-value storage
  - Cross-platform support
  - Async API
- **Usage**: Store sync notification and dark mode preferences

#### url_launcher (^6.2.0)
- **Purpose**: Open external URLs
- **Documentation**: https://pub.dev/packages/url_launcher
- **Key Features**:
  - Launch URLs in external browser
  - Email and phone support
  - Platform-specific handling
- **Usage**: Open GitHub repository and changelog links

#### fluttertoast (^8.2.0)
- **Purpose**: Display toast notifications
- **Documentation**: https://pub.dev/packages/fluttertoast
- **Key Features**:
  - Cross-platform toast messages
  - Customizable appearance
  - Duration control
- **Usage**: Show success/error feedback for operations

#### package_info_plus (^5.0.0)
- **Purpose**: Retrieve app version information
- **Documentation**: https://pub.dev/packages/package_info_plus
- **Key Features**:
  - App version and build number
  - Package name
  - Cross-platform support
- **Usage**: Display app version in About section

#### flutter_riverpod (^2.4.0)
- **Purpose**: State management
- **Documentation**: https://riverpod.dev/
- **Key Features**:
  - Compile-safe providers
  - Automatic disposal
  - Testing support
- **Usage**: Manage settings state and app info

## Design Resources

### Material Design 3

#### Lists
- **URL**: https://m3.material.io/components/lists/overview
- **Relevance**: Setting item layout and styling
- **Key Concepts**:
  - List item structure
  - Leading and trailing elements
  - Multi-line support
  - Dividers and spacing

#### Dialogs
- **URL**: https://m3.material.io/components/dialogs/overview
- **Relevance**: Confirmation dialogs for import/export
- **Key Concepts**:
  - Dialog structure
  - Action buttons
  - Content layout
  - Accessibility

#### Switches
- **URL**: https://m3.material.io/components/switch/overview
- **Relevance**: Toggle switches for settings
- **Key Concepts**:
  - Switch states
  - Animation timing
  - Touch targets
  - Accessibility labels

#### Navigation Drawer
- **URL**: https://m3.material.io/components/navigation-drawer/overview
- **Relevance**: Settings organization patterns
- **Key Concepts**:
  - Section grouping
  - Icon usage
  - Active states

### Flutter Design Patterns

#### Responsive Design
- **URL**: https://docs.flutter.dev/ui/layout/responsive/adaptive-responsive
- **Relevance**: Platform-specific layouts (mobile vs desktop)
- **Key Concepts**:
  - LayoutBuilder
  - MediaQuery
  - Platform detection

#### Theming
- **URL**: https://docs.flutter.dev/cookbook/design/themes
- **Relevance**: Dark mode implementation
- **Key Concepts**:
  - ThemeData
  - Theme switching
  - Color schemes

## Technical References

### Loro CRDT

#### Official Documentation
- **URL**: https://loro.dev/
- **Relevance**: Data format for import/export
- **Key Concepts**:
  - CRDT fundamentals
  - Snapshot format
  - Merge operations
  - Binary encoding

#### Loro Rust API
- **Relevance**: FFI interface implementation
- **Key Operations**:
  - Export snapshot
  - Import and merge
  - Parse file format
  - Version compatibility

### Flutter Rust Bridge

#### Documentation
- **URL**: https://cjycode.com/flutter_rust_bridge/
- **Relevance**: Rust FFI integration
- **Key Concepts**:
  - Code generation
  - Type mapping
  - Async operations
  - Error handling

## Platform Guidelines

### iOS Human Interface Guidelines

#### Settings
- **URL**: https://developer.apple.com/design/human-interface-guidelines/settings
- **Relevance**: iOS settings design patterns
- **Key Concepts**:
  - Settings organization
  - Toggle switches
  - Navigation patterns

### Android Material Design

#### Settings
- **URL**: https://m3.material.io/foundations/layout/applying-layout/window-size-classes
- **Relevance**: Android settings design patterns
- **Key Concepts**:
  - Preference screens
  - Switch preferences
  - Dialog preferences

### macOS Human Interface Guidelines

#### Preferences
- **URL**: https://developer.apple.com/design/human-interface-guidelines/preferences
- **Relevance**: Desktop settings dialog design
- **Key Concepts**:
  - Preferences window
  - Toolbar organization
  - Keyboard shortcuts (Cmd+,)

### Windows Design Guidelines

#### Settings
- **URL**: https://learn.microsoft.com/en-us/windows/apps/design/
- **Relevance**: Windows settings design patterns
- **Key Concepts**:
  - Settings flyout
  - Toggle switches
  - Navigation patterns

## Accessibility Standards

### WCAG 2.1 Guidelines

#### Color Contrast
- **URL**: https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html
- **Requirement**: 4.5:1 for text, 3:1 for UI components
- **Relevance**: Ensure readable text in both light and dark modes

#### Keyboard Navigation
- **URL**: https://www.w3.org/WAI/WCAG21/Understanding/keyboard.html
- **Requirement**: All functionality available via keyboard
- **Relevance**: Desktop keyboard shortcuts and focus management

#### Screen Reader Support
- **URL**: https://www.w3.org/WAI/WCAG21/Understanding/name-role-value.html
- **Requirement**: Semantic labels for all interactive elements
- **Relevance**: Accessibility labels for switches and buttons

### Flutter Accessibility

#### Semantics
- **URL**: https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility
- **Relevance**: Screen reader support implementation
- **Key Concepts**:
  - Semantics widget
  - Semantic labels
  - Announcements

## Testing Resources

### Flutter Testing

#### Widget Testing
- **URL**: https://docs.flutter.dev/cookbook/testing/widget/introduction
- **Relevance**: UI component testing
- **Key Concepts**:
  - WidgetTester
  - Finder
  - Interaction simulation

#### Integration Testing
- **URL**: https://docs.flutter.dev/cookbook/testing/integration/introduction
- **Relevance**: End-to-end testing
- **Key Concepts**:
  - IntegrationTestWidgetsFlutterBinding
  - Real device testing
  - Performance profiling

### Riverpod Testing

#### Testing Guide
- **URL**: https://riverpod.dev/docs/essentials/testing
- **Relevance**: State management testing
- **Key Concepts**:
  - ProviderContainer
  - Mock providers
  - Override providers

## Performance Resources

### Flutter Performance

#### Best Practices
- **URL**: https://docs.flutter.dev/perf/best-practices
- **Relevance**: Optimize settings panel performance
- **Key Concepts**:
  - Build optimization
  - Lazy loading
  - Animation performance

#### Profiling
- **URL**: https://docs.flutter.dev/perf/ui-performance
- **Relevance**: Measure and optimize performance
- **Key Concepts**:
  - DevTools
  - Performance overlay
  - Timeline analysis

## Security Considerations

### File Operations Security

#### Best Practices
- Validate file size before processing (< 100MB limit)
- Verify file format and magic bytes
- Handle file permissions gracefully
- Sanitize file names to prevent path traversal

#### Error Handling
- Never expose internal paths in error messages
- Log security-relevant errors
- Provide user-friendly error messages
- Implement rate limiting for file operations

### Data Privacy

#### Considerations
- Settings stored locally only (no cloud sync by default)
- Export files contain all user data (warn users)
- Import merges data (no automatic deletion)
- Clear data only via app uninstall

## Related Projects

### Similar Implementations

#### Flutter Settings UI
- **URL**: https://pub.dev/packages/settings_ui
- **Relevance**: Reference implementation for settings screens
- **Note**: Not used directly, but provides design inspiration

#### Adaptive Dialog
- **URL**: https://pub.dev/packages/adaptive_dialog
- **Relevance**: Platform-specific dialog patterns
- **Note**: Reference for confirmation dialogs

## Community Resources

### Flutter Community

#### Flutter Dev Discord
- **URL**: https://discord.gg/flutter
- **Relevance**: Community support and discussions

#### Flutter Subreddit
- **URL**: https://reddit.com/r/FlutterDev
- **Relevance**: Community examples and best practices

### Stack Overflow

#### Flutter Tag
- **URL**: https://stackoverflow.com/questions/tagged/flutter
- **Relevance**: Common issues and solutions

#### Riverpod Tag
- **URL**: https://stackoverflow.com/questions/tagged/flutter-riverpod
- **Relevance**: State management patterns

## Version History

### Document Updates
- **2026-01-29**: Initial reference document created
- **Source**: Compiled from original design document and implementation research

## Notes

- All external links should be verified before implementation
- Package versions may need updates based on latest stable releases
- Platform guidelines may change; check for updates before finalizing design
- Accessibility standards are minimum requirements; aim for better compliance
