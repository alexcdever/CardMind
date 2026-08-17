import '../src/rust/sync.dart';

/// 配对凭证用户错误（稳定 kind + 中文文案；UI 直接展示 [message]）。
///
/// Rust 侧 [`PairingCredentialError`] 携带稳定 kind（FRB codegen 后为
/// [`PairingCredentialErrorKind`]），仓库层在此把它映射为带中文文案的
/// 用户错误——UI 不得接触裸异常，也不得做字符串匹配。
class PairingCredentialException implements Exception {
  final PairingCredentialErrorKind kind;
  final String message;

  const PairingCredentialException({required this.kind, required this.message});

  /// 从 FRB 抛出的 Rust 错误转换为用户错误（kind 保留，文案中文化）。
  factory PairingCredentialException.fromRust(PairingCredentialError error) {
    return PairingCredentialException(
      kind: error.kind,
      message: messageFor(error.kind),
    );
  }

  /// kind → 中文文案（用户可见）。
  static String messageFor(PairingCredentialErrorKind kind) {
    switch (kind) {
      case PairingCredentialErrorKind.invalidFormat:
        return '配对信息格式无效，请确认复制的是完整的配对码或配对信息';
      case PairingCredentialErrorKind.invalidSignature:
        return '配对信息签名无效，可能已被篡改，请让对方重新生成';
      case PairingCredentialErrorKind.expired:
        return '配对信息已过期，请让对方重新生成';
      case PairingCredentialErrorKind.usedOrReplaced:
        return '配对信息已使用或已被替代，请让对方重新生成';
      case PairingCredentialErrorKind.unreachable:
        return '无法连接到对方设备，请确认两台设备网络可达后重试';
      case PairingCredentialErrorKind.internal:
        return '配对失败，请稍后重试';
    }
  }

  @override
  String toString() => message;
}
