// input: 当前无外部输入，按默认构造生成引导控制器。
// output: 通过 state getter 返回默认 OnboardingState 实例。
// pos: 引导流程控制器，负责对外提供引导页状态读取。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/onboarding/onboarding_state.dart';

class OnboardingController {
  const OnboardingController();

  OnboardingState get state => const OnboardingState();
}
