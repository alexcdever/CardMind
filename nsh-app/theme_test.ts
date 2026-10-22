// 令牌基线测试：lib/ 已随 Flutter 链整删，theme.ts 成为令牌唯一来源。
// 本测试把迁移前与 Dart `cardmind_theme.dart` 对齐过的最终值固化为字面量
// 基线（值取自 HEAD:lib/ui/design_system/cardmind_theme.dart，2026-10 快照），
// 防无意漂移；有意改令牌时同步改这里的基线即视为正式变更。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
  colors,
  spacing,
  radii,
  layout,
  typography,
  fontFamilyFallback,
} from './theme.ts';

const here = path.dirname(fileURLToPath(import.meta.url));

describe('colors（10 个，迁移自 CardMindTokens.light）', () => {
  const expected = {
    paper: '#F9F9F8',
    ink: '#1A1A1A',
    mutedInk: '#666666',
    border: '#E2E2E0',
    accent: '#4A707A',
    accentHover: '#3E646E',
    surfaceLow: '#F3F4F3',
    surfaceRaised: '#FFFFFF',
    danger: '#A34F4F',
    stale: '#B08D2E',
  } as const;

  it('恰好 10 个，无多无少', () => {
    assert.deepEqual(Object.keys(colors).sort(), Object.keys(expected).sort());
  });

  for (const [name, value] of Object.entries(expected)) {
    it(`colors.${name} === ${value}`, () => {
      assert.equal(colors[name as keyof typeof colors], value);
    });
  }
});

describe('spacing（6 档，迁移自 CardMindSpacing）', () => {
  const expected = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32 } as const;

  it('恰好 6 档', () => {
    assert.deepEqual(Object.keys(spacing).sort(), Object.keys(expected).sort());
  });

  for (const [name, value] of Object.entries(expected)) {
    it(`spacing.${name} === ${value}`, () => {
      assert.equal(spacing[name as keyof typeof spacing], value);
    });
  }
});

describe('radii（4 档，迁移自 CardMindRadii）', () => {
  const expected = { sm: 2, md: 4, lg: 6, xl: 8 } as const;

  it('恰好 4 档', () => {
    assert.deepEqual(Object.keys(radii).sort(), Object.keys(expected).sort());
  });

  for (const [name, value] of Object.entries(expected)) {
    it(`radii.${name} === ${value}`, () => {
      assert.equal(radii[name as keyof typeof radii], value);
    });
  }
});

describe('layout（5 个，迁移自 CardMindLayout）', () => {
  const expected = {
    desktopBreakpoint: 960,
    sidebarWidth: 240,
    listWidth: 360,
    editorMaxWidth: 768,
    mobileTouchTarget: 48,
  } as const;

  it('恰好 5 个', () => {
    assert.deepEqual(Object.keys(layout).sort(), Object.keys(expected).sort());
  });

  for (const [name, value] of Object.entries(expected)) {
    it(`layout.${name} === ${value}`, () => {
      assert.equal(layout[name as keyof typeof layout], value);
    });
  }
});

describe('typography（4 档，迁移自 CardMindTheme.light textTheme）', () => {
  const expected = {
    headlineSmall: { fontSize: 24, lineHeight: 32, fontWeight: 600 },
    titleMedium: { fontSize: 18, lineHeight: 24, fontWeight: 600 },
    bodyMedium: { fontSize: 15, lineHeight: 22 },
    labelLarge: { fontSize: 14, fontWeight: 600 },
  } as const;

  it('恰好 4 档', () => {
    assert.deepEqual(
      Object.keys(typography).sort(),
      Object.keys(expected).sort(),
    );
  });

  for (const [slot, token] of Object.entries(expected)) {
    it(`typography.${slot} 字号/行高/字重对齐`, () => {
      const ts = typography[slot as keyof typeof typography];
      assert.equal(ts.fontSize, token.fontSize, `${slot}.fontSize 漂移`);
      if ('lineHeight' in token) {
        assert.equal(ts.lineHeight, token.lineHeight, `${slot}.lineHeight 漂移`);
      } else {
        assert.equal(
          ts.lineHeight,
          undefined,
          `${slot}.lineHeight 应未设（迁移前 Dart 源无 height）`,
        );
      }
      if ('fontWeight' in token) {
        assert.equal(ts.fontWeight, token.fontWeight, `${slot}.fontWeight 漂移`);
      } else {
        assert.equal(
          ts.fontWeight,
          undefined,
          `${slot}.fontWeight 应未设（迁移前 Dart 源默认字重）`,
        );
      }
    });
  }
});

describe('fontFamilyFallback', () => {
  it('包含 Source Han Sans CN（迁移前与 Dart fontFamilyFallback 一致）', () => {
    assert.deepEqual([...fontFamilyFallback].sort(), ['Source Han Sans CN']);
    assert.ok(fontFamilyFallback.includes('Source Han Sans CN'));
  });
});

describe('验收 7：令牌模块自身不含游离数字字面量', () => {
  it('theme.ts 导出值全部来自令牌对象（无顶层散置数字导出）', () => {
    const themeSrc = readFileSync(path.resolve(here, 'theme.ts'), 'utf8');
    // 允许令牌定义对象内的数字；不允许 export const X = <number> 形式
    const bare = themeSrc.match(
      /export\s+const\s+\w+\s*=\s*\d+(\.\d+)?\s*;/g,
    );
    assert.equal(
      bare,
      null,
      `theme.ts 存在裸数字导出：${bare?.join(', ')}`,
    );
  });
});
