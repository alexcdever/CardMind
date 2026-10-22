// 施工方案 2.5 验收测试（task.md 标准 4/5/6/7）：读文件断言，不跑构建。
//
// 断言面：
//  ① devices_page.tsx 存在；
//  ② 配对流程真接线：beginPairingAccept* / acceptPairingRequest* /
//    confirmPairing / beginPairingConnect*（含凭证路径 beginPairingConnectWithCredential
//    + parsePairingCredential 验证 + beginPairingCredential* 生成展示码）；
//  ③ 设备管理真接线：listPairedDevices / removePairedDevice /
//    checkDeviceConnectivity；解绑走 CardMindConfirmDialog（danger）；
//  ④ 发现真接线：discoverPeers / syncDiscoverPeers；
//  ⑤ R3 诚实标注：扫码入口存在但 disabled + 说明文案；
//  ⑥ 倒计时：setInterval + 清理（clearInterval/cleanup），10 分钟语义；
//  ⑦ 空态 CardMindEmptyState；令牌纪律（无裸色值/裸 48）；无 React hooks；
//  ⑧ App.tsx 接入 devices_page，Phase 1 后端调用仍在。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (name: string) => readFileSync(path.join(here, name), 'utf8');

const DEVICES = 'devices_page.tsx';
const APP = 'App.tsx';

const devicesPath = path.join(here, DEVICES);
const devices = existsSync(devicesPath) ? read(DEVICES) : '';
const app = read(APP);

/** 去掉行注释/块注释后的代码（查裸数字/裸色时用）。 */
const codeOnly = (src: string) =>
  src.replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '');

describe('2.5 devices_page.tsx — 存在与配对流程', () => {
  it('devices_page.tsx 存在', () => {
    assert.ok(existsSync(devicesPath), 'nsh-app/devices_page.tsx 不存在');
  });

  it('生成配对码（beginPairingAcceptWithAdvertising，任务 J 组合 API）', () => {
    assert.match(
      devices,
      /beginPairingAccept\w*\s*\(/,
      'devices_page.tsx 应调用 BackendPairing.beginPairingAccept*（生成配对码）',
    );
  });

  it('显示方会话窗口 10 分钟（倒计时语义）', () => {
    // 配对码有效期对齐 Rust PAIRING_CODE_TTL_MINUTES=10：倒计时信号 +
    // setInterval 驱动 + 组件卸载清理。
    const code = codeOnly(devices);
    assert.match(
      code,
      /10\s*\*\s*60|600_?000|600000|minutes?:\s*10|10\s*分钟/,
      '配对码有效期应对齐 Rust 侧 PAIRING_CODE_TTL = 10 分钟',
    );
  });

  it('等待配对请求（acceptPairingRequest*，有界超时）', () => {
    assert.match(
      devices,
      /acceptPairingRequest\w*\s*\(/,
      'devices_page.tsx 应调用 BackendPairing.acceptPairingRequest*（等待对端请求）',
    );
    // 有界等待：必须带 timeout（acceptPairingRequestWithTimeout 或传 timeout_ms）。
    assert.match(
      devices,
      /acceptPairingRequestWithTimeout\s*\(|timeout_ms|timeoutMs|acceptTimeout/i,
      '等待配对请求必须有界（acceptPairingRequestWithTimeout 或超时参数）',
    );
  });

  it('确认配对（confirmPairing）', () => {
    assert.match(
      devices,
      /confirmPairing\s*\(/,
      'devices_page.tsx 应调用 BackendPairing.confirmPairing(code, request)',
    );
  });

  it('发起方连接（beginPairingConnect*，6 位码或凭证路径）', () => {
    assert.match(
      devices,
      /beginPairingConnect\w*\s*\(/,
      'devices_page.tsx 应调用 BackendPairing.beginPairingConnect*（发起方连接）',
    );
  });

  it('凭证直连替代路径（beginPairingConnectWithCredential + parsePairingCredential）', () => {
    assert.match(
      devices,
      /beginPairingConnectWithCredential\s*\(/,
      '扫码不可用时的替代路径：beginPairingConnectWithCredential（凭证直连）',
    );
    assert.match(
      devices,
      /parsePairingCredential\s*\(/,
      '输入凭证应先经 parsePairingCredential 验证（友好错误）',
    );
  });

  it('倒计时（setInterval 驱动 + 清理，10 分钟有效期语义）', () => {
    assert.match(
      devices,
      /setInterval\s*\(/,
      '配对码倒计时应用 setInterval 驱动（signal 更新）',
    );
    assert.match(
      devices,
      /clearInterval\s*\(|cleanup\s*\(/,
      '倒计时定时器组件卸载时必须清理（clearInterval/cleanup）',
    );
    const code = codeOnly(devices);
    assert.match(
      code,
      /10\s*\*\s*60|600_?000|600000|minutes?:\s*10|10\s*分钟/,
      '配对码有效期应对齐 Rust 侧 PAIRING_CODE_TTL = 10 分钟',
    );
  });
});

describe('2.5 devices_page.tsx — 设备管理', () => {
  it('已配对设备列表（listPairedDevices）', () => {
    assert.match(
      devices,
      /listPairedDevices\s*\(/,
      'devices_page.tsx 应调用 BackendPairing.listPairedDevices()',
    );
  });

  it('解绑（removePairedDevice）走 CardMindConfirmDialog 危险确认', () => {
    assert.match(
      devices,
      /removePairedDevice\s*\(/,
      'devices_page.tsx 应调用 BackendPairing.removePairedDevice(peerId)',
    );
    assert.match(
      devices,
      /<CardMindConfirmDialog\b/,
      '解除配对必须弹 CardMindConfirmDialog 确认，不能直删',
    );
    assert.match(devices, /danger/, '解绑确认对话框应用 danger 危险态');
  });

  it('连通检查（BackendSync.checkDeviceConnectivity）', () => {
    assert.match(
      devices,
      /checkDeviceConnectivity\s*\(/,
      'devices_page.tsx 应调用 BackendSync.checkDeviceConnectivity(peerId)',
    );
  });

  it('本机信息（getDeviceId / getDeviceName / localAddrs）', () => {
    for (const fn of ['getDeviceId', 'getDeviceName', 'localAddrs']) {
      assert.match(
        devices,
        new RegExp(`${fn}\\s*\\(`),
        `devices_page.tsx 应调用 BackendPairing.${fn}()`,
      );
    }
  });

  it('设备改名（setDeviceName*）', () => {
    assert.match(
      devices,
      /setDeviceName\w*\s*\(/,
      'devices_page.tsx 应提供设备改名（setDeviceName*）',
    );
  });

  it('发现对端（discoverPeers / syncDiscoverPeers）', () => {
    assert.match(
      devices,
      /discoverPeers\s*\(|syncDiscoverPeers\s*\(/i,
      'devices_page.tsx 应调用 BackendPairing.discoverPeers() 或 syncDiscoverPeers()',
    );
  });

  it('空态用 CardMindEmptyState', () => {
    assert.match(
      devices,
      /CardMindEmptyState/,
      '设备列表空态应使用 CardMindEmptyState 组件',
    );
  });
});

describe('2.5 devices_page.tsx — R3 扫码诚实标注', () => {
  it('扫码入口存在但 disabled + 说明文案（R3 阻塞项）', () => {
    // 扫码入口文案存在（「扫码」字样）。
    assert.match(devices, /扫码/, '应保留「扫码」入口（R3 占位）');
    // 入口必须 disabled（或 onPress 缺省 = components.tsx 的 disabled 语义），
    // 并附不可用说明文案（移动端平台能力/相机/暂不可用 任一）。
    const scanBlock = devices.match(/扫码[\s\S]{0,400}/);
    assert.ok(scanBlock, '应能找到扫码入口区块');
    assert.match(
      scanBlock![0],
      /disabled|onPress=\{undefined\}|onPress\s*=\s*\{\s*\(\)\s*=>\s*\{\s*\}\s*\}/,
      '扫码入口必须是 disabled/不可用（NSH 无相机 API）',
    );
    assert.match(
      devices,
      /相机|移动端平台能力|暂不可用|不可用|不支持扫码/,
      '扫码入口必须有「为什么不可用」说明文案（R3 诚实标注，不假报可用）',
    );
  });
});

describe('2.5 devices_page.tsx — 令牌纪律', () => {
  it('从 ./theme 导入令牌', () => {
    assert.match(
      devices,
      /import\s*\{[^}]*\b(colors|layout|spacing|radii)\b[^}]*\}\s*from\s*['"]\.\/theme(\.ts)?['"]/,
      'devices_page.tsx 应 import { colors, layout, ... } from "./theme"',
    );
  });

  it('不含裸 #RRGGBB / 0x 色值字面量', () => {
    assert.ok(
      !/#[0-9A-Fa-f]{3,8}\b/.test(devices),
      'devices_page.tsx 出现裸 hex 色值（应改用 theme.ts 的 colors.*）',
    );
    assert.ok(
      !/0x[0-9A-Fa-f]{6,8}\b/.test(devices),
      'devices_page.tsx 出现 0x 色值',
    );
  });

  it('触摸目标走 layout.mobileTouchTarget（≥48dp 令牌，非裸 48）', () => {
    assert.match(
      devices,
      /layout\.mobileTouchTarget/,
      'devices_page.tsx 应用 layout.mobileTouchTarget 表达触摸目标',
    );
    const code = codeOnly(devices);
    assert.ok(
      !/(?<![\w.])48(?![\w.])/.test(code),
      'devices_page.tsx 不应出现裸 48（触摸目标经 layout.mobileTouchTarget）',
    );
  });

  it('不引入 React hooks（nsh 用 signal）', () => {
    for (const hook of ['useState', 'useEffect', 'useMemo', 'useCallback', 'useRef']) {
      assert.ok(!devices.includes(hook), `devices_page.tsx 不应使用 React 的 ${hook}`);
    }
  });
});

describe('2.5 App.tsx 接入', () => {
  it('App.tsx 导入 devices_page 模块', () => {
    assert.match(
      app,
      /import\s*[\s\S]*?from\s*['"]\.\/devices_page(\.tsx)?['"]/,
      'App.tsx 应 `import { ... } from "./devices_page"`',
    );
  });

  it('App.tsx 渲染 devices_page 导出的组件', () => {
    const imported = app.match(
      /import\s*\{([^}]*)\}\s*from\s*['"]\.\/devices_page(\.tsx)?['"]/,
    );
    assert.ok(imported, 'App.tsx 应 import { X } from "./devices_page"');
    const names = imported![1]
      .split(',')
      .map((s) => s.trim().split(/\s+as\s+/).pop()!)
      .filter(Boolean);
    const used = names.filter((n) => new RegExp(`<${n}\\b`).test(app));
    assert.ok(
      used.length > 0,
      `App.tsx 应渲染 ./devices_page 导出的组件（导入 ${names.join(',')}；用到 ${used.join(',') || '无'}）`,
    );
  });

  it('Phase 1 后端调用仍保留', () => {
    for (const call of [
      'BackendNotes.noteCreate',
      'BackendNotes.noteSoftDelete',
      'BackendStore.storeList',
      'BackendStore.storeSearch',
      'BackendSync.getSyncAllowed',
      'BackendPairing.listPairedDevices',
      'BackendSync.close',
    ]) {
      assert.ok(app.includes(call), `App.tsx 缺失 Phase 1 调用 ${call}`);
    }
  });
});
