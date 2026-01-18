import 'package:cardmind/providers/card_provider.dart';
import 'package:cardmind/providers/theme_provider.dart';
import 'package:cardmind/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'mock_card_service.dart';

/// Test App Wrapper
///
/// 用于测试的应用包装器，跳过 Rust Bridge 初始化
/// 避免集成测试中的超时问题
class TestApp extends StatelessWidget {

  const TestApp({
    super.key,
    required this.child,
    this.cardService,
    this.themeMode,
  });
  final Widget child;
  final MockCardService? cardService;
  final ThemeMode? themeMode;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              CardProvider(cardService: cardService ?? MockCardService()),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MaterialApp(
        title: 'CardMind Test',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode ?? ThemeMode.light,
        home: child,
      ),
    );
  }
}

/// Simple Test App Wrapper (without providers)
///
/// 用于简单组件测试的包装器
class SimpleTestApp extends StatelessWidget {

  const SimpleTestApp({super.key, required this.child, this.themeMode});
  final Widget child;
  final ThemeMode? themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardMind Test',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode ?? ThemeMode.light,
      home: child,
    );
  }
}

/// Create a test widget with Material wrapper
Widget createTestWidget(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

/// Create a test widget with providers
Widget createTestWidgetWithProviders({
  required Widget child,
  MockCardService? cardService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) =>
            CardProvider(cardService: cardService ?? MockCardService()),
      ),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ],
    child: MaterialApp(home: child),
  );
}
