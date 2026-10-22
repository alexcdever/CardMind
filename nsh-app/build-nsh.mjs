// nsh build 包装：要求 NSH_SOURCE 指向 nsh 源码 checkout，未设时明确报错退出 1。
// 用法：node build-nsh.mjs（在 nsh-app/ 下，等价于 `nsh build . -o out`）。
import { spawnSync } from 'node:child_process';

if (!process.env.NSH_SOURCE) {
  console.error(
    '[build] NSH_SOURCE 未设置：请指向 nsh 源码 checkout 目录\n' +
      '        PowerShell: $env:NSH_SOURCE = "<path-to-nsh-src-git>"',
  );
  process.exit(1);
}

const nsh = process.platform === 'win32' ? 'nsh.exe' : 'nsh';
const result = spawnSync(nsh, ['build', '.', '-o', 'out'], {
  stdio: 'inherit',
  shell: process.platform === 'win32',
});
if (result.error) {
  console.error(`[build] 无法启动 ${nsh}: ${result.error.message}`);
  process.exit(1);
}
process.exit(result.status ?? 1);
