import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../bridge/api/loro_export.dart';
import '../bridge/third_party/cardmind_rust/api/loro_export.dart';

/// Loro 文件操作服务
class LoroFileService {
  /// 导出数据到文件
  ///
  /// 返回导出的文件路径，如果用户取消则返回 null
  static Future<String?> exportData() async {
    try {
      // 1. 调用 Rust FFI 获取快照
      final json = await loroExportSnapshot();

      // 2. 生成文件名
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'cardmind-export-$timestamp.json';

      // 3. 获取下载目录
      Directory? directory;
      if (Platform.isAndroid || Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory == null) {
        throw Exception('无法获取下载目录');
      }

      // 4. 写入文件
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(json);

      return filePath;
    } catch (e) {
      rethrow;
    }
  }

  /// 导入数据从文件
  ///
  /// 返回导入的卡片数量，如果用户取消则返回 null
  static Future<int?> importData() async {
    try {
      // 1. 打开文件选择对话框
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null; // 用户取消
      }

      final file = result.files.first;

      // 2. 验证文件大小 (< 100MB)
      const maxSize = 100 * 1024 * 1024;
      if (file.size > maxSize) {
        throw Exception('文件大小超过 100MB 限制');
      }

      // 3. 读取文件内容
      String json;
      if (file.bytes != null) {
        json = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        json = await File(file.path!).readAsString();
      } else {
        throw Exception('无法读取文件');
      }

      // 4. 解析文件预览（暂时不使用，但验证文件格式）
      await loroParseFile(data: json);

      // 5. 调用 Rust FFI 合并数据
      final countBigInt = await loroImportMerge(data: json);
      final count = countBigInt.toInt();

      return count;
    } catch (e) {
      rethrow;
    }
  }

  /// 获取文件预览信息
  static Future<FilePreview> getFilePreview(String json) async {
    return loroParseFile(data: json);
  }
}
