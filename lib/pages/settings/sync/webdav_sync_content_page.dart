import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xxread/services/sync/sync_models.dart';
import 'package:xxread/services/sync/webdav_sync_controller.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';
import 'package:xxread/widgets/side_toast.dart';

import 'webdav_sync_translator.dart';

class WebDavSyncContentPage extends StatefulWidget {
  const WebDavSyncContentPage({super.key});

  @override
  State<WebDavSyncContentPage> createState() => _WebDavSyncContentPageState();
}

class _WebDavSyncContentPageState extends State<WebDavSyncContentPage> {
  late WebDavSyncScope _scope;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _scope = context.read<WebDavSyncController>().scope;
  }

  Future<void> _updateScope(WebDavSyncScope next) async {
    if (_saving) return;
    final previous = _scope;
    setState(() {
      _scope = next;
      _saving = true;
    });
    try {
      await context.read<WebDavSyncController>().setScope(next);
    } on WebDavSyncFailure catch (error) {
      if (!mounted) return;
      setState(() => _scope = previous);
      showSideToast(
        context,
        webDavSyncErrorText(context, error.code),
        kind: SideToastKind.error,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _scope = previous);
      showSideToast(
        context,
        webDavSyncErrorText(context, WebDavSyncErrorCode.unknown),
        kind: SideToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sync = context.watch<WebDavSyncController>();
    final palette = PageStyleHelper.palette(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.webDavSyncContent),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 20),
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Material(
                    color: palette.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: palette.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          _ScopeSwitch(
                            title: l10n.webDavScopeBooks,
                            icon: Icons.library_books_outlined,
                            value: _scope.books,
                            enabled: !_saving,
                            onChanged: (value) =>
                                _updateScope(_scope.copyWith(books: value)),
                          ),
                          _ScopeSwitch(
                            title: l10n.webDavScopeProgress,
                            icon: Icons.auto_stories_outlined,
                            value: _scope.progress,
                            enabled: !_saving,
                            onChanged: (value) =>
                                _updateScope(_scope.copyWith(progress: value)),
                          ),
                          _ScopeSwitch(
                            title: l10n.webDavScopeBookmarks,
                            icon: Icons.bookmark_border_rounded,
                            value: _scope.bookmarks,
                            enabled: !_saving,
                            onChanged: (value) =>
                                _updateScope(_scope.copyWith(bookmarks: value)),
                          ),
                          _ScopeSwitch(
                            title: l10n.webDavScopeReadingSessions,
                            icon: Icons.bar_chart_rounded,
                            value: _scope.readingSessions,
                            enabled: !_saving,
                            onChanged: (value) => _updateScope(
                              _scope.copyWith(readingSessions: value),
                            ),
                          ),
                          _ScopeSwitch(
                            title: l10n.webDavScopeBookFiles,
                            subtitle: sync.fileCapabilities.uploadSupported
                                ? l10n.webDavBookFilesHint
                                : l10n.webDavBookFilesUnavailable,
                            icon: Icons.cloud_upload_outlined,
                            value:
                                _scope.bookFiles &&
                                sync.fileCapabilities.uploadSupported,
                            enabled:
                                !_saving &&
                                sync.fileCapabilities.uploadSupported,
                            onChanged: (value) =>
                                _updateScope(_scope.copyWith(bookFiles: value)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeSwitch extends StatelessWidget {
  const _ScopeSwitch({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}
