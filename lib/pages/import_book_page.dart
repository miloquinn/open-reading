// 文件说明：书籍导入页面，处理本地文件与 WebDAV 导入。
// 技术要点：Flutter UI、文件系统。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pages/webdav_remote_import_page.dart';
import '../services/books/book_services.dart';
import '../services/sync/webdav_sync_service.dart';
import '../utils/localization_extension.dart';
import '../utils/system_ui_helper.dart';
import '../widgets/side_toast.dart';

class ImportBookPage extends StatefulWidget {
  const ImportBookPage({super.key});

  @override
  State<ImportBookPage> createState() => _ImportBookPageState();
}

class _ImportBookPageState extends State<ImportBookPage> {
  bool _isLoading = false;
  double _progress = 0.0;
  String _progressMessage = '';

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _progress = 0.0;
      _progressMessage = '准备导入...';
    });

    try {
      final book = await BookImportService().importBook(
        progressCallback: (progress, message) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _progressMessage = message;
            });
          }
        },
      );

      if (book != null && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showSideToast(context, '导入失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _progress = 0.0;
          _progressMessage = '';
        });
      }
    }
  }

  Future<void> _importFromWebDav() async {
    if (!WebDavSyncService().isConfigured) {
      showSideToast(context, '请先在设置中完成 WebDAV 配置');
      return;
    }

    final importedCount = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const WebDavRemoteImportPage()),
    );

    if (!mounted) return;
    if ((importedCount ?? 0) > 0) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overlayStyle = SystemUiHelper.overlayStyleForBrightness(
      Theme.of(context).brightness,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          backgroundColor: scheme.surface,
          scrolledUnderElevation: 0,
          title: Text(context.l10n.importBooks),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImportButton(
                  icon: Icons.file_open_rounded,
                  label: '本地文件',
                  onTap: _pickFile,
                ),
                const SizedBox(height: 12),
                _buildImportButton(
                  icon: Icons.cloud_download_rounded,
                  label: 'WebDAV',
                  onTap: _importFromWebDav,
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 24),
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 8),
                  Text(
                    _progressMessage,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImportButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return FilledButton.tonalIcon(
      onPressed: _isLoading ? null : onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 15)),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
