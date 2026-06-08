import 'package:cardmind/app/navigation/app_startup_state.dart';
import 'package:cardmind/app/theme/cardmind_colors.dart';
import 'package:flutter/material.dart';

/// 启动过渡覆盖层组件。
///
/// 在应用启动阶段（[AppStartupStage.booting]、[AppStartupStage.localReady]、
/// [AppStartupStage.poolProbing]）渲染全屏覆盖层，展示启动进度信息。
/// 当阶段推进至 [AppStartupStage.ready] 时，直接渲染子组件，不加覆盖层。
///
/// ## 各阶段展示内容
/// - [AppStartupStage.booting]：显示"正在初始化…"和 CircularProgressIndicator
/// - [AppStartupStage.localReady]：显示"正在从其他设备同步…"和 CircularProgressIndicator
/// - [AppStartupStage.poolProbing]：显示"正在检查数据池状态…"和副标题
/// - [AppStartupStage.ready]：直接渲染 child，不加覆盖层
class StartupOverlay extends StatelessWidget {
  /// 创建启动过渡覆盖层。
  ///
  /// [stage] - 当前启动阶段
  /// [message] - 可选的自定义消息，覆盖默认阶段文案
  /// [child] - 底层子组件，在就绪时直接展示
  const StartupOverlay({
    super.key,
    required this.stage,
    this.message,
    required this.child,
  });

  /// 当前启动阶段。
  final AppStartupStage stage;

  /// 可选的自定义消息，覆盖默认阶段文案。
  final String? message;

  /// 底层子组件。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (stage == AppStartupStage.ready) {
      return child;
    }

    return Stack(
      children: [
        child,
        // 全屏覆盖层：用 AnimatedOpacity 实现淡入淡出效果
        AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 400),
          child: Container(
            color: CardMindColors.bgCanvas,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: CardMindColors.brand,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _getStageMessage(stage),
                    style: const TextStyle(
                      color: CardMindColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (stage == AppStartupStage.poolProbing) ...const [
                    SizedBox(height: 8),
                    Text(
                      '同步完成后即可查看多设备笔记',
                      style: TextStyle(
                        color: CardMindColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 根据当前阶段获取默认文案。
  String _getStageMessage(AppStartupStage stage) {
    if (message != null) return message!;
    return switch (stage) {
      AppStartupStage.booting => '正在初始化…',
      AppStartupStage.localReady => '正在从其他设备同步…',
      AppStartupStage.poolProbing => '正在检查数据池状态…',
      AppStartupStage.ready => '',
    };
  }
}
