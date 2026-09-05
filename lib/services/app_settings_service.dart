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
    try {
      final value = jsonDecode(await (await _file).readAsString());
      if (value is! Map) return UpdateChannel.stable;
      return UpdateChannel.fromValue(value['updateChannel']);
    } catch (_) {
      return UpdateChannel.stable;
    }
  }

  Future<void> writeChannel(UpdateChannel channel) async {
    final file = await _file;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode({'updateChannel': channel.value})}\n',
    );
  }
}
