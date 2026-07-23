import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/core/app_update_download_service.dart';
import '../services/core/update_check_service.dart';
import '../utils/localization_extension.dart';
import '../utils/page_style_helper.dart';
import 'release_notes_markdown.dart';
import 'side_toast.dart';

class UpdateCheckGate extends StatefulWidget {
  const UpdateCheckGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateCheckGate> createState() => _UpdateCheckGateState();
}

class _UpdateCheckGateState extends State<UpdateCheckGate> {
  @override
  void initState() {
    super.initState();
    // Web 部署随 GitHub Release 自动替换静态文件，刷新页面即是最新版。
    // 浏览器中再请求官网/GitHub 更新接口只会引入 CORS 失败。
    if (kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(UpdatePromptController.check(context));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

enum _UpdateAction { later, skip, github, website }

class UpdatePromptController {
  static const _skippedVersionKey = 'skipped_update_version';

  static Future<bool> check(
    BuildContext context, {
    bool manual = false,
    UpdateCheckService? service,
    AppUpdateDownloadService? downloadService,
  }) async {
    try {
      final result = await (service ?? UpdateCheckService()).check();
      if (!context.mounted) return false;

      if (!result.hasUpdate) {
        if (manual) {
          _showMessage(
            context,
            context.l10n.updateAlreadyLatest,
            kind: SideToastKind.success,
          );
        }
        return false;
      }

      final latestVersion = result.latestRelease.version;
      final prefs = await SharedPreferences.getInstance();
      if (!manual && prefs.getString(_skippedVersionKey) == latestVersion) {
        return true;
      }
      if (!context.mounted) return true;

      final action =
          await showDialog<_UpdateAction>(
            context: context,
            builder: (dialogContext) => _UpdateDialog(result: result),
          ) ??
          _UpdateAction.later;
      if (!context.mounted) return true;

      if (action == _UpdateAction.skip) {
        await prefs.setString(_skippedVersionKey, latestVersion);
      }
      if (!context.mounted) return true;

      switch (action) {
        case _UpdateAction.later || _UpdateAction.skip:
          break;
        case _UpdateAction.github:
          await _openExternal(context, result.latestRelease.releaseUrl);
        case _UpdateAction.website:
          if (context.mounted) {
            await _handleWebsiteUpdate(
              context,
              result.latestRelease,
              downloadService ?? AppUpdateDownloadService(),
            );
          }
      }
      return true;
    } catch (_) {
      if (manual && context.mounted) {
        _showMessage(
          context,
          context.l10n.updateCheckFailed,
          kind: SideToastKind.error,
        );
      }
      return false;
    }
  }

  static Future<bool> _handleWebsiteUpdate(
    BuildContext context,
    AppRelease release,
    AppUpdateDownloadService downloadService,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) {
      final websiteUrl =
          release.websiteAsset?.websiteUrl ??
          Uri.parse('https://open.xxread.top/download');
      return _openExternal(context, websiteUrl);
    }

    final asset = release.websiteAsset;
    if (asset == null) {
      _showMessage(
        context,
        context.l10n.updateWebsiteUnavailable,
        kind: SideToastKind.error,
      );
      return false;
    }
    final failure = await showDialog<AppUpdateException>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _WebsiteUpdateProgressDialog(
        asset: asset,
        downloadService: downloadService,
      ),
    );
    if (!context.mounted || failure == null) return failure == null;
    final message = switch (failure.failure) {
      AppUpdateFailure.cancelled => null,
      AppUpdateFailure.fileSize ||
      AppUpdateFailure.checksum => context.l10n.updateIntegrityFailed,
      AppUpdateFailure.download => context.l10n.updateDownloadFailed,
      AppUpdateFailure.install => context.l10n.updateInstallFailed,
      AppUpdateFailure.unsupported => context.l10n.updateWebsiteUnavailable,
    };
    if (message != null) {
      _showMessage(context, message, kind: SideToastKind.error);
    }
    return false;
  }

  static Future<bool> _openExternal(BuildContext context, Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      _showMessage(
        context,
        context.l10n.updateOpenFailed,
        kind: SideToastKind.error,
      );
    }
    return opened;
  }

  static void _showMessage(
    BuildContext context,
    String message, {
    SideToastKind kind = SideToastKind.info,
  }) {
    showSideToast(context, message, kind: kind);
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.result});

  final UpdateCheckResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = PageStyleHelper.palette(context);
    final release = result.latestRelease;
    final notes = release.notes.isEmpty ? l10n.updateNotesEmpty : release.notes;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.88;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 620, maxHeight: maxHeight),
        child: Material(
          color: palette.cardStrong,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                decoration: BoxDecoration(
                  color: palette.hero,
                  border: Border(bottom: BorderSide(color: palette.border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.auto_stories_rounded,
                            color: scheme.onPrimaryContainer,
                            size: 27,
                          ),
                        ),
                        Positioned(
                          right: -5,
                          bottom: -5,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: palette.hero, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              color: scheme.onPrimary,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.updateAvailableTitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 11),
                          Semantics(
                            label: l10n.updateVersionSummary(
                              result.currentVersion,
                              release.version,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _VersionBadge(
                                  version: result.currentVersion,
                                  foreground: scheme.onSurfaceVariant,
                                  background: scheme.surface.withValues(
                                    alpha: 0.62,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 17,
                                    color: scheme.primary,
                                  ),
                                ),
                                _VersionBadge(
                                  version: release.version,
                                  foreground: scheme.onPrimaryContainer,
                                  background: scheme.primaryContainer,
                                  emphasized: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notes_rounded,
                            size: 19,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.updateNotesTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 15, 16, 3),
                          decoration: BoxDecoration(
                            color: palette.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: palette.border),
                          ),
                          child: SingleChildScrollView(
                            child: ReleaseNotesMarkdown(
                              data: notes,
                              onTapLink: (uri) =>
                                  UpdatePromptController._openExternal(
                                    context,
                                    uri,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: BoxDecoration(
                  color: palette.cardStrong,
                  border: Border(top: BorderSide(color: palette.border)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pop(_UpdateAction.skip),
                      icon: const Icon(Icons.visibility_off_outlined, size: 18),
                      label: Text(l10n.updateSkipVersion),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_UpdateAction.later),
                      child: Text(l10n.updateLater),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pop(_UpdateAction.github),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(l10n.updateFromGithub),
                    ),
                    FilledButton.icon(
                      onPressed:
                          defaultTargetPlatform == TargetPlatform.android &&
                              !kIsWeb &&
                              release.websiteAsset == null
                          ? null
                          : () => Navigator.of(
                              context,
                            ).pop(_UpdateAction.website),
                      icon: Icon(
                        defaultTargetPlatform == TargetPlatform.android &&
                                !kIsWeb
                            ? Icons.download_rounded
                            : Icons.language_rounded,
                        size: 18,
                      ),
                      label: Text(
                        defaultTargetPlatform == TargetPlatform.android &&
                                !kIsWeb
                            ? l10n.updateFromWebsiteInstall
                            : l10n.updateFromWebsite,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({
    required this.version,
    required this.foreground,
    required this.background,
    this.emphasized = false,
  });

  final String version;
  final Color foreground;
  final Color background;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      'v$version',
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: foreground,
        fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

class _WebsiteUpdateProgressDialog extends StatefulWidget {
  const _WebsiteUpdateProgressDialog({
    required this.asset,
    required this.downloadService,
  });

  final WebsiteReleaseAsset asset;
  final AppUpdateDownloadService downloadService;

  @override
  State<_WebsiteUpdateProgressDialog> createState() =>
      _WebsiteUpdateProgressDialogState();
}

class _WebsiteUpdateProgressDialogState
    extends State<_WebsiteUpdateProgressDialog> {
  final _cancelToken = CancelToken();
  double? _progress;
  bool _openingInstaller = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await widget.downloadService.downloadAndInstall(
        widget.asset,
        cancelToken: _cancelToken,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _progress = total > 0 ? (received / total).clamp(0, 1) : null;
            _openingInstaller = total > 0 && received >= total;
          });
        },
      );
      if (mounted) Navigator.of(context).pop();
    } on AppUpdateException catch (error) {
      if (mounted) Navigator.of(context).pop(error);
    } catch (error) {
      if (mounted) {
        Navigator.of(
          context,
        ).pop(AppUpdateException(AppUpdateFailure.install, error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final percentage = ((_progress ?? 0) * 100).round();
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(context.l10n.updateDownloadingTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: _openingInstaller ? null : _progress,
            ),
            const SizedBox(height: 12),
            Text(
              _openingInstaller
                  ? context.l10n.updatePreparingInstaller
                  : context.l10n.updateDownloadProgress(percentage),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _openingInstaller
                ? null
                : () => _cancelToken.cancel('Cancelled by user'),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
      ),
    );
  }
}
