import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/core/app_update_download_service.dart';
import '../services/core/update_check_service.dart';
import '../utils/localization_extension.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(UpdatePromptController.check(context));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

enum _UpdateAction { later, github, website }

class UpdatePromptController {
  static const _lastPromptedVersionKey = 'last_prompted_update_version';

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
      if (!manual &&
          prefs.getString(_lastPromptedVersionKey) == latestVersion) {
        return true;
      }
      if (!context.mounted) return true;

      final action = await showDialog<_UpdateAction>(
            context: context,
            builder: (dialogContext) => _UpdateDialog(result: result),
          ) ??
          _UpdateAction.later;
      if (!context.mounted) return true;

      final handled = switch (action) {
        _UpdateAction.later => true,
        _UpdateAction.github =>
          await _openExternal(context, result.latestRelease.releaseUrl),
        _UpdateAction.website => context.mounted
            ? await _handleWebsiteUpdate(
                context,
                result.latestRelease,
                downloadService ?? AppUpdateDownloadService(),
              )
            : false,
      };
      if (!manual && handled) {
        await prefs.setString(_lastPromptedVersionKey, latestVersion);
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
      final websiteUrl = release.websiteAsset?.websiteUrl ??
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
      AppUpdateFailure.checksum =>
        context.l10n.updateIntegrityFailed,
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
    final release = result.latestRelease;
    final notes = release.notes.isEmpty ? l10n.updateNotesEmpty : release.notes;

    return AlertDialog(
      icon: const Icon(Icons.system_update_alt_rounded),
      title: Text(l10n.updateAvailableTitle),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.updateVersionSummary(
                result.currentVersion,
                release.version,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.updateNotesTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(child: SelectableText(notes)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_UpdateAction.later),
          child: Text(l10n.updateLater),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(_UpdateAction.github),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(l10n.updateFromGithub),
        ),
        FilledButton.icon(
          onPressed: defaultTargetPlatform == TargetPlatform.android &&
                  !kIsWeb &&
                  release.websiteAsset == null
              ? null
              : () => Navigator.of(context).pop(_UpdateAction.website),
          icon: Icon(
            defaultTargetPlatform == TargetPlatform.android && !kIsWeb
                ? Icons.download_rounded
                : Icons.language_rounded,
          ),
          label: Text(
            defaultTargetPlatform == TargetPlatform.android && !kIsWeb
                ? l10n.updateFromWebsiteInstall
                : l10n.updateFromWebsite,
          ),
        ),
      ],
    );
  }
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
        Navigator.of(context).pop(
          AppUpdateException(AppUpdateFailure.install, error),
        );
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
