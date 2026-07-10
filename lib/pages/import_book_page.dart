// 文件说明：书籍导入页面，处理本地文件与 WebDAV 导入。
// 技术要点：Flutter UI、文件系统。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../pages/webdav_remote_import_page.dart';
import '../services/books/book_services.dart';
import '../services/sync/webdav_sync_service.dart';
import '../utils/localization_extension.dart';
import '../utils/page_style_helper.dart';
import '../utils/system_ui_helper.dart';
import '../utils/ui_style.dart';
import '../widgets/side_toast.dart';

enum _ImportChannel { local, webdav }

class ImportBookPage extends StatefulWidget {
  const ImportBookPage({super.key});

  @override
  State<ImportBookPage> createState() => _ImportBookPageState();
}

class _ImportBookPageState extends State<ImportBookPage> {
  final _bookDao = BookDao();

  bool _isLoading = false;
  bool _isLoadingRecent = true;
  double _progress = 0.0;
  String _progressMessage = '';
  String _encodingOverride = 'auto';
  _ImportChannel _selectedChannel = _ImportChannel.local;
  Book? _latestImportedBook;

  static const List<Map<String, String>> _encodingOptions = [
    {'label': '自动识别', 'value': 'auto'},
    {'label': 'GBK/GB2312/GB18030', 'value': 'gbk'},
    {'label': 'UTF-8', 'value': 'utf8'},
    {'label': 'UTF-16 LE', 'value': 'utf16le'},
    {'label': 'UTF-16 BE', 'value': 'utf16be'},
  ];

  bool get _isMaterial3Style {
    return Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;
  }

  BoxDecoration _panelDecoration({
    double glassAlpha = 0.9,
    double radius = 16,
    double borderAlpha = 0.12,
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: color ??
          (_isMaterial3Style
              ? scheme.surfaceContainerLow
              : scheme.surface.withValues(alpha: glassAlpha)),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: scheme.outline.withValues(
          alpha: _isMaterial3Style ? 0.22 : borderAlpha,
        ),
        width: 0.9,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLatestImportedBook();
  }

  Future<void> _loadLatestImportedBook() async {
    setState(() => _isLoadingRecent = true);
    try {
      final books = await _bookDao.getAllBooks();
      if (!mounted) return;
      setState(() {
        _latestImportedBook = books.isNotEmpty ? books.first : null;
        _isLoadingRecent = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingRecent = false);
    }
  }

  void _onChannelSelected(_ImportChannel channel) {
    setState(() => _selectedChannel = channel);
  }

  Future<void> _startImport() async {
    switch (_selectedChannel) {
      case _ImportChannel.local:
        await _pickFile();
        break;
      case _ImportChannel.webdav:
        await _importFromWebDav();
        break;
    }
  }

  Future<void> _importFromWebDav() async {
    final webDavService = WebDavSyncService();
    if (!webDavService.isConfigured) {
      showSideToast(context, '请先在设置中完成 WebDAV 配置');
      return;
    }

    final importedCount = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => const WebDavRemoteImportPage(),
      ),
    );

    if (!mounted) return;
    if ((importedCount ?? 0) > 0) {
      await _loadLatestImportedBook();
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  String _formatImportDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    if (diff.inDays == 0) return '今天 $hh:$mm';
    if (diff.inDays == 1) return '昨天 $hh:$mm';
    return '${date.month}月${date.day}日 $hh:$mm';
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _progress = 0.0;
      _progressMessage = '准备导入...';
    });

    try {
      final book = await BookImportService().importBook(
        encodingOverride:
            _encodingOverride == 'auto' ? null : _encodingOverride,
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
        await _loadLatestImportedBook();
        if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayStyle = SystemUiHelper.overlayStyleForBrightness(
      Theme.of(context).brightness,
    );
    final palette = PageStyleHelper.palette(context);
    final backgroundGradient = _buildBackgroundGradient(
      scheme: scheme,
      isDark: isDark,
    );
    final actionBarColor = _isMaterial3Style
        ? scheme.surfaceContainerHigh
        : isDark
            ? palette.cardStrong
            : const Color(0xFFF7F9FD).withValues(alpha: 0.92);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: Container(
          decoration: BoxDecoration(
            gradient: backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _buildHeader(),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('导入来源'),
                        const SizedBox(height: 10),
                        _buildImportChannelSelector(),
                        const SizedBox(height: 16),
                        _buildUploadCard(),
                        if (_selectedChannel == _ImportChannel.local) ...[
                          const SizedBox(height: 12),
                          _buildEncodingCard(),
                        ],
                        const SizedBox(height: 12),
                        _buildTipsCard(),
                        const SizedBox(height: 12),
                        _buildSectionLabel('最近导入'),
                        const SizedBox(height: 8),
                        _buildRecentImportCard(),
                        if (_isLoading) ...[
                          const SizedBox(height: 12),
                          _buildProgressCard(),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildBottomActionBar(scheme, actionBarColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _buildBackgroundGradient({
    required ColorScheme scheme,
    required bool isDark,
  }) {
    if (isDark || _isMaterial3Style) {
      return PageStyleHelper.backgroundGradient(context);
    }

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.3, 1.0],
      colors: [
        Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.08),
          const Color(0xFFF7F9FD),
        ),
        Color.alphaBlend(
          scheme.secondary.withValues(alpha: 0.04),
          const Color(0xFFF8FAFE),
        ),
        const Color(0xFFFCFDFF),
      ],
    );
  }

  Widget _buildBottomActionBar(ColorScheme scheme, Color actionBarColor) {
    final actionLabel = switch (_selectedChannel) {
      _ImportChannel.local => '选择文件并导入',
      _ImportChannel.webdav => '从 WebDAV 远端导入',
    };
    final actionIcon = switch (_selectedChannel) {
      _ImportChannel.local => Icons.file_open_rounded,
      _ImportChannel.webdav => Icons.cloud_download_rounded,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: actionBarColor,
        border: Border(
          top: BorderSide(
            color: scheme.outline.withValues(
              alpha: _isMaterial3Style ? 0.24 : 0.12,
            ),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _startImport,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: Icon(actionIcon, size: 20),
            label: Text(
              _isLoading ? '导入中...' : actionLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.pop(context),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.82),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.importBooks,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              '支持 TXT / EPUB / PDF / MOBI / AZW / AZW3 / FB2 / RTF / DOCX',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImportChannelSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildChannelChip(
            label: '本地文件',
            channel: _ImportChannel.local,
            icon: Icons.file_present_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildChannelChip(
            label: 'WebDAV',
            channel: _ImportChannel.webdav,
            icon: Icons.cloud_sync_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildChannelChip({
    required String label,
    required _ImportChannel channel,
    required IconData icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedChannel == channel;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isLoading ? null : () => _onChannelSelected(channel),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? (_isMaterial3Style
                  ? scheme.secondaryContainer
                  : scheme.primary.withValues(alpha: 0.18))
              : (_isMaterial3Style
                  ? scheme.surfaceContainerLow
                  : scheme.surface.withValues(alpha: 0.88)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(
                    alpha: _isMaterial3Style ? 0.42 : 0.3,
                  )
                : scheme.outline.withValues(
                    alpha: _isMaterial3Style ? 0.2 : 0.12,
                  ),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard() {
    final scheme = Theme.of(context).colorScheme;
    final cardTitle = switch (_selectedChannel) {
      _ImportChannel.local => '拖拽或点击上传',
      _ImportChannel.webdav => '浏览 WebDAV 远端书籍',
    };
    final cardDesc = switch (_selectedChannel) {
      _ImportChannel.local => '导入后自动生成目录与分页，支持较大文件分段处理。',
      _ImportChannel.webdav => '连接你的 WebDAV 云端，选择远端书籍导入到本地书架。',
    };
    final cardButton = switch (_selectedChannel) {
      _ImportChannel.local => '选择文件',
      _ImportChannel.webdav => '打开远端列表',
    };
    final cardIcon = switch (_selectedChannel) {
      _ImportChannel.local => Icons.upload_file_rounded,
      _ImportChannel.webdav => Icons.cloud_sync_outlined,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(
        glassAlpha: 0.9,
        radius: 20,
        borderAlpha: 0.15,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(cardIcon, color: scheme.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  cardTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            cardDesc,
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isLoading ? null : _startImport,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            icon: Icon(cardIcon, size: 20),
            label: Text(
              cardButton,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncodingCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(
        glassAlpha: 0.85,
        radius: 16,
        borderAlpha: 0.12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.tune_rounded, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                '导入选项',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '文本编码',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: _panelDecoration(
              glassAlpha: 0.92,
              radius: 12,
              borderAlpha: 0.2,
              color: _isMaterial3Style
                  ? scheme.surfaceContainerHigh
                  : scheme.surface.withValues(alpha: 0.92),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _encodingOverride,
                isExpanded: true,
                items: _encodingOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option['value'],
                        child: Text(option['label']!,
                            style: const TextStyle(fontSize: 14)),
                      ),
                    )
                    .toList(),
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _encodingOverride = value);
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(
          alpha: _isMaterial3Style
              ? (isDark ? 0.42 : 0.66)
              : (isDark ? 0.15 : 0.2),
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.tertiary.withValues(
            alpha: _isMaterial3Style ? 0.34 : (isDark ? 0.2 : 0.15),
          ),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.lightbulb_outline_rounded,
                    size: 18, color: scheme.tertiary),
              ),
              const SizedBox(width: 10),
              Text(
                '导入建议',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipLine('1. TXT 乱码时可切换编码后重试。'),
          _buildTipLine('2. 首次导入大文件会稍慢，后续打开会明显更快。'),
          _buildTipLine('3. 导入成功后可在书库直接继续阅读。'),
        ],
      ),
    );
  }

  Widget _buildTipLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.84),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w600,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.68),
        ),
      ),
    );
  }

  Widget _buildRecentImportCard() {
    final scheme = Theme.of(context).colorScheme;
    final latestBook = _latestImportedBook;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(
        glassAlpha: 0.88,
        radius: 16,
        borderAlpha: 0.12,
      ),
      child: _isLoadingRecent
          ? const SizedBox(
              height: 56,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            )
          : latestBook == null
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: scheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '暂无导入记录，先导入一本书试试',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              scheme.onSurfaceVariant.withValues(alpha: 0.80),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 46,
                      height: 60,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: (latestBook.coverImagePath != null &&
                              latestBook.coverImagePath!.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(latestBook.coverImagePath!),
                                fit: Platform.isAndroid
                                    ? BoxFit.contain
                                    : BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            latestBook.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatImportDate(latestBook.importDate)} · ${latestBook.format.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.70),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.50),
                    ),
                  ],
                ),
    );
  }

  Widget _buildProgressCard() {
    final scheme = Theme.of(context).colorScheme;
    final progressLabel = (_progress * 100).clamp(0, 100).toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(
        glassAlpha: 0.92,
        radius: 16,
        borderAlpha: 0.12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _progress >= 1.0
                      ? Icons.check_circle_rounded
                      : Icons.sync_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '导入进度',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                '$progressLabel%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _progressMessage,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}
