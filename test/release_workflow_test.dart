import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

YamlMap _workflow() {
  final source = File(
    '.github/workflows/manual-build-artifacts.yml',
  ).readAsStringSync();
  return loadYaml(source) as YamlMap;
}

Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

void main() {
  late YamlMap workflow;
  late Map<String, dynamic> jobs;

  setUpAll(() {
    workflow = _workflow();
    jobs = _map(workflow['jobs']);
  });

  test('main push and manual dispatch trigger complete release', () {
    final trigger = workflow['on'] ?? workflow[true];
    final events = _map(trigger);
    expect(_map(events['push'])['branches'], ['main']);
    expect(events.containsKey('workflow_dispatch'), isTrue);
    expect(workflow['name'], 'CardMind Main Release');
    expect(workflow['permissions'], {'contents': 'write'});
  });

  test('build matrix matches the three supported platforms', () {
    expect(jobs.keys, containsAll(<String>['android', 'windows', 'linux']));
    expect(jobs.keys, contains('release'));
    expect(jobs.keys, hasLength(4));
    expect(jobs.keys, isNot(contains('macos')));
    expect(jobs.keys, isNot(contains('ios')));
    expect(_map(jobs['release'])['needs'], ['android', 'windows', 'linux']);
  });

  test('desktop jobs install current Rust runtime libraries', () {
    for (final platform in ['windows', 'linux']) {
      final steps = (_map(jobs[platform])['steps'] as YamlList)
          .map(_map)
          .toList();
      final rust = steps.firstWhere(
        (step) => step['name'] == 'Build Rust library',
      );
      expect(rust['working-directory'], 'rust-backend');
      expect(rust['run'], contains('cargo build --release'));
      final copy = steps.firstWhere(
        (step) => step['name'] == 'Install Rust runtime library',
      );
      expect(copy['run'], contains('cardmind_backend'));
      expect(
        copy['run'],
        contains(platform == 'windows' ? 'Test-Path' : 'test -s'),
      );
    }
  });

  test('linux apt setup uses a bounded, resilient archive mirror', () {
    final steps = (_map(jobs['linux'])['steps'] as YamlList)
        .map(_map)
        .toList();
    final install = steps.firstWhere(
      (step) => step['name'] == 'Install Linux build dependencies',
    );
    final run = install['run'] as String;

    expect(run, contains("-name '*.list'"));
    expect(run, contains("-name '*.sources'"));
    expect(run, contains(r'azure\.archive\.ubuntu\.com'));
    expect(run, contains('archive.ubuntu.com'));
    expect(run, contains('apt_files'));
    expect(run, contains("sudo sed -i 's/azure\\.archive\\.ubuntu\\.com/archive.ubuntu.com/g'"));
    expect(run, contains('exit 1'));
    expect(run, contains('grep -R'));
    expect(run, contains('timeout 180s sudo apt-get update'));
    expect(
      run,
      contains(
        'timeout 180s sudo apt-get install -y clang cmake ninja-build '
        'pkg-config libgtk-3-dev build-essential',
      ),
    );
  });

  test(
    'linux package preserves the complete bundle under the cardmind root',
    () {
      final steps = (_map(jobs['linux'])['steps'] as YamlList)
          .map(_map)
          .toList();
      final package = steps.firstWhere(
        (step) => step['name'] == 'Package Linux artifact',
      );
      expect(package['run'], contains('mkdir -p cardmind'));
      expect(package['run'], contains('-C . cardmind'));
      expect(
        package['run'],
        contains('tar -czf CardMind-Linux-x64.tar.gz -C . cardmind'),
      );
      expect(
        package['run'],
        isNot(contains('-C build/linux/x64/release/bundle .')),
      );
    },
  );

  test('release workflow has no machine paths or embedded secrets', () {
    final source = File(
      '.github/workflows/manual-build-artifacts.yml',
    ).readAsStringSync();
    expect(source, isNot(matches(RegExp(r'[A-Za-z]:[\\/]'))));
    expect(source, isNot(contains('BEGIN PRIVATE KEY')));
    expect(source, isNot(contains('GITHUB_TOKEN:')));
  });

  test('android build stages all supported JNI ABI directories', () {
    final steps = (_map(jobs['android'])['steps'] as YamlList)
        .map(_map)
        .toList();
    final build = steps.firstWhere(
      (step) => step['name'] == 'Build Android Rust libraries',
    );
    expect(build['run'], contains('-o ../build/android-jni'));
    expect(build['run'], contains('-t armeabi-v7a'));
    expect(build['run'], contains('-t arm64-v8a'));
    expect(build['run'], contains('-t x86_64'));
    expect(workflow['env'], containsPair('FRB_CODEGEN_VERSION', '2.12.0'));
  });

  test('all Flutter release jobs pin the project Flutter version', () {
    for (final platform in ['android', 'windows', 'linux']) {
      final steps = (_map(jobs[platform])['steps'] as YamlList)
          .map(_map)
          .toList();
      final flutter = steps.firstWhere(
        (step) => step['uses'] == 'subosito/flutter-action@v2',
      );
      expect(_map(flutter['with'])['flutter-version'], '3.44.9');
      expect(_map(flutter['with'])['cache'], true);
    }
  });

  test('android removes DIR.md resources before building the APK', () {
    final steps = (_map(jobs['android'])['steps'] as YamlList)
        .map(_map)
        .toList();
    final cleanupIndex = steps.indexWhere(
      (step) => '${step['run']}'.contains(
        'find android/app/src/main/res -type f -name DIR.md -delete',
      ),
    );
    final apkIndex = steps.indexWhere(
      (step) => step['run'] == 'flutter build apk --release',
    );
    expect(cleanupIndex, greaterThanOrEqualTo(0));
    expect(cleanupIndex, lessThan(apkIndex));
  });

  test('windows release is an Inno Setup exe rather than a zip', () {
    final steps = (_map(jobs['windows'])['steps'] as YamlList)
        .map(_map)
        .toList();
    final install = steps.firstWhere(
      (step) => step['name'] == 'Compile Inno Setup installer',
    );
    expect(install['run'], contains('ISCC.exe'));
    expect(install['run'], contains('/DSourceDir='));
    final artifact = steps.firstWhere(
      (step) => step['name'] == 'Upload Windows artifact',
    );
    expect(_map(artifact['with'])['path'], 'CardMind-Setup.exe');
    expect(
      steps.where((step) => '${step['run']}'.contains('Compress-Archive')),
      isEmpty,
    );
  });

  test(
    'release waits for all builds and uploads exact assets idempotently',
    () {
      final release = _map(jobs['release']);
      expect(release['if'], contains('success()'));
      final steps = (release['steps'] as YamlList).map(_map).toList();
      final download = steps.firstWhere(
        (step) => step['uses'] == 'actions/download-artifact@v4',
      );
      expect(_map(download['with'])['pattern'], 'release-*');
      final verify = steps.firstWhere(
        (step) => step['name'] == 'Verify release assets',
      );
      expect(verify['run'], contains('CardMind-Android.apk'));
      expect(verify['run'], contains('CardMind-Setup.exe'));
      expect(verify['run'], contains('CardMind-Linux-x64.tar.gz'));
      final publish = steps.firstWhere(
        (step) => step['uses'] == 'softprops/action-gh-release@v2',
      );
      expect(publish['uses'], 'softprops/action-gh-release@v2');
      expect(
        _map(publish['with'])['tag_name'],
        contains('steps.tag.outputs.tag'),
      );
      expect(_map(publish['with'])['target_commitish'], r'${{ github.sha }}');
      expect(_map(publish['with'])['prerelease'], true);
      expect(_map(publish['with'])['files'], contains('CardMind-Android.apk'));
      expect(_map(publish['with'])['files'], contains('CardMind-Setup.exe'));
      expect(
        _map(publish['with'])['files'],
        contains('CardMind-Linux-x64.tar.gz'),
      );
    },
  );
}
