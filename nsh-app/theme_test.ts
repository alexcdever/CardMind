// 令牌一致性测试：读 Flutter 侧 Dart 源文本，用正则抽值与 theme.ts 逐个比对。
// Dart 源改了而 TS 侧没跟上时，本测试应变红。
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
const dartSource = readFileSync(
  path.resolve(here, '..', 'lib', 'ui', 'design_system', 'cardmind_theme.dart'),
  'utf8',
);

/** 从 Dart 源抽 `name: Color(0xAARRGGBB)` 形式的颜色，返回 #RRGGBB。 */
function dartColor(name: string): string {
  const re = new RegExp(
    `${name}\\s*:\\s*Color\\(0x([0-9A-Fa-f]{8})\\)`,
  );
  const m = dartSource.match(re);
  assert.ok(m, `Dart 源中未找到颜色令牌 ${name}`);
  return `#${m[1].slice(2).toUpperCase()}`;
}

/** 从 Dart 源抽 `static const double name = N;` 形式的数值。 */
function dartConst(name: string): number {
  const re = new RegExp(`static\\s+const\\s+double\\s+${name}\\s*=\\s*([0-9.]+)`);
  const m = dartSource.match(re);
  assert.ok(m, `Dart 源中未找到数值常量 ${name}`);
  return Number(m[1]);
}

/** 抽出 `slot: ...copyWith(fontSize: F, height: A/B?, fontWeight: W?)` 代码块。 */
function dartTextStyleBlock(slot: string): string {
  const re = new RegExp(`${slot}:[\\s\\S]*?copyWith\\(([\\s\\S]*?)\\)`);
  const m = dartSource.match(re);
  assert.ok(m, `Dart 源中未找到排版档位 ${slot}`);
  return m[1];
}

function dartFontSize(block: string): number {
  const m = block.match(/fontSize:\s*([0-9.]+)/);
  assert.ok(m, '块内未找到 fontSize');
  return Number(m[1]);
}

/** height 以 `a / b` 写法存在时返回行高像素值 a；未设返回 null。 */
function dartLineHeight(block: string): number | null {
  const m = block.match(/height:\s*([0-9.]+)\s*\/\s*([0-9.]+)/);
  return m ? Number(m[1]) : null;
}

function dartFontWeight(block: string): number | null {
  const m = block.match(/fontWeight:\s*FontWeight\.w(\d+)/);
  return m ? Number(m[1]) : null;
}

describe('colors（10 个，对齐 CardMindTokens.light）', () => {
  const names = [
    'paper',
    'ink',
    'mutedInk',
    'border',
    'accent',
    'accentHover',
    'surfaceLow',
    'surfaceRaised',
    'danger',
    'stale',
  ] as const;

  it('恰好 10 个，无多无少', () => {
    assert.deepEqual(Object.keys(colors).sort(), [...names].sort());
  });

  for (const name of names) {
    it(`colors.${name} === Dart ${name}`, () => {
      assert.equal(
        colors[name],
        dartColor(name),
        `颜色令牌 ${name} 与 Dart 源不一致`,
      );
    });
  }
});

describe('spacing（6 档，对齐 CardMindSpacing）', () => {
  const names = ['xs', 'sm', 'md', 'lg', 'xl', 'xxl'] as const;

  it('恰好 6 档', () => {
    assert.deepEqual(Object.keys(spacing).sort(), [...names].sort());
  });

  for (const name of names) {
    it(`spacing.${name} === Dart ${name}`, () => {
      assert.equal(
        spacing[name],
        dartConst(name),
        `间距档位 ${name} 与 Dart 源不一致`,
      );
    });
  }
});

describe('radii（4 档，对齐 CardMindRadii）', () => {
  const names = ['sm', 'md', 'lg', 'xl'] as const;

  it('恰好 4 档', () => {
    assert.deepEqual(Object.keys(radii).sort(), [...names].sort());
  });

  for (const name of names) {
    it(`radii.${name} === Dart ${name}`, () => {
      // CardMindSpacing 与 CardMindRadii 共用 sm/md/lg/xl 名字，
      // 这里按各自 class 块限定范围抽取，避免串档。
      const block = dartSource.match(
        /class\s+CardMindRadii\s*\{([\s\S]*?)\}/,
      );
      assert.ok(block, '未找到 CardMindRadii 类');
      const m = block[1].match(
        new RegExp(`double\\s+${name}\\s*=\\s*([0-9.]+)`),
      );
      assert.ok(m, `CardMindRadii 中未找到 ${name}`);
      assert.equal(
        radii[name],
        Number(m[1]),
        `圆角档位 ${name} 与 Dart 源不一致`,
      );
    });
  }
});

describe('layout（5 个，对齐 CardMindLayout）', () => {
  const names = [
    'desktopBreakpoint',
    'sidebarWidth',
    'listWidth',
    'editorMaxWidth',
    'mobileTouchTarget',
  ] as const;

  it('恰好 5 个', () => {
    assert.deepEqual(Object.keys(layout).sort(), [...names].sort());
  });

  for (const name of names) {
    it(`layout.${name} === Dart ${name}`, () => {
      assert.equal(
        layout[name],
        dartConst(name),
        `布局常量 ${name} 与 Dart 源不一致`,
      );
    });
  }
});

describe('typography（4 档，对齐 CardMindTheme.light textTheme）', () => {
  const cases = [
    { slot: 'headlineSmall', hasHeight: true },
    { slot: 'titleMedium', hasHeight: true },
    { slot: 'bodyMedium', hasHeight: true },
    { slot: 'labelLarge', hasHeight: false },
  ] as const;

  it('恰好 4 档', () => {
    assert.deepEqual(
      Object.keys(typography).sort(),
      cases.map((c) => c.slot).sort(),
    );
  });

  for (const { slot, hasHeight } of cases) {
    it(`typography.${slot} 字号/行高/字重对齐`, () => {
      const block = dartTextStyleBlock(slot);
      const ts = typography[slot];

      assert.equal(
        ts.fontSize,
        dartFontSize(block),
        `${slot}.fontSize 与 Dart 源不一致`,
      );

      const dartLh = dartLineHeight(block);
      if (hasHeight) {
        assert.ok(dartLh !== null, `Dart 源 ${slot} 应有 height`);
        assert.equal(
          ts.lineHeight,
          dartLh,
          `${slot}.lineHeight 与 Dart 源（height 分子）不一致`,
        );
        // lineHeight / fontSize 应等于 Dart 的 height 比值
        const ratio = dartSource.match(
          new RegExp(`${slot}:[\\s\\S]*?height:\\s*([0-9.]+)\\s*\\/\\s*([0-9.]+)`),
        );
        assert.ok(ratio, `${slot} 未找到 height 比值`);
        assert.ok(
          Math.abs(ts.lineHeight! / ts.fontSize - Number(ratio[1]) / Number(ratio[2])) < 1e-9,
          `${slot} lineHeight/fontSize 比值不等于 Dart height 比值`,
        );
      } else {
        assert.equal(
          ts.lineHeight,
          undefined,
          `${slot}.lineHeight 应未设（Dart 源无 height）`,
        );
        assert.equal(dartLh, null, `Dart 源 ${slot} 不应有 height`);
      }

      const dartWeight = dartFontWeight(block);
      assert.equal(
        ts.fontWeight,
        dartWeight === null ? undefined : dartWeight,
        `${slot}.fontWeight 与 Dart 源不一致`,
      );
    });
  }
});

describe('fontFamilyFallback', () => {
  it('包含 Source Han Sans CN，与 Dart fontFamilyFallback 一致', () => {
    const m = dartSource.match(
      /fontFamilyFallback:\s*const\s*\[([^\]]*)\]/,
    );
    assert.ok(m, 'Dart 源未找到 fontFamilyFallback');
    const dartFonts = [...m[1].matchAll(/'([^']+)'/g)].map((x) => x[1]);
    assert.deepEqual(
      [...fontFamilyFallback].sort(),
      dartFonts.sort(),
      'fontFamilyFallback 与 Dart 源不一致',
    );
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
