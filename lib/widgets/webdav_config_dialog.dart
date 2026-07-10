// 文件说明：WebDAV 配置对话框，用于编辑服务器、账号和测试连接。
// 技术要点：Flutter UI、渲染层。

import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/sync/webdav_sync_service.dart';
import '../utils/glass_config.dart';
import '../utils/ui_style.dart';
import 'side_toast.dart';

/// WebDAV配置对话框
class WebDavConfigDialog extends StatefulWidget {
  const WebDavConfigDialog({super.key});

  @override
  State<WebDavConfigDialog> createState() => _WebDavConfigDialogState();
}

class _WebDavConfigDialogState extends State<WebDavConfigDialog> {
  static const List<int> _syncIntervals = [5, 10, 15, 30, 60, 120, 240, 720];

  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final WebDavSyncService _syncService = WebDavSyncService();

  bool _isPasswordVisible = false;
  bool _isWorking = false;
  bool _autoSync = true;
  int _syncInterval = 30;
  String? _statusMessage;
  bool _statusIsError = false;

  bool get _isMaterial3Style {
    return Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;
  }

  bool get _useBlur =>
      !_isMaterial3Style && !GlassEffectConfig.shouldDisableBlur;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  void _loadExistingConfig() {
    if (_syncService.isConfigured) {
      _serverUrlController.text = _syncService.serverUrl;
      _usernameController.text = _syncService.username;
    }
    _autoSync = _syncService.autoSync;
    _syncInterval = _syncService.syncInterval;
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final targetWidth = screenWidth >= 1200
        ? 900.0
        : screenWidth >= 960
            ? 820.0
            : screenWidth >= 760
                ? 700.0
                : screenWidth - 20;

    final dialogSurface = _getDialogSurfaceColor();
    final dialogContent = Container(
      width: targetWidth,
      constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            dialogSurface,
            dialogSurface.withValues(
              alpha: _isMaterial3Style
                  ? 1.0
                  : GlassEffectConfig.effectiveOpacity(0.7),
            ),
          ],
        ),
        border: Border.all(
          color:
              scheme.outline.withValues(alpha: _isMaterial3Style ? 0.24 : 0.2),
          width: _isMaterial3Style ? 1.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow
                .withValues(alpha: _isMaterial3Style ? 0.10 : 0.16),
            blurRadius: _isMaterial3Style ? 16 : 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildForm(),
            if (_statusMessage != null) _buildStatusBanner(),
            _buildActions(),
          ],
        ),
      ),
    );

    final dialogBody = ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: _useBlur
          ? BackdropFilter(
              enabled: _useBlur,
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: dialogContent,
            )
          : dialogContent,
    );

    final dialog = Dialog(
      backgroundColor:
          _isMaterial3Style ? scheme.surfaceContainerHigh : Colors.transparent,
      shadowColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: dialogBody,
    );

    if (!_useBlur) {
      return dialog;
    }

    return BackdropFilter(
      enabled: _useBlur,
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: dialog,
    );
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isMaterial3Style
                  ? scheme.primaryContainer
                  : scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.cloud_sync,
              color: _isMaterial3Style
                  ? scheme.onPrimaryContainer
                  : scheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WebDAV 配置',
                  style: TextStyle(
                    color: _getTextColor(),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '配置服务器后可同步书籍、书签、进度和笔记',
                  style: TextStyle(color: _getSubtitleColor(), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _serverUrlController,
              label: '服务器地址',
              hint: 'https://example.com/webdav/',
              icon: Icons.link,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return '请输入服务器地址';
                }
                final uri = Uri.tryParse(text);
                if (uri == null ||
                    !(uri.scheme == 'http' || uri.scheme == 'https')) {
                  return '请输入有效的 http/https 地址';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _usernameController,
              label: '用户名',
              hint: '输入用户名',
              icon: Icons.person,
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入用户名';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _passwordController,
              label: '密码',
              hint: _syncService.isConfigured ? '留空表示保持不变' : '输入密码',
              icon: Icons.lock,
              isPassword: true,
              validator: (value) {
                if (_syncService.isConfigured) {
                  return null;
                }
                if (value?.trim().isEmpty ?? true) {
                  return '请输入密码';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildSyncPreferenceCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncPreferenceCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getFieldBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              scheme.outline.withValues(alpha: _isMaterial3Style ? 0.22 : 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: _getIconColor(), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '自动同步',
                  style: TextStyle(
                    color: _getTextColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: _autoSync,
                onChanged: _isWorking
                    ? null
                    : (value) {
                        setState(() {
                          _autoSync = value;
                        });
                      },
              ),
            ],
          ),
          Text(
            _autoSync ? '按间隔自动同步，仍可手动同步' : '关闭后仅支持手动同步',
            style: TextStyle(color: _getSubtitleColor(), fontSize: 12),
          ),
          if (_autoSync) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _syncIntervals.map((minutes) {
                final selected = minutes == _syncInterval;
                return ChoiceChip(
                  label: Text('$minutes 分钟'),
                  selected: selected,
                  onSelected: _isWorking
                      ? null
                      : (_) {
                          setState(() {
                            _syncInterval = minutes;
                          });
                        },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final scheme = Theme.of(context).colorScheme;
    final color = _statusIsError ? scheme.error : scheme.tertiary;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            _statusIsError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage ?? '',
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      validator: validator,
      style: TextStyle(color: _getTextColor()),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _getIconColor()),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: _getIconColor(),
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
        labelStyle: TextStyle(color: _getSubtitleColor()),
        hintStyle: TextStyle(color: _getSubtitleColor()),
        filled: true,
        fillColor: _getFieldBackgroundColor(),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
      ),
    );
  }

  Widget _buildActions() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isWorking ? null : _testConnection,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _getIconColor()),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isWorking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('测试连接', style: TextStyle(color: _getTextColor())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isWorking ? null : _saveConfiguration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('保存配置'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isWorking ? null : () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: TextStyle(color: _getSubtitleColor()),
                  ),
                ),
              ),
              if (_syncService.isConfigured) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: _isWorking ? null : _clearConfiguration,
                    child: Text(
                      '清除配置',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isWorking = true;
      _statusMessage = null;
    });

    final success = await _syncService.testConnectionWith(
      serverUrl: _serverUrlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isWorking = false;
      _statusIsError = !success;
      _statusMessage = success
          ? '连接测试成功'
          : (_syncService.lastErrorMessage.isNotEmpty
              ? _syncService.lastErrorMessage
              : '连接测试失败');
    });

    showSideToast(context, _statusMessage!);
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isWorking = true;
      _statusMessage = null;
    });

    final success = await _syncService.configure(
      serverUrl: _serverUrlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      autoSync: _autoSync,
      syncInterval: _syncInterval,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      showSideToast(context, 'WebDAV 配置已保存');
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isWorking = false;
      _statusIsError = true;
      _statusMessage = _syncService.lastErrorMessage.isNotEmpty
          ? _syncService.lastErrorMessage
          : '保存失败，请检查配置后重试';
    });
    showSideToast(context, _statusMessage!);
  }

  Future<void> _clearConfiguration() async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除 WebDAV 配置吗？这将删除同步设置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _syncService.clearConfiguration();
      if (!mounted) return;
      showSideToast(context, 'WebDAV 配置已清除');
      Navigator.pop(context, true);
    }
  }

  Color _getDialogSurfaceColor() {
    final scheme = Theme.of(context).colorScheme;
    if (_isMaterial3Style) {
      return scheme.surfaceContainerHigh;
    }
    return scheme.surface.withValues(
      alpha: GlassEffectConfig.effectiveOpacity(0.82),
    );
  }

  Color _getTextColor() {
    return Theme.of(context).colorScheme.onSurface;
  }

  Color _getSubtitleColor() {
    return Theme.of(context)
        .colorScheme
        .onSurfaceVariant
        .withValues(alpha: 0.8);
  }

  Color _getIconColor() {
    return Theme.of(context)
        .colorScheme
        .onSurfaceVariant
        .withValues(alpha: 0.86);
  }

  Color _getFieldBackgroundColor() {
    final scheme = Theme.of(context).colorScheme;
    return _isMaterial3Style
        ? scheme.surfaceContainer
        : scheme.surface.withValues(alpha: 0.66);
  }
}
