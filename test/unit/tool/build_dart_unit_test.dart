import 'package:flutter_test/flutter_test.dart';

import '../../../tool/build.dart';

void main() {
  test('it_should_find_frameworks_group_id', () {
    final lines = <String>[
      '\t\tD73912EC22F37F3D000D13A0 /* Frameworks */ = {',
      '\t\t\tisa = PBXGroup;',
      '\t\t\tchildren = (',
      '\t\t\t);',
      '\t\t};',
    ];

    final id = findFrameworksGroupId(lines);

    expect(id, 'D73912EC22F37F3D000D13A0');
  });

  test('it_should_find_runner_frameworks_build_phase_id', () {
    final lines = <String>[
      '\t\t33CC10EC2044A3C60003C045 /* Runner */ = {',
      '\t\t\tisa = PBXNativeTarget;',
      '\t\t\tbuildPhases = (',
      '\t\t\t\t33CC10EA2044A3C60003C045 /* Frameworks */,',
      '\t\t\t);',
      '\t\t};',
    ];

    final id = findRunnerBuildPhaseId(lines, 'Frameworks');

    expect(id, '33CC10EA2044A3C60003C045');
  });

  test('it_should_add_line_to_object_list_without_comment', () {
    final lines = <String>[
      '\t\t97C146E51CF9000F007C117D = {',
      '\t\t\tisa = PBXGroup;',
      '\t\t\tchildren = (',
      '\t\t\t);',
      '\t\t};',
    ];

    final added = addLineToObjectList(
      lines,
      '97C146E51CF9000F007C117D',
      'children',
      '\t\t\t\tAAA /* item */,',
    );

    expect(added, isTrue);
    expect(lines, contains('\t\t\t\tAAA /* item */,'));
  });

  test('it_should_use_crate_api_rust_input_for_codegen', () {
    final args = buildCodegenArgs();

    final rustInputIndex = args.indexOf('--rust-input');
    expect(rustInputIndex, isNot(-1));
    expect(args[rustInputIndex + 1], 'crate::api');
  });
}
