// #[module] 闭环验收测试（task.md 标准 3）：读文件断言，不跑构建。
// ①App.tsx 源码含 `await BackendStore.dataDir(`（证明 TSX 侧有 await，不是裸调用；
//   P4 收敛后启动契约改为 dataDir → createNoteStore → syncDeviceId → startReceiver，
//   不再有 Phase 1 的 `Backend.deviceId()` 演示调用）；
// ②`.nsh/types/app/native.d.ts`（nsh build 生成）含 `deviceId` 导出。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));

describe('#[module] 最小闭环', () => {
  it('App.tsx 含 await BackendStore.dataDir(', () => {
    const tsx = readFileSync(path.join(here, 'App.tsx'), 'utf8');
    assert.ok(
      tsx.includes('await BackendStore.dataDir('),
      'App.tsx 应含 `await BackendStore.dataDir(`',
    );
  });

  it('.nsh/types/app/native.d.ts 含 deviceId 导出', () => {
    const dts = path.join(here, '.nsh', 'types', 'app', 'native.d.ts');
    assert.ok(existsSync(dts), `${dts} 不存在，需先 nsh build`);
    assert.match(readFileSync(dts, 'utf8'), /deviceId/);
  });
});
