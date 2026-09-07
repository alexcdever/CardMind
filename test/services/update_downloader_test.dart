import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cardmind/models/update_manifest.dart';
import 'package:cardmind/services/update_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late List<int> bytes;

  setUp(() async {
    bytes = utf8.encode('CardMind update');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/error') {
        request.response.statusCode = 503;
        await request.response.close();
        return;
      }
      if (request.uri.path == '/slow') {
        request.response.add(bytes.sublist(0, 1));
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        request.response.add(bytes.sublist(1));
      } else {
        request.response.add(bytes);
      }
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  UpdateAsset asset({int? size, String? hash}) => UpdateAsset(
    artifact: 'update.bin',
    url: 'https://example.com/update',
    sha256:
        hash ??
        'c43bbf3138feea3b65e0e62c7fc31bdb464d8e238354208e655d1361c067ddff',
    size: size ?? bytes.length,
  );

  test('downloads bytes and returns a temporary file', () async {
    final result = await UpdateDownloader(
      client: _redirectingClient(),
    ).download(asset(), url: Uri.parse('http://localhost:${server.port}/'));
    expect(result, isA<DownloadSuccess>());
    final path = (result as DownloadSuccess).file.path;
    expect(await File(path).readAsBytes(), bytes);
    expect(path, isNot(contains(Platform.resolvedExecutable)));
    await File(path).delete();
    await Directory(
      path.substring(0, path.lastIndexOf(Platform.pathSeparator)),
    ).delete();
  });

  test('reports progress and accepts a custom temporary directory', () async {
    final directory = await Directory.systemTemp.createTemp('cardmind-test-');
    addTearDown(() => directory.delete(recursive: true));
    final progress = <double>[];
    final result =
        await UpdateDownloader(
          client: _redirectingClient(),
          directoryProvider: (_) async => directory,
        ).download(
          asset(),
          url: Uri.parse('http://localhost:${server.port}/'),
          onProgress: progress.add,
        );
    expect(result, isA<DownloadSuccess>());
    expect(progress, isNotEmpty);
    expect(progress.last, 1.0);
  });

  test('cancellation during streaming removes the partial file', () async {
    final directory = await Directory.systemTemp.createTemp('cardmind-test-');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final token = DownloadCancellationToken();
    Timer(const Duration(milliseconds: 10), token.cancel);
    final result =
        await UpdateDownloader(
          client: _redirectingClient(),
          directoryProvider: (_) async => directory,
        ).download(
          asset(),
          url: Uri.parse('http://localhost:${server.port}/slow'),
          cancellation: token,
        );
    expect(result, isA<DownloadFailure>());
    expect(directory.existsSync(), isFalse);
  });

  test('rejects size mismatch and removes temporary file', () async {
    final result = await UpdateDownloader(client: _redirectingClient())
        .download(
          asset(size: bytes.length + 1),
          url: Uri.parse('http://localhost:${server.port}/'),
        );
    expect(result, isA<DownloadFailure>());
    expect((result as DownloadFailure).message, contains('文件大小'));
  });

  test('rejects hash mismatch and removes temporary file', () async {
    final result = await UpdateDownloader(client: _redirectingClient())
        .download(
          asset(hash: '0' * 64),
          url: Uri.parse('http://localhost:${server.port}/'),
        );
    expect(result, isA<DownloadFailure>());
    expect((result as DownloadFailure).message, contains('SHA-256'));
  });

  test('reports HTTP errors and cancellation', () async {
    final downloader = UpdateDownloader(client: _redirectingClient());
    final failed = await downloader.download(
      asset(),
      url: Uri.parse('http://localhost:${server.port}/error'),
    );
    expect(failed, isA<DownloadFailure>());
    final token = DownloadCancellationToken()..cancel();
    final cancelled = await downloader.download(
      asset(),
      url: Uri.parse('http://localhost:${server.port}/'),
      cancellation: token,
    );
    expect(cancelled, isA<DownloadFailure>());
    expect((cancelled as DownloadFailure).message, contains('取消'));
  });

  test('rejects non-HTTPS manifest URL before opening a connection', () async {
    final result = await UpdateDownloader(client: _redirectingClient())
        .download(
          UpdateAsset(
            artifact: 'update.bin',
            url: 'http://example.com/update',
            sha256: '0' * 64,
            size: bytes.length,
          ),
        );
    expect(result, isA<DownloadFailure>());
    expect((result as DownloadFailure).message, '下载地址必须使用 HTTPS');
  });

  test(
    'rejects a non-local HTTP override as well as the manifest URL',
    () async {
      final result = await UpdateDownloader(
        client: _redirectingClient(),
      ).download(asset(), url: Uri.parse('http://example.com/'));
      expect(result, isA<DownloadFailure>());
      expect((result as DownloadFailure).message, '下载地址必须使用 HTTPS');
    },
  );
}

HttpClient _redirectingClient() =>
    HttpClient()..badCertificateCallback = (_, _, _) => true;
