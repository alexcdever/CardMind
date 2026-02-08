import 'package:flutter/material.dart';

/// Pool 创建屏幕
///
/// 允许用户创建新的数据池。
class PoolCreateScreen extends StatefulWidget {
  const PoolCreateScreen({super.key});

  @override
  State<PoolCreateScreen> createState() => _PoolCreateScreenState();
}

class _PoolCreateScreenState extends State<PoolCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _secretkeyController = TextEditingController();
  final _confirmSecretkeyController = TextEditingController();
  bool _isLoading = false;
  bool _obscureSecretkey = true;
  bool _obscureConfirmSecretkey = true;

  @override
  void dispose() {
    _nameController.dispose();
    _secretkeyController.dispose();
    _confirmSecretkeyController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: 实现创建 Pool 的逻辑
      // 调用 Rust API 创建 Pool
      await Future<void>.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('数据池创建成功')));

      Navigator.of(context).pop(true);
    } on Exception catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('创建失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入池名称';
    }
    if (value.length > 64) {
      return '池名称不能超过 64 个字符';
    }
    return null;
  }

  String? _validateSecretkey(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入 secretkey';
    }
    return null;
  }

  String? _validateConfirmSecretkey(String? value) {
    if (value == null || value.isEmpty) {
      return '请确认 secretkey';
    }
    if (value != _secretkeyController.text) {
      return '两次输入的 secretkey 不一致';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('创建数据池'), centerTitle: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text('创建新的数据池', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  '创建数据池后，您可以邀请其他设备加入',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: '池名称',
                    hintText: '例如：家庭笔记',
                    prefixIcon: const Icon(Icons.pool),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLength: 64,
                  validator: _validateName,
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _secretkeyController,
                  decoration: InputDecoration(
                    labelText: 'secretkey',
                    hintText: '请输入 secretkey',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureSecretkey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(
                          () => _obscureSecretkey = !_obscureSecretkey,
                        );
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: _obscureSecretkey,
                  maxLength: 64,
                  validator: _validateSecretkey,
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmSecretkeyController,
                  decoration: InputDecoration(
                    labelText: '确认 secretkey',
                    hintText: '再次输入 secretkey',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmSecretkey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(
                          () => _obscureConfirmSecretkey =
                              !_obscureConfirmSecretkey,
                        );
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: _obscureConfirmSecretkey,
                  maxLength: 64,
                  validator: _validateConfirmSecretkey,
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleCreate(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreate,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('创建', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('取消', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
