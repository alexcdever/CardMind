import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import 'bridge/bridge_helper.dart';
import 'bridge/debug_log.dart';
import 'bridge/note_repository.dart';
import 'pages/note_list_page.dart';
import 'pages/editor_page.dart';
import 'src/rust/frb_generated.dart';
import 'ui/design_system/cardmind_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 任务 U7：文件日志（Windows: %APPDATA%\com.cardmind\cardmind\logs\cardmind.log）。
  // 挂载点选在 main() 而非 BridgeHelper.init()——后者会随初始化重试重复 attach；
  // 且越早 attach 越能覆盖启动期事件。fire-and-forget：打开失败静默退化
  // （仅 debugPrint），FLUTTER_TEST 下自动跳过不落盘。
  unawaited(initializeFileLogging());
  runApp(const CardMindBootstrap());
}

Future<void> initializeCardMindBackend() async {
  // 启动事件（验收 2）：RustLib / Bridge 初始化成功或失败各有可断言事件
  await initializeBackendWithLogging(
    rustInit: RustLib.init,
    bridgeInit: () => BridgeHelper().init(),
    log: DebugLogger.instance,
  );
}

class CardMindBootstrap extends StatefulWidget {
  const CardMindBootstrap({
    super.key,
    this.initialize = initializeCardMindBackend,
  });

  final Future<void> Function() initialize;

  @override
  State<CardMindBootstrap> createState() => _CardMindBootstrapState();
}

class _CardMindBootstrapState extends State<CardMindBootstrap> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _startInitialization();
  }

  Future<void> _startInitialization() {
    return Future<void>.delayed(Duration.zero, widget.initialize);
  }

  void _retry() {
    setState(() {
      _initialization = _startInitialization();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const CardMindApp();
        }
        final initializationFailed =
            snapshot.connectionState == ConnectionState.done &&
            snapshot.hasError;
        return _CardMindStartupScreen(
          error: initializationFailed,
          onRetry: initializationFailed ? _retry : null,
        );
      },
    );
  }
}

class _CardMindStartupScreen extends StatelessWidget {
  const _CardMindStartupScreen({required this.error, this.onRetry});

  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardMind',
      debugShowCheckedModeBanner: false,
      theme: CardMindTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(CardMindSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: CardMindTokens.light.accent,
                      borderRadius: BorderRadius.circular(CardMindRadii.md),
                    ),
                    child: const Icon(
                      Icons.auto_stories_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: CardMindSpacing.lg),
                  Text(
                    'CardMind',
                    style: CardMindTheme.light.textTheme.titleMedium,
                  ),
                  const SizedBox(height: CardMindSpacing.xl),
                  if (error) ...[
                    Text(
                      '启动失败，请重试',
                      style: TextStyle(color: CardMindTokens.light.mutedInk),
                    ),
                    const SizedBox(height: CardMindSpacing.lg),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ] else
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CardMindApp extends StatelessWidget {
  const CardMindApp({super.key, this.repository});

  final NoteRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardMind',
      debugShowCheckedModeBanner: false,
      theme: CardMindTheme.light,
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
        AppFlowyEditorLocalizations.delegate,
      ],
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => NoteListPage(repository: repository),
            );
          case '/editor':
            final args = settings.arguments as Map<String, dynamic>?;
            final noteId = args?['noteId'] as String?;
            return MaterialPageRoute(
              builder: (_) =>
                  EditorPage(noteId: noteId, repository: repository),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => NoteListPage(repository: repository),
            );
        }
      },
    );
  }
}
