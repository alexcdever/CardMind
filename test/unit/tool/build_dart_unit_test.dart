import 'package:flutter_test/flutter_test.dart';

import '../../../tool/build.dart';

void main() {
  test('it_should_find_frameworks_group_id', () {
    final lines = <String>[
      '/* Begin PBXGroup section */',
      '\t\tD73912EC22F37F3D000D13A0 /* Frameworks */ = {',
      '\t\t\tisa = PBXGroup;',
      '\t\t\tchildren = (',
      '\t\t\t);',
      '\t\t};',
      '/* End PBXGroup section */',
    ];

    final id = findFrameworksGroupId(lines);

    expect(id, 'D73912EC22F37F3D000D13A0');
  });

  test('it_should_ignore_frameworks_build_phase_when_finding_group_id', () {
    final lines = <String>[
      '/* Begin PBXFrameworksBuildPhase section */',
      '\t\t111111111111111111111111 /* Frameworks */ = {',
      '\t\t\tisa = PBXFrameworksBuildPhase;',
      '\t\t};',
      '/* End PBXFrameworksBuildPhase section */',
      '/* Begin PBXGroup section */',
      '\t\t222222222222222222222222 /* Frameworks */ = {',
      '\t\t\tisa = PBXGroup;',
      '\t\t};',
      '/* End PBXGroup section */',
    ];

    final id = findFrameworksGroupId(lines);

    expect(id, '222222222222222222222222');
  });

  test('it_should_return_null_when_frameworks_group_missing', () {
    final lines = <String>[
      '/* Begin PBXFrameworksBuildPhase section */',
      '\t\t111111111111111111111111 /* Frameworks */ = {',
      '\t\t\tisa = PBXFrameworksBuildPhase;',
      '\t\t};',
      '/* End PBXFrameworksBuildPhase section */',
      '/* Begin PBXGroup section */',
      '\t\t333333333333333333333333 /* Products */ = {',
      '\t\t\tisa = PBXGroup;',
      '\t\t};',
      '/* End PBXGroup section */',
    ];

    final id = findFrameworksGroupId(lines);

    expect(id, isNull);
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

  test('it_should_add_line_to_object_list_with_comment', () {
    final lines = <String>[
      '\t\tD73912EC22F37F3D000D13A0 /* Frameworks */ = {',
      '\t\t\tisa = PBXGroup;',
      '\t\t\tchildren = (',
      '\t\t\t);',
      '\t\t};',
    ];

    final added = addLineToObjectList(
      lines,
      'D73912EC22F37F3D000D13A0',
      'children',
      '\t\t\t\tBBB /* item */,',
    );

    expect(added, isTrue);
    expect(lines, contains('\t\t\t\tBBB /* item */,'));
  });

  test('it_should_remove_line_from_object_list', () {
    final lines = <String>[
      '\t\tABCDEF1234567890ABCDEF12 /* Bundle Framework */ = {',
      '\t\t\tisa = PBXCopyFilesBuildPhase;',
      '\t\t\tfiles = (',
      '\t\t\t\t111111111111111111111111 /* cardmind_rust.xcframework in Bundle Framework */,',
      '\t\t\t\t222222222222222222222222 /* Other.framework in Bundle Framework */,',
      '\t\t\t);',
      '\t\t};',
    ];

    final removed = removeLineFromObjectList(
      lines,
      'ABCDEF1234567890ABCDEF12',
      'files',
      'cardmind_rust.xcframework',
    );

    expect(removed, isTrue);
    expect(
      lines.any((line) => line.contains('cardmind_rust.xcframework')),
      isFalse,
    );
  });

  test('it_should_use_crate_api_rust_input_for_codegen', () {
    final args = buildCodegenArgs();

    final rustInputIndex = args.indexOf('--rust-input');
    expect(rustInputIndex, isNot(-1));
    expect(args[rustInputIndex + 1], 'crate::api');
  });

  test('it_should_include_both_macos_rust_targets', () {
    final targets = macosRustTargets();

    expect(targets, contains('aarch64-apple-darwin'));
    expect(targets, contains('x86_64-apple-darwin'));
  });

  test('it_should_build_macos_library_paths', () {
    final paths = macosLibraryPaths();

    expect(
      paths,
      contains('rust/target/aarch64-apple-darwin/release/libcardmind_rust.a'),
    );
    expect(
      paths,
      contains('rust/target/x86_64-apple-darwin/release/libcardmind_rust.a'),
    );
  });

  test('it_should_skip_embed_when_phase_name_is_empty', () {
    expect(shouldEmbedFrameworks(null), isFalse);
    expect(shouldEmbedFrameworks(''), isFalse);
    expect(shouldEmbedFrameworks('Embed Frameworks'), isTrue);
  });

  test('it_should_skip_insert_when_xcframework_exists', () {
    expect(shouldInsertXcframework('cardmind_rust.xcframework'), isFalse);
    expect(shouldInsertXcframework(''), isTrue);
  });
}
