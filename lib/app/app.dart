import 'package:cardmind/features/onboarding/onboarding_page.dart';
import 'package:flutter/material.dart';

class CardMindApp extends StatelessWidget {
  const CardMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardMind',
      theme: ThemeData(useMaterial3: true),
      home: const OnboardingPage(),
    );
  }
}
