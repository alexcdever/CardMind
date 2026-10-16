import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/update_channel.dart';

class AppSettingsService {
  AppSettingsService({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<File> get _file async {
    final directory = await _directoryProvider();
    return File('${directory.path}${Platform.pathSeparator}settings.json');
  }

  Future<UpdateChannel> readChannel() async {
    final settings = await _read();
    return UpdateChannel.fromValue(settings['updateChannel']);
  }

  Future<bool> readUseSystemProxy() async {
    final settings = await _read();
    final value = settings['useSystemProxy'];
    return value is bool ? value : true;
  }

  Future<void> writeChannel(UpdateChannel channel) async {
    final settings = await _read();
    settings['updateChannel'] = channel.value;
    await _write(settings);
  }

  Future<void> writeUseSystemProxy(bool value) async {
    final settings = await _read();
    settings['useSystemProxy'] = value;
    await _write(settings);
  }

  Future<Map<String, dynamic>> _read() async {
    try {
      final value = jsonDecode(await (await _file).readAsString());
      return value is Map
          ? Map<String, dynamic>.from(value)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _write(Map<String, dynamic> settings) async {
    final file = await _file;
    await file.parent.create(recursive: true);
    await file.writeAsString('${jsonEncode(settings)}\n');
  }
}
