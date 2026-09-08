import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:path_provider/path_provider.dart';

import '../models/update_manifest.dart';

sealed class DownloadResult {
  const DownloadResult();
}

class DownloadSuccess extends DownloadResult {
  const DownloadSuccess(this.file);

  final File file;
}

class DownloadFailure extends DownloadResult {
  const DownloadFailure(this.message);

  final String message;
}

class DownloadCancellationToken {
  bool _cancelled = false;

  bool get cancelled => _cancelled;

  void cancel() => _cancelled = true;
}

class UpdateDownloader {
  UpdateDownloader({
    HttpClient? client,
    this.timeout = const Duration(minutes: 3),
    Future<Directory> Function(String prefix)? directoryProvider,
  }) : _client = client ?? HttpClient(),
       _directoryProvider = directoryProvider ?? _createTempDirectory;

  // Android 上 Directory.systemTemp 指向 code_cache/ 且路径形式为 /data/data/<pkg>/…，
  // FileProvider 匹配会失败（URI_FAILED: Failed to find configured root）。
  // 用 path_provider 的临时目录（Android = context.cacheDir，/data/user/0/<pkg>/cache，
  // 与 AndroidManifest 的 FileProvider cache-path 同源同形式）。
  static Future<Directory> _createTempDirectory(String prefix) async {
    try {
      final base = await getTemporaryDirectory();
      final dir = Directory(
        '${base.path}${Platform.pathSeparator}$prefix'
        '${DateTime.now().millisecondsSinceEpoch}',
      );
      await dir.create(recursive: true);
      return dir;
    } catch (_) {
      // 无 path_provider 平台实现（测试/桌面兜底）时退回 systemTemp
      return Directory.systemTemp.createTemp(prefix);
    }
  }

  final HttpClient _client;
  final Duration timeout;
  final Future<Directory> Function(String prefix) _directoryProvider;

  void dispose() => _client.close(force: true);

  Future<DownloadResult> download(
    UpdateAsset asset, {
    Uri? url,
    DownloadCancellationToken? cancellation,
    void Function(double)? onProgress,
  }) async {
    File? temp;
    IOSink? sink;
    var verified = false;
    try {
      if (cancellation?.cancelled ?? false) {
        return const DownloadFailure('下载已取消');
      }
      final uri = url ?? Uri.parse(asset.url);
      final isLocalTestEndpoint =
          (uri.host == 'localhost' || uri.host == '127.0.0.1') && uri.port > 0;
      if (uri.scheme != 'https' && !isLocalTestEndpoint) {
        return const DownloadFailure('下载地址必须使用 HTTPS');
      }
      final request = await _client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        return DownloadFailure('下载失败：HTTP ${response.statusCode}');
      }
      final dir = await _directoryProvider('cardmind-update-');
      temp = File('${dir.path}${Platform.pathSeparator}${asset.artifact}');
      sink = temp.openWrite();
      var count = 0;
      await for (final chunk in response) {
        if (cancellation?.cancelled ?? false) throw const _Cancelled();
        sink.add(chunk);
        await sink.flush();
        count += chunk.length;
        onProgress?.call((count / asset.size).clamp(0.0, 1.0));
      }
      await sink.close();
      sink = null;
      if (count != asset.size) {
        throw const FormatException('文件大小与清单不一致');
      }
      final digest = sha256.convert(await temp.readAsBytes()).toString();
      if (digest.toLowerCase() != asset.sha256.toLowerCase()) {
        throw const FormatException('SHA-256 校验失败');
      }
      verified = true;
      return DownloadSuccess(temp);
    } on _Cancelled {
      return const DownloadFailure('下载已取消');
    } on TimeoutException {
      return const DownloadFailure('下载超时');
    } catch (error) {
      return DownloadFailure('下载失败：$error');
    } finally {
      if (sink != null) await sink.close();
      if (!verified && temp != null) await _remove(temp);
    }
  }

  Future<void> _remove(File file) async {
    try {
      final directory = file.parent;
      if (await file.exists()) await file.delete();
      if (await directory.exists()) await directory.delete();
    } catch (_) {}
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
