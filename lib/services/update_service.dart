import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/update_channel.dart';
import '../models/update_manifest.dart';

class _ParsedVersion {
  const _ParsedVersion(this.core, this.prerelease);

  final List<int> core;
  final List<String> prerelease;
}

sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

class UpdateAvailable extends UpdateCheckResult {
  const UpdateAvailable(this.manifest);

  final UpdateManifest manifest;
}

class UpdateUpToDate extends UpdateCheckResult {
  const UpdateUpToDate(this.manifest);

  final UpdateManifest manifest;
}

class UpdateCheckError extends UpdateCheckResult {
  const UpdateCheckError(this.message);

  final String message;
}

class UpdateService {
  UpdateService({
    this.currentBuild = 0,
    this.currentVersion = '',
    Future<String> Function(Uri)? fetch,
    this._timeout = const Duration(seconds: 20),
  }) : _fetch = fetch ?? _httpFetch;

  final int currentBuild;
  final String currentVersion;
  final Future<String> Function(Uri) _fetch;
  final Duration _timeout;

  Future<UpdateCheckResult> check(UpdateChannel channel) async {
    try {
      final body = await _fetch(
        Uri.parse(channel.manifestUrl),
      ).timeout(_timeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return const UpdateCheckError('更新清单无效');
      }
      final manifest = UpdateManifest.tryParse(
        Map<String, dynamic>.from(decoded),
        channel: channel.value,
      );
      if (manifest == null) return const UpdateCheckError('更新清单无效');
      return _isNewer(manifest)
          ? UpdateAvailable(manifest)
          : UpdateUpToDate(manifest);
    } on TimeoutException {
      return const UpdateCheckError('检查更新超时');
    } catch (error) {
      return UpdateCheckError('检查更新失败：$error');
    }
  }

  bool _isNewer(UpdateManifest manifest) {
    if (manifest.build != currentBuild) return manifest.build > currentBuild;
    return _compareVersions(manifest.version, currentVersion) > 0;
  }

  static int _compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    for (var index = 0; index < 3; index++) {
      final difference = leftParts.core[index] - rightParts.core[index];
      if (difference != 0) return difference;
    }
    return _comparePrerelease(leftParts.prerelease, rightParts.prerelease);
  }

  static _ParsedVersion _versionParts(String value) {
    final separator = value.indexOf('-');
    final core = separator < 0 ? value : value.substring(0, separator);
    final prerelease = separator < 0 ? null : value.substring(separator + 1);
    return _ParsedVersion(
      core.split('.').map(int.parse).toList(),
      prerelease == null ? const <String>[] : prerelease.split('.'),
    );
  }

  static int _comparePrerelease(List<String> left, List<String> right) {
    if (left.isEmpty && right.isEmpty) return 0;
    if (left.isEmpty) return 1;
    if (right.isEmpty) return -1;
    final length = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      if (index >= left.length) return -1;
      if (index >= right.length) return 1;
      final leftNumber = int.tryParse(left[index]);
      final rightNumber = int.tryParse(right[index]);
      if (leftNumber != null && rightNumber != null) {
        final difference = leftNumber - rightNumber;
        if (difference != 0) return difference;
      } else if (leftNumber != null) {
        return -1;
      } else if (rightNumber != null) {
        return 1;
      } else {
        final difference = left[index].compareTo(right[index]);
        if (difference != 0) return difference;
      }
    }
    return 0;
  }

  static Future<String> _httpFetch(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }
}
