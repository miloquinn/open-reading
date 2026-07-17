// 文件说明：发现页与搜索页共享的书源书籍展示组件与操作流程。
// 技术要点：Flutter UI、底部弹窗、书架服务调用。

import 'dart:async';

import 'package:flutter/material.dart';

import '../book_sources/models/registered_book_source.dart';
import '../book_sources/protocol/book_source_protocol.dart';
import '../book_sources/services/book_source_client.dart';
import '../book_sources/services/book_source_shelf_service.dart';
import '../utils/book_open_transition.dart';
import '../utils/localization_extension.dart';
import '../utils/page_style_helper.dart';
import '../utils/ui_style.dart';
import '../widgets/generated_book_cover.dart';
import 'book_source_reader_page.dart';

/// 一本来自具体书源的书。
class SourcedBook {
  final RegisteredBookSource source;
  final BookSourceBook book;

  const SourcedBook({required this.source, required this.book});
}

enum _ShelfAddMode { online, local }

BoxDecoration bookSourcePanelDecoration(
  BuildContext context, {
  double radius = 16,
  bool stronger = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  final palette = PageStyleHelper.palette(context);
  final isMaterial3Style =
      Theme.of(context).extension<UiStyleThemeExtension>()?.isMaterial3Style ??
          false;
  return BoxDecoration(
    color: isMaterial3Style
        ? (stronger ? scheme.surfaceContainer : scheme.surfaceContainerLow)
        : (stronger ? palette.cardStrong : palette.card),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: scheme.outline.withValues(alpha: isMaterial3Style ? 0.22 : 0.12),
      width: 0.8,
    ),
  );
}

/// 竖版书籍卡片（封面 + 标题 + 作者），用于发现页横向书架。
class SourcedBookCard extends StatelessWidget {
  final SourcedBook result;
  final VoidCallback onTap;

  const SourcedBookCard({super.key, required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 132,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: result.book.coverUrl == null
                        ? GeneratedBookCover(
                            title: result.book.title,
                            author: result.book.author,
                          )
                        : Image.network(
                            result.book.coverUrl.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => GeneratedBookCover(
                              title: result.book.title,
                              author: result.book.author,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  result.book.author.isEmpty
                      ? result.source.name
                      : result.book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 横版书籍行（封面 + 标题 + 作者/来源 + 简介），用于搜索结果和分类列表。
class SourcedBookListTile extends StatelessWidget {
  final SourcedBook result;
  final VoidCallback onTap;

  const SourcedBookListTile({
    super.key,
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final book = result.book;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: bookSourcePanelDecoration(context, radius: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BookCoverThumb(book: book),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [book.author, result.source.name]
                        .where((item) => item.isNotEmpty)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (book.description.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      book.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _BookCoverThumb extends StatelessWidget {
  final BookSourceBook book;

  const _BookCoverThumb({required this.book});

  @override
  Widget build(BuildContext context) {
    final fallback = SizedBox(
      width: 58,
      height: 78,
      child: GeneratedBookCover(
        title: book.title,
        author: book.author,
      ),
    );
    if (book.coverUrl == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        book.coverUrl.toString(),
        width: 58,
        height: 78,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

/// 书籍详情弹窗与加入书架/下载/阅读的完整流程。
///
/// 发现页与搜索页共用，弹窗只展示面向读者的信息。
class SourcedBookActions {
  final BuildContext context;
  final BookSourceClient client;
  final BookSourceShelfService shelfService;

  const SourcedBookActions({
    required this.context,
    required this.client,
    required this.shelfService,
  });

  void showBookDetails(SourcedBook result) {
    final book = result.book;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    key: const Key('bookSourceDetailsScroll'),
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: Theme.of(sheetContext)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [book.author, result.source.name]
                              .where((item) => item.isNotEmpty)
                              .join(' · '),
                          style: TextStyle(
                            color: Theme.of(sheetContext).colorScheme.primary,
                          ),
                        ),
                        if (book.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            book.description,
                            style: const TextStyle(height: 1.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          key: const Key('bookSourceAddToShelfButton'),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            unawaited(_showAddToShelfOptions(result));
                          },
                          icon: const Icon(Icons.add_to_photos_outlined),
                          label: Text(sheetContext.l10n.bookSourceAddToShelf),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          key: const Key('bookSourceReadButton'),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            // 弹窗里拿不到封面位置，走统一路由的淡入兜底。
                            Navigator.of(context).push(
                              BookOpenTransition.createRoute<void>(
                                BookSourceReaderPage(
                                  source: result.source,
                                  book: book,
                                  client: client,
                                  shelfService: shelfService,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.menu_book_rounded),
                          label: Text(sheetContext.l10n.reading),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddToShelfOptions(SourcedBook result) async {
    final choice = await showModalBottomSheet<_ShelfAddMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(sheetContext.l10n.bookSourceAddOnline),
                subtitle: Text(sheetContext.l10n.bookSourceAddOnlineHint),
                onTap: () => Navigator.pop(sheetContext, _ShelfAddMode.online),
              ),
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: Text(sheetContext.l10n.bookSourceDownloadLocal),
                subtitle: Text(sheetContext.l10n.bookSourceDownloadLocalHint),
                onTap: () => Navigator.pop(sheetContext, _ShelfAddMode.local),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == _ShelfAddMode.online) {
      final existing = await shelfService.findShelfBook(
        sourceId: result.source.id,
        sourceBookId: result.book.id,
      );
      if (existing == null) {
        await shelfService.addOnline(
          source: result.source,
          book: result.book,
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? context.l10n.bookSourceAddedOnline
                : context.l10n.bookSourceAlreadyOnShelf,
          ),
        ),
      );
      return;
    }
    await _downloadSourceBook(result);
  }

  Future<void> _downloadSourceBook(SourcedBook result) async {
    final progress = ValueNotifier<(int, int)>((0, 0));
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(dialogContext.l10n.bookSourceDownloading),
          content: ValueListenableBuilder<(int, int)>(
            valueListenable: progress,
            builder: (context, value, _) {
              final total = value.$2;
              final ratio = total <= 0 ? null : value.$1 / total;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: ratio),
                  const SizedBox(height: 12),
                  Text(
                    total <= 0
                        ? context.l10n.bookSourceFetchingCatalog
                        : context.l10n.bookSourceDownloadProgress(
                            value.$1,
                            total,
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    try {
      await shelfService.downloadToLocal(
        source: result.source,
        book: result.book,
        onProgress: (completed, total) {
          progress.value = (completed, total);
        },
      );
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.bookSourceDownloadComplete)),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.bookSourceDownloadFailed('$error')),
        ),
      );
    } finally {
      progress.dispose();
    }
  }
}
