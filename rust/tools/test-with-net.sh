#!/bin/bash
# 运行 Rust 测试时自动允许网络权限
#
# macOS 防火墙拦截未签名的二进制，每次编译后 hash 都变，所以每次都弹窗。
# 这个脚本在编译后用 ad-hoc 签名 + com.apple.security.network.server 授权，
# 让防火墙知道这些测试二进制应该被允许接受传入连接。
#
# 用法：
#   cd rust/
#   bash tools/test-with-net.sh [cargo test args...]
#
# 示例：
#   bash tools/test-with-net.sh --test unit pool_network_sync
#
# 先跑一次观察是否还有弹窗，如果还有，点击"允许"后永久生效。

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENTITLEMENTS="$SCRIPT_DIR/test.entitlements"

echo "🔨 Compiling tests..."
cargo test --no-run "$@"

echo ""
echo "🔏 Signing test binaries with network entitlement..."
for pattern in unit-* contract-* integration-*; do
  for bin in target/debug/$pattern; do
    if [ -f "$bin" ] && [ -x "$bin" ]; then
      echo "  Signing: $(basename $bin)"
      codesign --force --sign - --timestamp=none --entitlements "$ENTITLEMENTS" "$bin" 2>/dev/null || true
    fi
  done
done

echo ""
echo "🚀 Running tests..."
cargo test "$@"
