import 'package:flutter/material.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(onPressed: () {}, child: const Text('先本地使用')),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () {}, child: const Text('创建或加入数据池')),
            ],
          ),
        ),
      ),
    );
  }
}
