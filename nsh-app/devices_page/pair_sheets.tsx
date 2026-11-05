// 设备页配对弹窗（自 devices_page.tsx 纯结构拆出，JSX 逐字保留）。
import { Text, View, type JSX } from "nsh";
import { Dialog, Input } from "nsh/base";
import { colors, layout, radii, spacing, typography } from "../theme";
import { PairModeRow, Panel } from "./sections";
import {
  closePairSheet,
  enterBusy,
  enterError,
  enterInput,
  formatCountdown,
  openEnterCode,
  openShowCode,
  pairCode,
  pairDeadlineMs,
  pairError,
  pairRemainingMs,
  pairSheet,
  qrSavedPath,
  regeneratePairCode,
  savePairingQrImage,
  scanBusy,
  scanError,
  scanPairingQrImage,
  submitPeerCode,
} from "./state";

/** 「添加设备」弹窗：选配对方式（显示码 / 识别二维码图片 / 输入码）。 */
export function PairChooseSheet(): JSX.Element {
  return (
    <Dialog open={pairSheet() === "choose"}>
      <View
        style={{
          flex: 1,
          alignItems: "center",
          justifyContent: "center",
          padding: spacing.xl,
          backgroundColor: colors.paper,
        }}
      >
        <Panel>
          <Text
            style={{
              fontSize: typography.titleMedium.fontSize,
              fontWeight: "600",
              color: colors.ink,
            }}
          >
            添加设备
          </Text>
          <Text style={{ fontSize: typography.bodyMedium.fontSize, color: colors.mutedInk }}>
            选择配对方式：
          </Text>
          <PairModeRow
            icon="add"
            title="我显示配对码"
            subtitle="对方扫码或输入我屏幕上的配对信息"
            onPress={() => void openShowCode()}
          />
          {/* 二维码图片路径（QR 任务）：选一张配对二维码图片自动完成配对；
              相机直扫仍需移动端平台能力（R3），本条不含直扫。 */}
          <PairModeRow
            icon="search"
            title="识别二维码图片"
            subtitle="选择一张配对二维码图片自动完成配对"
            onPress={() => void scanPairingQrImage()}
            disabled={scanBusy()}
          />
          {() =>
            scanBusy() ? (
              <Text style={{ color: colors.mutedInk, fontSize: typography.bodyMedium.fontSize }}>
                正在识别…
              </Text>
            ) : null
          }
          <If when={scanError() !== undefined}>
            <Text
              style={{
                color: colors.danger,
                fontSize: typography.bodyMedium.fontSize - 3,
              }}
            >
              {() => scanError() ?? ""}
            </Text>
          </If>
          <Text
            style={{
              fontSize: typography.bodyMedium.fontSize - 3,
              color: colors.mutedInk,
            }}
          >
            相机直扫需移动端平台能力（R3），暂不可用——请用上方的图片识别。
          </Text>
          <PairModeRow
            icon="edit"
            title="我输入对方的码"
            subtitle="输入或粘贴对方设备的配对码/配对信息"
            onPress={openEnterCode}
          />
          <View style={{ flexDirection: "row", justifyContent: "flex-end" }}>
            <View
              onPress={closePairSheet}
              role="button"
              accessibilityLabel="取消"
              style={{
                minHeight: layout.mobileTouchTarget,
                paddingHorizontal: spacing.lg,
                alignItems: "center",
                justifyContent: "center",
                borderRadius: radii.md,
                borderWidth: 1,
                borderColor: colors.border,
              }}
            >
              <Text style={{ color: colors.mutedInk, fontSize: typography.bodyMedium.fontSize }}>
                取消
              </Text>
            </View>
          </View>
        </Panel>
      </View>
    </Dialog>
  );
}

/** 「我显示配对码」弹窗（对照 Dart _PairingAcceptDialog）：
 *  6 位码大字 + 倒计时（10 分钟有效）+ 等待/确认状态 + 重新生成 +
 *  「保存二维码图片」（QR 任务：cm1. 凭证 → PNG → 系统保存框，保存路径
 *  用 mutedInk 提示）。屏幕内不画 QR（NSH 无二维码绘制组件），二维码以
 *  图片文件形式交付给对方识别。 */
export function PairShowSheet(): JSX.Element {
  const expiryText = () => {
    if (pairDeadlineMs() === undefined) return "";
    return formatCountdown(pairRemainingMs());
  };
  return (
    <Dialog open={pairSheet() === "show"}>
      <View
        style={{
          flex: 1,
          alignItems: "center",
          justifyContent: "center",
          padding: spacing.xl,
          backgroundColor: colors.paper,
        }}
      >
        <Panel>
          <Text
            style={{
              fontSize: typography.titleMedium.fontSize,
              fontWeight: "600",
              color: colors.ink,
            }}
          >
            配对信息
          </Text>
          {() => {
            if (pairCode() === undefined && pairError() === undefined) {
              return (
                <Text style={{ color: colors.mutedInk, fontSize: typography.bodyMedium.fontSize }}>
                  正在生成配对信息…
                </Text>
              );
            }
            return (
              <View style={{ gap: spacing.sm }}>
                <Text style={{ color: colors.mutedInk, fontSize: typography.bodyMedium.fontSize }}>
                  在对方设备「添加设备」中输入以下 6 位码（移动端也可扫码）：
                </Text>
                <Text
                  style={{
                    fontSize: typography.headlineSmall.fontSize,
                    lineHeight: typography.headlineSmall.lineHeight,
                    fontWeight: "600",
                    color: colors.accent,
                    letterSpacing: 4,
                    textAlign: "center",
                  }}
                >
                  {() => pairCode() ?? ""}
                </Text>
                <View
                  style={{
                    flexDirection: "row",
                    alignItems: "center",
                    gap: spacing.md,
                  }}
                >
                  <Text
                    style={{
                      fontSize: typography.bodyMedium.fontSize,
                      color:
                        pairRemainingMs() <= 0 ? colors.danger : colors.mutedInk,
                    }}
                  >
                    {() => expiryText()}
                  </Text>
                  <View style={{ flex: 1 }} />
                  <View
                    onPress={() => void regeneratePairCode()}
                    role="button"
                    accessibilityLabel="重新生成配对码"
                    style={{
                      minHeight: layout.mobileTouchTarget,
                      paddingHorizontal: spacing.md,
                      alignItems: "center",
                      justifyContent: "center",
                      borderRadius: radii.md,
                      borderWidth: 1,
                      borderColor: colors.border,
                    }}
                  >
                    <Text
                      style={{
                        fontSize: typography.bodyMedium.fontSize - 3,
                        color: colors.accent,
                        fontWeight: "600",
                      }}
                    >
                      重新生成
                    </Text>
                  </View>
                </View>
                {/* 保存二维码图片（QR 任务）：cm1. 凭证渲染成 PNG 写用户自选
                    路径；成功路径提示走 mutedInk，错误仍走 pairError 红字。 */}
                <View
                  onPress={() => void savePairingQrImage()}
                  role="button"
                  accessibilityLabel="保存二维码图片"
                  style={{
                    minHeight: layout.mobileTouchTarget,
                    paddingHorizontal: spacing.md,
                    alignItems: "center",
                    justifyContent: "center",
                    borderRadius: radii.md,
                    borderWidth: 1,
                    borderColor: colors.border,
                  }}
                >
                  <Text
                    style={{
                      fontSize: typography.bodyMedium.fontSize - 3,
                      color: colors.accent,
                      fontWeight: "600",
                    }}
                  >
                    保存二维码图片
                  </Text>
                </View>
                <If when={qrSavedPath() !== undefined}>
                  <Text
                    style={{
                      fontSize: typography.bodyMedium.fontSize - 3,
                      color: colors.mutedInk,
                    }}
                  >
                    {() => `已保存：${qrSavedPath() ?? ""}`}
                  </Text>
                </If>
                <Text
                  style={{
                    fontSize: typography.bodyMedium.fontSize - 3,
                    color: colors.mutedInk,
                  }}
                >
                  保存的图片可用对方设备「识别二维码图片」打开完成配对；相机直扫需移动端平台能力（R3）。
                </Text>
              </View>
            );
          }}
          <If when={pairError() !== undefined}>
            <Text
              style={{
                color: colors.danger,
                fontSize: typography.bodyMedium.fontSize - 3,
              }}
            >
              {() => pairError() ?? ""}
            </Text>
          </If>
          <If when={pairError() === undefined && pairCode() !== undefined}>
            <Text
              style={{
                color: colors.mutedInk,
                fontSize: typography.bodyMedium.fontSize - 3,
              }}
            >
              等待对方确认后自动完成配对…
            </Text>
          </If>
          <View style={{ flexDirection: "row", justifyContent: "flex-end" }}>
            <View
              onPress={closePairSheet}
              role="button"
              accessibilityLabel="关闭"
              style={{
                minHeight: layout.mobileTouchTarget,
                paddingHorizontal: spacing.lg,
                alignItems: "center",
                justifyContent: "center",
                borderRadius: radii.md,
                borderWidth: 1,
                borderColor: colors.border,
              }}
            >
              <Text style={{ color: colors.mutedInk, fontSize: typography.bodyMedium.fontSize }}>
                关闭
              </Text>
            </View>
          </View>
        </Panel>
      </View>
    </Dialog>
  );
}

/** 「我输入对方的码」弹窗（对照 Dart _enterPeerCode）：单输入框 + 提交错误
 *  内联 + 提交中 busy。cm1 开头走凭证直连，6 位走 mDNS 发现。 */
export function PairEnterSheet(): JSX.Element {
  return (
    <Dialog open={pairSheet() === "enter"}>
      <View
        style={{
          flex: 1,
          alignItems: "center",
          justifyContent: "center",
          padding: spacing.xl,
          backgroundColor: colors.paper,
        }}
      >
        <Panel>
          <Text
            style={{
              fontSize: typography.titleMedium.fontSize,
              fontWeight: "600",
              color: colors.ink,
            }}
          >
            输入对方配对信息
          </Text>
          <View
            style={{
              borderWidth: 1,
              borderColor: colors.border,
              borderRadius: radii.md,
              backgroundColor: colors.surfaceRaised,
            }}
          >
            <Input
              value={enterInput()}
              onChange={({ value }) => enterInput.set(value)}
              onSubmit={() => void submitPeerCode()}
              placeholder="输入 6 位配对码，或粘贴以 cm1 开头的配对信息"
              accessibilityLabel="配对码或配对信息"
              style={{
                minHeight: layout.mobileTouchTarget,
                fontSize: typography.bodyMedium.fontSize,
                color: colors.ink,
                paddingHorizontal: spacing.md,
              }}
            />
          </View>
          <If when={enterBusy()}>
            <Text style={{ color: colors.mutedInk, fontSize: typography.bodyMedium.fontSize }}>
              正在连接…
            </Text>
          </If>
          <If when={enterError() !== undefined}>
            <Text
              style={{
                color: colors.danger,
                fontSize: typography.bodyMedium.fontSize - 3,
              }}
            >
              {() => enterError() ?? ""}
            </Text>
          </If>
          <View style={{ flexDirection: "row", justifyContent: "flex-end", gap: spacing.sm }}>
            <View
              onPress={closePairSheet}
              role="button"
              accessibilityLabel="取消"
              style={{
                minHeight: layout.mobileTouchTarget,
                paddingHorizontal: spacing.lg,
                alignItems: "center",
                justifyContent: "center",
                borderRadius: radii.md,
                borderWidth: 1,
                borderColor: colors.border,
              }}
            >
              <Text style={{ color: colors.mutedInk, fontSize: typography.bodyMedium.fontSize }}>
                取消
              </Text>
            </View>
            <View
              onPress={enterBusy() ? undefined : () => void submitPeerCode()}
              role="button"
              accessibilityLabel="确认配对"
              accessibilityState={{ disabled: enterBusy() }}
              style={{
                minHeight: layout.mobileTouchTarget,
                paddingHorizontal: spacing.lg,
                alignItems: "center",
                justifyContent: "center",
                borderRadius: radii.md,
                backgroundColor: colors.accent,
                opacity: enterBusy() ? 0.4 : 1,
              }}
            >
              <Text
                style={{
                  color: colors.surfaceRaised,
                  fontSize: typography.bodyMedium.fontSize,
                  fontWeight: "600",
                }}
              >
                确认配对
              </Text>
            </View>
          </View>
        </Panel>
      </View>
    </Dialog>
  );
}
