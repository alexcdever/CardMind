// input: 加载 FRB 生成的 bridge API 顶层后端用例函数符号。
// output: initAppConfig 与无句柄资源 API 可访问。
// pos: 覆盖桥接 API 主路径契约，防止产品路径重新暴露 store handle。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generated bridge should expose initAppConfig and handle-free backend apis',
    () {
      expect(frb.initAppConfig, isNotNull);
      expect(frb.createPool, isNotNull);
      expect(frb.createCardNote, isNotNull);
      expect(frb.listCardNotes, isNotNull);
      expect(frb.getPoolMembersRuntimeView, isNotNull);
      expect(frb.getPoolRuntimeSummary, isNotNull);
      expect(frb.listActiveInvites, isNotNull);
      expect(frb.revokeInvite, isNotNull);
    },
  );
}
