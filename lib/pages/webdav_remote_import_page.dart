// 文件说明：WebDAV 远程导入页面，用于浏览云端目录并导入书籍。
// 技术要点：Flutter UI、文件系统。

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:xxread/models/book.dart';
import 'package:xxread/services/library/library_event_bus_service.dart';
import 'package:xxread/services/sync/webdav_sync_service.dart';
import 'package:xxread/utils/page_style_helper.dart';
import 'package:xxread/utils/ui_style.dart';
import 'package:xxread/widgets/side_toast.dart';

class WebDavRemoteImportPage extends StatefulWidget {
  const WebDavRemoteImportPage({super.key});

  @override
  State<WebDavRemoteImportPage> createState() => _WebDavRemoteImportPageState();
}

class _WebDavRemoteImportPageState extends State<WebDavRemoteImportPage> {
  final _service = WebDavSyncService();

  List<Book> _remoteBooks = const <Book>[];
  final Set<String> _selectedKeys = <String>{};
  bool _isLoading = true;
  bool _isImporting = false;
  String _error = '';
  String _progress = '';

  bool get _isMaterial3Style {
    return Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;
  }

  BoxDecoration _panelDecoration({
    double glassAlpha = 0.88,
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
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadRemoteBooks();
  }

  String _keyOf(Book book) {
    return '${book.id ?? ''}|${book.filePath}|${book.title}|${book.author}|${book.importDate.millisecondsSinceEpoch}';
  }

  Future<void> _loadRemoteBooks() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final books = await _service.listRemoteBooksForImport();
      if (!mounted) return;
      setState(() {
        _remoteBooks = books;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _importSelected() async {
    if (_selectedKeys.isEmpty) {
      showSideToast(context, '请先选择要导入的书籍');
      return;
    }
    if (_isImporting) {
      return;
    }

    setState(() {
      _isImporting = true;
      _progress = '准备导入...';
    });

    int imported = 0;
    try {
      final selected = _remoteBooks
          .where((book) => _selectedKeys.contains(_keyOf(book)))
          .toList();
      for (int i = 0; i < selected.length; i++) {
        if (!mounted) return;
        setState(() {
          _progress = '导入 ${i + 1}/${selected.length}: ${selected[i].title}';
        });
        final inserted = await _service.importRemoteBook(selected[i]);
        if (inserted != null) {
          imported++;
        }
      }

      if (!mounted) return;
      LibraryEventBus().notifyLibraryChanged();
      showSideToast(context, '导入完成：$imported 本');
      Navigator.pop(context, imported);
    } catch (e) {
      if (!mounted) return;
      showSideToast(context, '导入失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _progress = '';
        });
      }
    }
  }

  void _toggleAll(bool selected) {
    setState(() {
      if (selected) {
        _selectedKeys
          ..clear()
          ..addAll(_remoteBooks.map(_keyOf));
      } else {
        _selectedKeys.clear();
      }
    });
  }

  void _toggleBook(Book book) {
    final key = _keyOf(book);
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
  }

  String _formatImportDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays <= 0) return '今天';
    if (diff.inDays == 1) return '昨天';
    return '${date.month}月${date.day}日';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = PageStyleHelper.palette(context);
    final allSelected =
        _remoteBooks.isNotEmpty && _selectedKeys.length == _remoteBooks.length;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              if (_isImporting) _buildProgressBanner(),
              if (_isLoading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _buildBody(allSelected, palette),
                ),
              ),
              _buildBottomActionBar(scheme, palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _isImporting ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WebDAV 远端导入',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  '同步封面 + 书籍文件，导入后可直接阅读',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isLoading || _isImporting ? null : _loadRemoteBooks,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBanner() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(
            alpha: _isMaterial3Style ? 0.72 : 0.45,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.primary.withValues(
              alpha: _isMaterial3Style ? 0.34 : 0.18,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _progress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool allSelected, PageVisualPalette palette) {
    final scheme = Theme.of(context).colorScheme;
    if (_error.isNotEmpty) {
      return Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _panelDecoration(
            radius: 16,
            color: _isMaterial3Style
                ? scheme.errorContainer.withValues(alpha: 0.36)
                : palette.cardStrong,
            borderAlpha: 0.24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, color: scheme.error, size: 28),
              const SizedBox(height: 8),
              Text(
                '加载失败',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isImporting ? null : _loadRemoteBooks,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_remoteBooks.isEmpty && !_isLoading) {
      return Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: _panelDecoration(
            radius: 16,
            color: palette.cardStrong,
            borderAlpha: 0.14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 30,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
              ),
              const SizedBox(height: 8),
              Text(
                '远端没有可导入书籍',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: _panelDecoration(
            radius: 14,
            color: palette.cardStrong,
            borderAlpha: 0.14,
          ),
          child: Row(
            children: [
              Checkbox(
                value: allSelected,
                onChanged:
                    _isImporting ? null : (value) => _toggleAll(value ?? false),
              ),
              Expanded(
                child: Text(
                  '全选 ${_selectedKeys.length}/${_remoteBooks.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                '远端书籍',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: _remoteBooks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final book = _remoteBooks[index];
              final key = _keyOf(book);
              final selected = _selectedKeys.contains(key);
              return _buildBookCard(book, selected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBookCard(Book book, bool selected) {
    final scheme = Theme.of(context).colorScheme;
    final palette = PageStyleHelper.palette(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _isImporting ? null : () => _toggleBook(book),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        decoration: BoxDecoration(
          color: selected
              ? (_isMaterial3Style
                  ? scheme.secondaryContainer
                  : scheme.primaryContainer.withValues(alpha: 0.34))
              : (_isMaterial3Style ? scheme.surfaceContainerLow : palette.card),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(
                    alpha: _isMaterial3Style ? 0.42 : 0.38,
                  )
                : scheme.outline.withValues(
                    alpha: _isMaterial3Style ? 0.2 : 0.12,
                  ),
          ),
        ),
        child: Row(
          children: [
            _buildBookCover(book),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author.isEmpty ? '未知作者' : book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${book.format.toUpperCase()} · ${_formatImportDate(book.importDate)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: selected,
              onChanged: _isImporting ? null : (_) => _toggleBook(book),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCover(Book book) {
    final coverPath = (book.coverImagePath ?? '').trim();
    final coverFile = coverPath.isEmpty ? null : File(coverPath);
    final hasLocalCover = coverFile != null && coverFile.existsSync();
    final borderRadius = BorderRadius.circular(10);
    if (hasLocalCover) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(
          coverFile,
          width: 44,
          height: 62,
          fit: Platform.isAndroid ? BoxFit.contain : BoxFit.cover,
        ),
      );
    }
    return _RemoteBookFallbackCover(book: book);
  }

  Widget _buildBottomActionBar(ColorScheme scheme, PageVisualPalette palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: _isMaterial3Style
            ? scheme.surfaceContainerHigh
            : palette.cardStrong,
        border: Border(
          top: BorderSide(
            color: scheme.outline
                .withValues(alpha: _isMaterial3Style ? 0.24 : 0.12),
            width: 0.6,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed:
                _isImporting || _remoteBooks.isEmpty ? null : _importSelected,
            icon: Icon(
                _isImporting ? Icons.sync_rounded : Icons.download_rounded),
            label: Text(_isImporting ? '导入中...' : '导入选中书籍'),
          ),
        ),
      ),
    );
  }
}

class _RemoteBookFallbackCover extends StatelessWidget {
  final Book book;

  const _RemoteBookFallbackCover({required this.book});

  @override
  Widget build(BuildContext context) {
    final seed = '${book.title}|${book.author}|${book.format}'.hashCode.abs();
    final colors = _palette(seed);
    final title = book.title.trim();
    final initial = title.isNotEmpty ? title.characters.first : '书';
    return Container(
      width: 44,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<Color> _palette(int seed) {
    const groups = <List<Color>>[
      [Color(0xFF2C5AA0), Color(0xFF4C8BF5)],
      [Color(0xFF1D6F5F), Color(0xFF2FBF9F)],
      [Color(0xFF8A3E2E), Color(0xFFD9745B)],
      [Color(0xFF5B3B8C), Color(0xFF8D69C8)],
      [Color(0xFF4A4A2E), Color(0xFF9E9B5F)],
      [Color(0xFF2E4A73), Color(0xFF5C86C2)],
    ];
    return groups[seed % groups.length];
  }
}
