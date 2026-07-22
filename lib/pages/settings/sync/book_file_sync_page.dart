import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/sync/adapters/metadata_sync_adapters.dart';
import 'package:xxread/services/sync/sync_models.dart';
import 'package:xxread/services/sync/webdav_book_file_service.dart';
import 'package:xxread/services/sync/webdav_sync_controller.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';
import 'package:xxread/widgets/side_toast.dart';

import 'webdav_sync_translator.dart';

class BookFileSyncPage extends StatefulWidget {
  const BookFileSyncPage({super.key});

  @override
  State<BookFileSyncPage> createState() => _BookFileSyncPageState();
}

class _BookFileSyncPageState extends State<BookFileSyncPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _selected = <String>{};
  List<_LocalFileEntry> _pendingUpload = const [];
  List<RemoteBookDescriptor> _availableDownload = const [];
  List<_LocalFileEntry> _synced = const [];
  bool _loading = true;
  bool _transferring = false;
  String? _currentTitle;
  double? _currentProgress;
  WebDavSyncErrorCode? _loadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(_selected.clear);
        }
      });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load({bool synchronize = false}) async {
    setState(() => _loading = true);
    final sync = context.read<WebDavSyncController>();
    try {
      if (synchronize) {
        await sync.syncNow();
      } else {
        await sync.refreshRemoteBooks();
      }
      final remoteByUid = {
        for (final item in sync.remoteBooks) item.bookUid: item,
      };
      final localBooks = await BookDao().getAllBooks();
      final local = <_LocalFileEntry>[];
      for (final book in localBooks) {
        if (book.isOnline || book.id == null) continue;
        final file = File(book.filePath);
        if (!await file.exists()) continue;
        final uid = await bookUidForMap(book.toMap());
        final coverBlobSha256 = await _coverBlobSha256(book.coverImagePath);
        local.add(
          _LocalFileEntry(
            book: book,
            bookUid: uid,
            sizeBytes: await file.length(),
            coverBlobSha256: coverBlobSha256,
            remote: remoteByUid[uid],
          ),
        );
      }
      final localUids = local.map((item) => item.bookUid).toSet();
      if (!mounted) return;
      setState(() {
        _pendingUpload =
            local.where((item) => !item.isFullySynced).toList(growable: false);
        _synced =
            local.where((item) => item.isFullySynced).toList(growable: false);
        _availableDownload = remoteByUid.values
            .where(
              (item) => item.fileAvailable && !localUids.contains(item.bookUid),
            )
            .toList(growable: false);
        _selected.clear();
        _loadError = null;
        _loading = false;
      });
    } on WebDavSyncFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.code;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = WebDavSyncErrorCode.unknown;
        _loading = false;
      });
    }
  }

  List<String> get _visibleIds => switch (_tabController.index) {
        0 => _pendingUpload
            .where(
              (item) =>
                  item.sizeBytes <=
                  WebDavBookFileService.maxRecoverableFileBytes,
            )
            .map((item) => item.bookUid)
            .toList(),
        1 => _availableDownload
            .where(
              (item) =>
                  (item.sizeBytes ?? 0) <=
                  WebDavBookFileService.maxRecoverableFileBytes,
            )
            .map((item) => item.bookUid)
            .toList(),
        _ => const <String>[],
      };

  int get _selectedBytes {
    if (_tabController.index == 0) {
      return _pendingUpload
          .where((item) => _selected.contains(item.bookUid))
          .fold(0, (sum, item) => sum + item.sizeBytes);
    }
    if (_tabController.index == 1) {
      return _availableDownload
          .where((item) => _selected.contains(item.bookUid))
          .fold(0, (sum, item) => sum + (item.sizeBytes ?? 0));
    }
    return 0;
  }

  void _toggle(String uid, bool selected) {
    setState(() => selected ? _selected.add(uid) : _selected.remove(uid));
  }

  void _selectAll() {
    if (_tabController.index == 0 &&
        !context.read<WebDavSyncController>().scope.bookFiles) {
      return;
    }
    setState(() {
      final ids = _visibleIds;
      if (ids.isEmpty) return;
      if (ids.every(_selected.contains)) {
        _selected.removeAll(ids);
      } else {
        _selected.addAll(ids);
      }
    });
  }

  Future<void> _transferSelected() async {
    if (_selected.isEmpty || _transferring) return;
    setState(() => _transferring = true);
    final sync = context.read<WebDavSyncController>();
    try {
      if (_tabController.index == 0) {
        final items = _pendingUpload
            .where((item) => _selected.contains(item.bookUid))
            .toList();
        for (final item in items) {
          if (item.sizeBytes > WebDavBookFileService.maxRecoverableFileBytes) {
            continue;
          }
          setState(() {
            _currentTitle = item.book.title;
            _currentProgress = 0;
          });
          await sync.uploadBookFile(
            item.book,
            onProgress: (progress) {
              if (mounted) setState(() => _currentProgress = progress.fraction);
            },
          );
        }
      } else if (_tabController.index == 1) {
        final items = _availableDownload
            .where((item) => _selected.contains(item.bookUid))
            .toList();
        for (final item in items) {
          if ((item.sizeBytes ?? 0) >
              WebDavBookFileService.maxRecoverableFileBytes) {
            continue;
          }
          setState(() {
            _currentTitle = item.title;
            _currentProgress = 0;
          });
          await sync.downloadBookFile(
            item,
            onProgress: (progress) {
              if (mounted) setState(() => _currentProgress = progress.fraction);
            },
          );
        }
      }
      if (mounted) {
        showSideToast(
          context,
          context.l10n.webDavFilesTransferComplete,
          kind: SideToastKind.success,
        );
      }
      await _load();
    } on WebDavSyncFailure catch (error) {
      if (mounted) {
        showSideToast(
          context,
          webDavSyncErrorText(context, error.code),
          kind: SideToastKind.error,
        );
        await _load();
      }
    } finally {
      if (mounted) {
        setState(() {
          _transferring = false;
          _currentTitle = null;
          _currentProgress = null;
        });
      }
    }
  }

  Future<void> _pickNewBookPolicy(WebDavSyncController sync) async {
    final selected = await showModalBottomSheet<WebDavNewBookUploadPolicy>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Text(
                context.l10n.webDavNewBookPolicyTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            for (final policy in WebDavNewBookUploadPolicy.values)
              ListTile(
                leading: Icon(_newBookPolicyIcon(policy)),
                title: Text(_newBookPolicyTitle(context, policy)),
                subtitle: Text(_newBookPolicyHint(context, policy)),
                trailing: sync.newBookUploadPolicy == policy
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(policy),
              ),
          ],
        ),
      ),
    );
    if (selected != null) await sync.setNewBookUploadPolicy(selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sync = context.watch<WebDavSyncController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.webDavBookFilesTitle),
        actions: [
          IconButton(
            tooltip:
                MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
            onPressed: _loading || _transferring
                ? null
                : () => _load(synchronize: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).selectAllButtonLabel,
            onPressed: _loading || _transferring ? null : _selectAll,
            icon: const Icon(Icons.select_all_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.webDavFilesPendingUpload),
            Tab(text: l10n.webDavFilesAvailableDownload),
            Tab(text: l10n.webDavFilesSynced),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _LoadFailure(
                    message: webDavSyncErrorText(context, _loadError!),
                    onRetry: () => _load(synchronize: true),
                  )
                : Column(
                    children: [
                      if (_tabController.index == 0)
                        _UploadPermissionCard(
                          enabled: sync.scope.bookFiles,
                          policy: sync.newBookUploadPolicy,
                          onChanged: _transferring
                              ? null
                              : (enabled) async {
                                  if (!enabled) setState(_selected.clear);
                                  await sync.setScope(
                                    sync.scope.copyWith(bookFiles: enabled),
                                  );
                                },
                          onPolicyTap: _transferring || !sync.scope.bookFiles
                              ? null
                              : () => _pickNewBookPolicy(sync),
                        ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _LocalFilesList(
                              items: _pendingUpload,
                              selected: _selected,
                              onToggle: _toggle,
                              emptyText: l10n.webDavFilesEmpty,
                              selectable: sync.scope.bookFiles,
                            ),
                            _RemoteFilesList(
                              items: _availableDownload,
                              selected: _selected,
                              onToggle: _toggle,
                              emptyText: l10n.webDavFilesEmpty,
                            ),
                            _LocalFilesList(
                              items: _synced,
                              selected: const {},
                              onToggle: (_, __) {},
                              emptyText: l10n.webDavFilesEmpty,
                              selectable: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
      bottomNavigationBar: _selected.isEmpty && !_transferring
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_transferring) ...[
                      Text(_currentTitle ?? l10n.webDavSyncing),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: _currentProgress),
                      const SizedBox(height: 10),
                    ],
                    FilledButton.icon(
                      onPressed: _transferring ? null : _transferSelected,
                      icon: Icon(
                        _tabController.index == 1
                            ? Icons.download_rounded
                            : Icons.upload_rounded,
                      ),
                      label: Text(
                        _transferring
                            ? l10n.webDavSyncing
                            : '${l10n.webDavFilesSelectedSummary(_selected.length, _formatBytes(_selectedBytes))} · ${_tabController.index == 1 ? l10n.webDavFilesDownloadSelected : l10n.webDavFilesUploadSelected}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(MaterialLocalizations.of(context)
                  .refreshIndicatorSemanticLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadPermissionCard extends StatelessWidget {
  const _UploadPermissionCard({
    required this.enabled,
    required this.policy,
    required this.onChanged,
    required this.onPolicyTap,
  });

  final bool enabled;
  final WebDavNewBookUploadPolicy policy;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onPolicyTap;

  @override
  Widget build(BuildContext context) {
    final palette = PageStyleHelper.palette(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SwitchListTile(
              value: enabled,
              onChanged: onChanged,
              secondary: const Icon(Icons.cloud_upload_outlined),
              title: Text(context.l10n.webDavFilesUploadPermission),
              subtitle: Text(context.l10n.webDavFilesUploadPermissionHint),
            ),
            const Divider(height: 1),
            ListTile(
              enabled: enabled,
              onTap: onPolicyTap,
              leading: Icon(_newBookPolicyIcon(policy)),
              title: Text(context.l10n.webDavNewBookPolicyTitle),
              subtitle: Text(_newBookPolicyTitle(context, policy)),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _newBookPolicyIcon(WebDavNewBookUploadPolicy policy) =>
    switch (policy) {
      WebDavNewBookUploadPolicy.askEveryTime => Icons.help_outline_rounded,
      WebDavNewBookUploadPolicy.automatic => Icons.cloud_upload_outlined,
      WebDavNewBookUploadPolicy.manual => Icons.touch_app_outlined,
    };

String _newBookPolicyTitle(
  BuildContext context,
  WebDavNewBookUploadPolicy policy,
) =>
    switch (policy) {
      WebDavNewBookUploadPolicy.askEveryTime =>
        context.l10n.webDavNewBookPolicyAsk,
      WebDavNewBookUploadPolicy.automatic =>
        context.l10n.webDavNewBookPolicyAutomatic,
      WebDavNewBookUploadPolicy.manual =>
        context.l10n.webDavNewBookPolicyManual,
    };

String _newBookPolicyHint(
  BuildContext context,
  WebDavNewBookUploadPolicy policy,
) =>
    switch (policy) {
      WebDavNewBookUploadPolicy.askEveryTime =>
        context.l10n.webDavNewBookPolicyAskHint,
      WebDavNewBookUploadPolicy.automatic =>
        context.l10n.webDavNewBookPolicyAutomaticHint,
      WebDavNewBookUploadPolicy.manual =>
        context.l10n.webDavNewBookPolicyManualHint,
    };

class _LocalFilesList extends StatelessWidget {
  const _LocalFilesList({
    required this.items,
    required this.selected,
    required this.onToggle,
    required this.emptyText,
    this.selectable = true,
  });

  final List<_LocalFileEntry> items;
  final Set<String> selected;
  final void Function(String uid, bool selected) onToggle;
  final String emptyText;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(child: Text(emptyText));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final tooLarge =
            item.sizeBytes > WebDavBookFileService.maxRecoverableFileBytes;
        return _FileTile(
          title: item.book.title,
          subtitle: tooLarge
              ? context.l10n.webDavFilesTooLarge
              : '${item.book.format.toUpperCase()} · ${_formatBytes(item.sizeBytes)} · ${selectable ? context.l10n.webDavFilesOnlyLocal : context.l10n.webDavFilesSynced}',
          selected: selected.contains(item.bookUid),
          selectable: selectable && !tooLarge,
          onChanged: (value) => onToggle(item.bookUid, value),
        );
      },
    );
  }
}

class _RemoteFilesList extends StatelessWidget {
  const _RemoteFilesList({
    required this.items,
    required this.selected,
    required this.onToggle,
    required this.emptyText,
  });

  final List<RemoteBookDescriptor> items;
  final Set<String> selected;
  final void Function(String uid, bool selected) onToggle;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(child: Text(emptyText));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final size = item.sizeBytes ?? 0;
        final tooLarge = size > WebDavBookFileService.maxRecoverableFileBytes;
        return _FileTile(
          title: item.title,
          subtitle: tooLarge
              ? context.l10n.webDavFilesTooLarge
              : '${item.format.toUpperCase()} · ${_formatBytes(size)} · ${context.l10n.webDavFilesOnlyRemote}',
          selected: selected.contains(item.bookUid),
          selectable: !tooLarge,
          onChanged: (value) => onToggle(item.bookUid, value),
        );
      },
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.selectable,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool selectable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = PageStyleHelper.palette(context);
    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: CheckboxListTile(
        value: selected,
        onChanged: selectable ? (value) => onChanged(value ?? false) : null,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle),
        secondary: const Icon(Icons.menu_book_rounded),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}

class _LocalFileEntry {
  const _LocalFileEntry({
    required this.book,
    required this.bookUid,
    required this.sizeBytes,
    required this.coverBlobSha256,
    required this.remote,
  });

  final Book book;
  final String bookUid;
  final int sizeBytes;
  final String? coverBlobSha256;
  final RemoteBookDescriptor? remote;

  bool get isFullySynced {
    final remote = this.remote;
    if (remote == null || !remote.fileAvailable) return false;
    final coverHash = coverBlobSha256;
    if (coverHash == null) return true;
    return remote.coverAvailable && remote.coverBlobSha256 == coverHash;
  }
}

Future<String?> _coverBlobSha256(String? coverImagePath) async {
  if (coverImagePath == null || coverImagePath.trim().isEmpty) return null;
  final file = File(coverImagePath);
  try {
    if (!await file.exists()) return null;
    final size = await file.length();
    if (size <= 0 || size > WebDavBookFileService.maxCoverFileBytes) {
      return null;
    }
    return '${await sha256.bind(file.openRead()).first}';
  } on FileSystemException {
    return null;
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
