// 设置页常量（自 settings_page.tsx 纯结构拆出，声明逐字保留；对外使用的加 export）。

/** 面板紧凑断点（px）：<600 页边距收紧到 lg(16)，≥600 用 xl(24)。
 *  对照 settings_page.dart `MediaQuery.sizeOf(context).width < 600`；
 *  与 note_list 的 desktopBreakpoint=960（窗宽分栏）不同层级。 */
export const compactBreakpoint = 600;

/** 开关轨道尺寸（视觉件，命中区由外层 48 高行保证）。 */
export const switchTrack = { width: 44, height: 26, knob: 20 } as const;
/** 应用版本（nsh.json version；包构建版本由 Phase 4 `nsh package` 注入）。 */
export const appVersion = "0.1.0";
