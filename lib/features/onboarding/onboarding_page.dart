// input: 用户点击“先本地使用”或“创建或加入数据池”按钮。
// output: 触发页面导航，进入 CardsPage 或 PoolPage。
// pos: 首次引导页面，负责用户进入本地模式或数据池流程。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/cards/cards_page.dart';
import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
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
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(builder: (_) => const CardsPage()),
                  );
                },
                child: const Text('先本地使用'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const PoolPage(state: PoolState.notJoined()),
                    ),
                  );
                },
                child: const Text('创建或加入数据池'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
