// 设备页常量（自 devices_page.tsx 纯结构拆出，声明逐字保留；对外使用的加 export）。

/** 配对码有效期：与 Rust 侧 PAIRING_CODE_TTL_MINUTES = 10 分钟严格对齐
 *  （sync.rs；accept 轮询总时限即会话窗口，过期后重新生成）。
 *  `beginPairingAcceptWithAdvertising` 只返回 6 位码不返回过期时间，
 *  倒计时按「生成时刻 + 本常量」本地推导。 */
export const pairingCodeTtlMs = 10 * 60 * 1000;

/** accept 单轮短窗口（ms）：Rust 端要求有界调用，UI 用短窗口轮询，
 *  弹窗关闭/重新生成后旧轮次随窗口结束自然释放。 */
export const acceptPollMs = 10 * 1000;

/** 倒计时刻度（ms）。 */
export const countdownTickMs = 250;

/** 在线判定窗口：lastSeen 距今 ≤5 分钟视为在线（Dart onlineWindow）。 */
export const onlineWindowMs = 5 * 60 * 1000;

/** 设备列表自动刷新间隔（Dart _refreshInterval ≈2s 周期重读在线状态）。 */
export const refreshIntervalMs = 2000;

/** 6 位数字配对码（旧路径；cm1 开头走凭证路径）。 */
export const sixDigitCode = /^\d{6}$/;

/** 本机头像图标视觉尺寸（对照 Dart Icon size:22）。 */
export const localIconSize = 22;
