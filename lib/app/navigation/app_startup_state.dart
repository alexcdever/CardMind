/// 应用启动阶段枚举。
///
/// 定义应用从初始启动到完全就绪的各个阶段：
/// - [booting]: 应用初始化中
/// - [localReady]: 本地数据就绪，等待远程同步
/// - [poolProbing]: 正在探测数据池状态
/// - [ready]: 完全就绪，可以正常使用
enum AppStartupStage {
  booting,
  localReady,
  poolProbing,
  ready,
}
