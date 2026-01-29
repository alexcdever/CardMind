import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cardmind/services/qr_code_parser.dart';

/// 二维码扫描回调
typedef OnQRCodeScanned = Future<void> Function(QRCodeData qrData);

/// 错误类型
enum QRUploadErrorType {
  filePermission,
  fileSize,
  invalidFormat,
  parseError,
  networkError,
  unknown,
}

/// 错误信息类
class QRUploadError {
  final QRUploadErrorType type;
  final String message;
  final String? suggestion;
  final dynamic originalError;

  QRUploadError({
    required this.type,
    required this.message,
    this.suggestion,
    this.originalError,
  });

  /// 从异常创建错误
  factory QRUploadError.fromException(dynamic error) {
    if (error is FileSystemException) {
      return QRUploadError(
        type: QRUploadErrorType.filePermission,
        message: '无法访问文件',
        suggestion: '请检查文件权限，确保应用有读取文件的权限',
        originalError: error,
      );
    } else if (error.toString().contains('文件过大')) {
      return QRUploadError(
        type: QRUploadErrorType.fileSize,
        message: '文件过大',
        suggestion: '请选择小于 10MB 的文件，或使用图片压缩工具减小文件大小',
        originalError: error,
      );
    } else if (error.toString().contains('不支持的文件格式') ||
        error.toString().contains('无法解析')) {
      return QRUploadError(
        type: QRUploadErrorType.invalidFormat,
        message: '文件格式不正确或无法解析二维码',
        suggestion: '请确保文件是有效的二维码图片（PNG、JPG 或 SVG 格式）',
        originalError: error,
      );
    } else {
      return QRUploadError(
        type: QRUploadErrorType.unknown,
        message: error.toString().replaceAll('Exception: ', ''),
        suggestion: '请重试，如果问题持续存在，请联系技术支持',
        originalError: error,
      );
    }
  }
}

/// 二维码上传标签页
///
/// 支持文件选择和拖拽上传二维码图片。
class QRCodeUploadTab extends StatefulWidget {
  const QRCodeUploadTab({super.key, required this.onQRCodeScanned});

  final OnQRCodeScanned onQRCodeScanned;

  @override
  State<QRCodeUploadTab> createState() => _QRCodeUploadTabState();
}

class _QRCodeUploadTabState extends State<QRCodeUploadTab> {
  bool _isDragging = false;
  bool _isProcessing = false;
  QRUploadError? _error;
  File? _selectedFile;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  /// 处理文件选择
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'svg'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await _processFile(file);
      }
    } on FileSystemException catch (e) {
      _logError('文件选择权限错误', e);
      setState(() {
        _error = QRUploadError.fromException(e);
      });
    } catch (e) {
      _logError('文件选择失败', e);
      setState(() {
        _error = QRUploadError(
          type: QRUploadErrorType.unknown,
          message: '文件选择失败',
          suggestion: '请重试或尝试使用拖拽方式上传文件',
          originalError: e,
        );
      });
    }
  }

  /// 处理拖拽的文件
  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() {
      _isDragging = false;
    });

    if (details.files.isEmpty) {
      return;
    }

    // 只处理第一个文件
    final file = File(details.files.first.path);

    // 检查文件扩展名
    final extension = file.path.split('.').last.toLowerCase();
    if (!['png', 'jpg', 'jpeg', 'svg'].contains(extension)) {
      _logError('不支持的文件格式', 'Extension: $extension');
      setState(() {
        _error = QRUploadError(
          type: QRUploadErrorType.invalidFormat,
          message: '不支持的文件格式',
          suggestion: '请选择 PNG、JPG 或 SVG 格式的二维码图片',
        );
      });
      return;
    }

    await _processFile(file);
  }

  /// 处理文件
  Future<void> _processFile(File file) async {
    setState(() {
      _isProcessing = true;
      _error = null;
      _selectedFile = file;
    });

    try {
      // 检查文件是否存在
      if (!await file.exists()) {
        throw FileSystemException('文件不存在', file.path);
      }

      // 检查文件大小（10MB 限制）
      final fileSize = await file.length();
      final fileSizeMB = fileSize / (1024 * 1024);
      _logInfo('文件大小: ${fileSizeMB.toStringAsFixed(2)} MB');

      if (fileSize > 10 * 1024 * 1024) {
        throw Exception(
          '文件过大（${fileSizeMB.toStringAsFixed(2)} MB），请选择小于 10MB 的文件',
        );
      }

      // 解析二维码
      _logInfo('开始解析二维码: ${file.path}');
      final qrData = await QRCodeParser.parseFromFile(file);
      _logInfo('二维码解析成功: PeerId=${qrData.peerId}');

      // 调用回调
      await widget.onQRCodeScanned(qrData);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _retryCount = 0; // 重置重试计数
        });
        _logInfo('二维码处理完成');
      }
    } on FileSystemException catch (e) {
      _logError('文件访问权限错误', e);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = QRUploadError.fromException(e);
        });
      }
    } catch (e) {
      _logError('文件处理失败', e);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = QRUploadError.fromException(e);
        });
      }
    }
  }

  /// 重试处理文件
  Future<void> _retryProcessFile() async {
    if (_selectedFile == null || _retryCount >= _maxRetries) {
      return;
    }

    _retryCount++;
    _logInfo('重试处理文件 (第 $_retryCount 次)');
    await _processFile(_selectedFile!);
  }

  /// 清除错误状态
  void _clearError() {
    setState(() {
      _error = null;
      _selectedFile = null;
      _retryCount = 0;
    });
  }

  /// 记录信息日志
  void _logInfo(String message) {
    debugPrint('[QRCodeUpload] INFO: $message');
  }

  /// 记录错误日志
  void _logError(String message, dynamic error) {
    debugPrint('[QRCodeUpload] ERROR: $message');
    debugPrint('[QRCodeUpload] Details: $error');
    if (error is Error) {
      debugPrint('[QRCodeUpload] StackTrace: ${error.stackTrace}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropTarget(
      onDragEntered: (_) {
        setState(() {
          _isDragging = true;
        });
      },
      onDragExited: (_) {
        setState(() {
          _isDragging = false;
        });
      },
      onDragDone: _handleDrop,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 上传区域
            Expanded(child: _buildUploadArea(theme)),
            const SizedBox(height: 16),

            // 错误消息
            if (_error != null) _buildErrorMessage(theme),

            // 选择文件按钮
            if (!_isProcessing)
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('选择文件'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建上传区域
  Widget _buildUploadArea(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        border: Border.all(
          color: _isDragging
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: _isDragging ? 2 : 1,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
        borderRadius: BorderRadius.circular(12),
        color: _isDragging
            ? theme.colorScheme.primaryContainer.withOpacity(0.1)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      child: _isProcessing
          ? _buildProcessingState(theme)
          : _selectedFile != null
          ? _buildFilePreview(theme)
          : _buildEmptyState(theme),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isDragging ? Icons.file_download : Icons.qr_code_2,
            size: 64,
            color: _isDragging
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            _isDragging ? '释放文件以上传' : '拖拽或点击选择二维码图片文件',
            style: theme.textTheme.titleMedium?.copyWith(
              color: _isDragging
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '支持 PNG、JPG、SVG 格式，最大 10MB',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建处理中状态
  Widget _buildProcessingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '正在解析二维码...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建文件预览
  Widget _buildFilePreview(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            '文件已选择',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFile!.path.split('/').last,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 构建错误消息
  Widget _buildErrorMessage(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 错误标题
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.onErrorContainer,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _error!.message,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // 建议
          if (_error!.suggestion != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: theme.colorScheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!.suggestion!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 操作按钮
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 清除错误按钮
              TextButton.icon(
                onPressed: _clearError,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('清除'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(width: 8),
              // 重试按钮（仅在有文件且未超过最大重试次数时显示）
              if (_selectedFile != null && _retryCount < _maxRetries)
                FilledButton.icon(
                  onPressed: _retryProcessFile,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text('重试 (${_maxRetries - _retryCount})'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.onErrorContainer,
                    foregroundColor: theme.colorScheme.errorContainer,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
