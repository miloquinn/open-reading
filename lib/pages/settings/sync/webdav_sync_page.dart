import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:xxread/services/sync/sync_models.dart';
import 'package:xxread/services/sync/webdav_sync_controller.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';

import 'webdav_setup_page.dart';
import 'book_file_sync_page.dart';
import 'webdav_sync_translator.dart';

class WebDavSyncPage extends StatelessWidget {
  const WebDavSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<WebDavSyncController>();
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.webDavPageTitle)),
      body: Container(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              final sections = <Widget>[
                _StatusCard(sync: sync),
                _AutomaticSyncCard(sync: sync),
                _ScopeCard(sync: sync),
                _BookFilesCard(sync: sync),
                _ConnectionCard(sync: sync),
                _SecurityCard(),
              ];
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    children: [
                                      sections[0],
                                      const SizedBox(height: 16),
                                      sections[5],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    children: [
                                      sections[1],
                                      const SizedBox(height: 16),
                                      sections[2],
                                      const SizedBox(height: 16),
                                      sections[3],
                                      const SizedBox(height: 16),
                                      sections[4],
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                for (var i = 0; i < sections.length; i++) ...[
                                  sections[i],
                                  if (i != sections.length - 1)
                                    const SizedBox(height: 16),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.sync});

  final WebDavSyncController sync;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final configured = sync.isConfigured;
    final syncing = sync.status == WebDavSyncStatus.syncing ||
        sync.status == WebDavSyncStatus.testing;
    final failed = sync.status == WebDavSyncStatus.failed ||
        sync.status == WebDavSyncStatus.partialFailure;

    final title = !configured
        ? l10n.webDavNotConfigured
        : failed
            ? (sync.status == WebDavSyncStatus.partialFailure
                ? l10n.webDavPartialFailure
                : l10n.webDavSyncFailed)
            : syncing
                ? l10n.webDavSyncing
                : l10n.webDavConnected;
    final subtitle = !configured
        ? l10n.webDavConfigureSubtitle
        : failed
            ? webDavSyncErrorText(context, sync.lastError)
            : sync.pendingChanges > 0
                ? l10n.webDavPendingChanges(sync.pendingChanges)
                : sync.lastSuccessfulSync == null
                    ? l10n.webDavNeverSynced
                    : l10n.webDavLastSync(
                        DateFormat.yMd(
                          Localizations.localeOf(context).toLanguageTag(),
                        ).add_Hm().format(sync.lastSuccessfulSync!.toLocal()),
                      );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: (failed ? scheme.error : scheme.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: syncing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Icon(
                        failed
                            ? Icons.cloud_off_outlined
                            : configured
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_outlined,
                        color: failed ? scheme.error : scheme.primary,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (configured) ...[
            const SizedBox(height: 12),
            Text(
              '${sync.serverUrl ?? ''} / ${sync.rootPath ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: syncing
                  ? null
                  : configured
                      ? () => sync.syncNow()
                      : () => _openSetup(context),
              icon: Icon(configured ? Icons.sync_rounded : Icons.settings),
              label: Text(
                configured ? l10n.webDavSyncNow : l10n.webDavSetUp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomaticSyncCard extends StatelessWidget {
  const _AutomaticSyncCard({required this.sync});

  final WebDavSyncController sync;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.autorenew_rounded),
        title: Text(context.l10n.webDavAutomaticSync),
        subtitle: Text(context.l10n.webDavAutomaticSyncHint),
        value: sync.autoSync,
        onChanged: sync.isConfigured ? sync.setAutoSync : null,
      ),
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({required this.sync});

  final WebDavSyncController sync;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = <String>[
      if (sync.scope.books) l10n.webDavScopeBooks,
      if (sync.scope.progress) l10n.webDavScopeProgress,
      if (sync.scope.bookmarks || sync.scope.notes) l10n.webDavScopeAnnotations,
      if (sync.scope.readingSessions) l10n.webDavScopeReadingSessions,
    ];
    return _Card(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.sync_alt_rounded),
        title: Text(l10n.webDavSyncContent),
        subtitle: Text(enabled.join(' · ')),
        trailing: const Icon(Icons.chevron_right_rounded),
        enabled: sync.isConfigured,
        onTap: sync.isConfigured ? () => _openSetup(context) : null,
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.sync});

  final WebDavSyncController sync;

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.webDavClearConfigurationTitle),
        content: Text(context.l10n.webDavClearConfigurationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.webDavClearConfigurationConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) await sync.clearConfiguration();
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune_rounded),
            title: Text(context.l10n.webDavConnectionDetails),
            subtitle: Text(
              sync.isConfigured
                  ? (sync.serverUrl ?? '')
                  : context.l10n.webDavNotConfigured,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openSetup(context),
          ),
          if (sync.isConfigured) ...[
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.link_off_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(context.l10n.webDavClearConfiguration),
              onTap: () => _clear(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _BookFilesCard extends StatelessWidget {
  const _BookFilesCard({required this.sync});

  final WebDavSyncController sync;

  @override
  Widget build(BuildContext context) {
    final available =
        sync.remoteBooks.where((book) => book.fileAvailable).length;
    return _Card(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.cloud_download_outlined),
        title: Text(context.l10n.webDavBookFilesTitle),
        subtitle: Text(
          available == 0
              ? context.l10n.webDavBookFilesHint
              : '${context.l10n.webDavFilesAvailableDownload}：$available',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        enabled: sync.isConfigured,
        onTap: sync.isConfigured
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BookFileSyncPage(),
                  ),
                )
            : null,
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.security_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(context.l10n.webDavSecurityNotice)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

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
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

Future<void> _openSetup(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WebDavSetupPage()),
    );
