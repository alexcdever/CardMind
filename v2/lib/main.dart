import 'package:flutter/material.dart';
import 'pages/note_list_page.dart';
import 'pages/editor_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CardMindApp());
}

class CardMindApp extends StatelessWidget {
  const CardMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardMind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const NoteListPage(),
            );
          case '/editor':
            final args = settings.arguments as Map<String, dynamic>?;
            final noteId = args?['noteId'] as int?;
            return MaterialPageRoute(
              builder: (_) => EditorPage(noteId: noteId),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const NoteListPage(),
            );
        }
      },
    );
  }
}
