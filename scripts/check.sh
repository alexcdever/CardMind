#!/usr/bin/env bash
# CardMind 本地质量检查（本地 CI）
# 用法: scripts/check.sh
# 任一检查失败即退出非零；全部通过输出 ✅
# 跳过方式: SKIP_LOCAL_CHECK=1 时 pre-commit 会跳过本脚本
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1  # 项目根目录
failures=0

step() { echo "==> [$1/5] $2"; }

step 1 "cargo fmt --check"
if (cd rust-backend && cargo fmt --check); then
  echo "    ✅ fmt"
else
  echo "    ❌ fmt 未通过"; failures=1
fi

step 2 "cargo clippy --all-targets --all-features -- -D warnings"
if (cd rust-backend && cargo clippy --all-targets --all-features -- -D warnings); then
  echo "    ✅ clippy"
else
  echo "    ❌ clippy 未通过"; failures=1
fi

step 3 "cargo test --all-features"
if (cd rust-backend && cargo test --all-features); then
  echo "    ✅ rust 测试"
else
  echo "    ❌ rust 测试未通过"; failures=1
fi

step 4 "flutter analyze"
if flutter analyze; then
  echo "    ✅ analyze"
else
  echo "    ❌ analyze 未通过"; failures=1
fi

step 5 "flutter test"
if flutter test; then
  echo "    ✅ flutter 测试"
else
  echo "    ❌ flutter 测试未通过"; failures=1
fi

if [ "$failures" -ne 0 ]; then
  echo ""
  echo "❌ 本地检查未通过，见上方错误。修复后重新提交。"
  echo "   （确认没问题想跳过: SKIP_LOCAL_CHECK=1 git commit）"
  exit 1
fi

echo ""
echo "✅ 本地检查全部通过 (fmt + clippy + rust test + analyze + flutter test)"
