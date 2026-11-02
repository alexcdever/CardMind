// editor_text.ts 纯函数单测（node:test；不依赖 DOM / NSH 引擎）。
//
// 覆盖 06 §5.3 要求：`linkPrefixFromContext`、`matchTags`、行首表 offset 换算、
// `[[` 候选替换 range 计算；另含选区上下文、CSV 标签、onChange 取值兼容。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  AUTOSAVE_DEBOUNCE_MS,
  LOAD_TIMEOUT_MS,
  TEXT_BEFORE_CHARS,
  completionOffsets,
  lineStartOffsets,
  linkPrefixFromContext,
  matchTags,
  normalizeNewlines,
  offsetToPosition,
  positionToOffset,
  selectionContext,
  tagsFromCsv,
  textOfChange,
  wikilinkText,
} from './editor_text.ts';

describe('linkPrefixFromContext（[[ 触发探测）', () => {
  it('刚输入 [[ → 空前缀', () => {
    assert.equal(linkPrefixFromContext('[[',), '');
  });

  it('[[前缀 → 前缀串', () => {
    assert.equal(linkPrefixFromContext('前文 [[会议记'), '会议记');
  });

  it('已闭合 [[x]] → null（不触发）', () => {
    assert.equal(linkPrefixFromContext('[[会议记录]]'), null);
  });

  it('带 | 的未闭合 [[id|alias → null（不触发）', () => {
    assert.equal(linkPrefixFromContext('[[会议|记录'), null);
  });

  it('含换行前缀 → null（跨行不算）', () => {
    assert.equal(linkPrefixFromContext('[[会议\n记录'), null);
  });

  it('普通文本 → null', () => {
    assert.equal(linkPrefixFromContext('普通文本'), null);
  });

  it('只看最近一段：更早的 [[x]] 不影响后面的 [[y', () => {
    assert.equal(linkPrefixFromContext('[[旧]] 然后 [[新'), '新');
  });
});

describe('matchTags（标签高亮命中）', () => {
  const tags = ['工作', '会议记录', 'Work'];

  it('[[prefix 命中标签前缀（大小写不敏感）', () => {
    assert.deepEqual(matchTags(tags, { textBefore: '[[工' }), ['工作']);
    assert.deepEqual(matchTags(tags, { textBefore: '[[wo' }), ['Work']);
  });

  it('[[ 空前缀命中全部标签', () => {
    assert.deepEqual(matchTags(tags, { textBefore: '[[' }), tags);
  });

  it('选中文本完整等于标签才命中', () => {
    assert.deepEqual(matchTags(tags, { text: ' 会议记录 ', textBefore: '' }), ['会议记录']);
    assert.deepEqual(matchTags(tags, { text: '会议', textBefore: '' }), []);
  });

  it('无选区无前缀 → 不高亮', () => {
    assert.deepEqual(matchTags(tags, {}), []);
  });
});

describe('行首表与 offset 换算（UTF-16）', () => {
  const text = '第一行\nab\n🙂x\n';

  it('lineStartOffsets 每行起始 offset', () => {
    assert.deepEqual(lineStartOffsets(text), [0, 4, 7, 11]);
  });

  it('positionToOffset 行首/行内', () => {
    assert.equal(positionToOffset(text, { line: 0, column: 0 }), 0);
    assert.equal(positionToOffset(text, { line: 1, column: 2 }), 6);
    assert.equal(positionToOffset(text, { line: 2, column: 2 }), 9); // emoji 占 2 个 UTF-16
  });

  it('positionToOffset 越界 line/column 收敛到文本内', () => {
    assert.equal(positionToOffset(text, { line: 99, column: 0 }), text.length);
    assert.equal(positionToOffset(text, { line: 0, column: 99 }), 3);
    assert.equal(positionToOffset(text, { line: -1, column: -1 }), 0);
  });

  it('offsetToPosition 反解（含行尾）', () => {
    assert.deepEqual(offsetToPosition(text, 0), { line: 0, column: 0 });
    assert.deepEqual(offsetToPosition(text, 6), { line: 1, column: 2 });
    assert.deepEqual(offsetToPosition(text, 9), { line: 2, column: 2 });
    assert.deepEqual(offsetToPosition(text, text.length), { line: 3, column: 0 });
  });

  it('offsetToPosition 越界收敛', () => {
    assert.deepEqual(offsetToPosition(text, 999), { line: 3, column: 0 });
    assert.deepEqual(offsetToPosition(text, -5), { line: 0, column: 0 });
  });

  it('positionToOffset(offsetToPosition(x)) 往返一致', () => {
    for (let offset = 0; offset <= text.length; offset += 1) {
      assert.equal(positionToOffset(text, offsetToPosition(text, offset)), offset);
    }
  });
});

describe('completionOffsets（[[ 替换范围）', () => {
  it('空前缀替换已输入的两个 [', () => {
    assert.deepEqual(completionOffsets(10, ''), { start: 8, end: 10 });
  });

  it('带前缀时连前缀一起替换', () => {
    assert.deepEqual(completionOffsets(10, '会记'), { start: 6, end: 10 });
  });

  it('offset 小于 2+prefix 时收敛到 0', () => {
    assert.deepEqual(completionOffsets(1, 'abc'), { start: 0, end: 1 });
    assert.deepEqual(completionOffsets(0, ''), { start: 0, end: 0 });
  });
});

describe('wikilinkText / 选区上下文', () => {
  it('候选拼成 [[id|title]] + 尾随空格', () => {
    assert.equal(wikilinkText({ id: 'note-2', title: '会议记录' }), '[[note-2|会议记录]] ');
  });

  it('折叠光标：selected 为空，textBefore 取光标前 40 字符', () => {
    const text = `${'a'.repeat(100)}光标`;
    const ctx = selectionContext(text, { line: 0, column: 102 }, { line: 0, column: 102 });
    assert.equal(ctx.offset, 102);
    assert.equal(ctx.selected, '');
    assert.equal(ctx.textBefore, text.slice(102 - TEXT_BEFORE_CHARS, 102));
    assert.equal(ctx.textBefore.length, TEXT_BEFORE_CHARS);
  });

  it('范围选区：selected 为选中的文本，textBefore 按 head 取', () => {
    const text = '[[会议记\n下一行';
    const ctx = selectionContext(text, { line: 0, column: 2 }, { line: 0, column: 5 });
    assert.equal(ctx.selected, '会议记');
    assert.equal(ctx.textBefore, text.slice(0, 5));
  });
});

describe('tagsFromCsv / textOfChange', () => {
  it('逗号分隔、trim、丢空项', () => {
    assert.deepEqual(tagsFromCsv('工作, 会议记录 ,, '), ['工作', '会议记录']);
    assert.deepEqual(tagsFromCsv(''), []);
    assert.deepEqual(tagsFromCsv(undefined), []);
  });

  it('onChange 取值：字符串原样', () => {
    assert.equal(textOfChange('abc'), 'abc');
  });

  it('onChange 取值：事件对象兼容 { value }', () => {
    assert.equal(textOfChange({ value: 'abc' }), 'abc');
  });

  it('onChange 取值：非法值 → 空串（不抛）', () => {
    assert.equal(textOfChange(undefined), '');
    assert.equal(textOfChange(null), '');
    assert.equal(textOfChange(42), '');
    assert.equal(textOfChange({ value: 42 }), '');
  });
});

describe('时间常量', () => {
  it('自动保存 700ms、加载超时有上限、前缀窗口 40', () => {
    assert.equal(AUTOSAVE_DEBOUNCE_MS, 700);
    assert.ok(LOAD_TIMEOUT_MS > 0 && LOAD_TIMEOUT_MS <= 30_000);
    assert.equal(TEXT_BEFORE_CHARS, 40);
  });
});

describe('normalizeNewlines（唯一允许的换行归一）', () => {
  it('CRLF → LF', () => {
    assert.equal(normalizeNewlines('a\r\nb\r\n'), 'a\nb\n');
  });

  it('裸 CR → LF', () => {
    assert.equal(normalizeNewlines('a\rb'), 'a\nb');
  });

  it('LF 原样、逐字节不动（含 [[id|alias]]、空行、代码块、中文）', () => {
    const fixture =
      '# 标题\n\n[[note-2|别名]] 与 [[note-3]]\n\n行一\n行二\n\n\n\n```\nconst x = 1;\n```\n';
    assert.equal(normalizeNewlines(fixture), fixture);
  });

  it('不动反斜杠/方括号/尾随空格（不再有旧 Tiptap 归一化）', () => {
    assert.equal(normalizeNewlines('\\[x\\]  \n'), '\\[x\\]  \n');
  });
});
