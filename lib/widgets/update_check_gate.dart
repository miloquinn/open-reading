import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/core/update_check_service.dart';
import '../utils/localization_extension.dart';

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

class UpdatePromptController {
  static const _lastPromptedVersionKey = 'last_prompted_update_version';

  static Future<bool> check(
    BuildContext context, {
    bool manual = false,
    UpdateCheckService? service,
  }) async {
    try {
      final result = await (service ?? UpdateCheckService()).check();
      if (!context.mounted) return false;

      if (!result.hasUpdate) {
        if (manual) {
          _showMessage(context, context.l10n.updateAlreadyLatest);
        }
        return false;
      }

      final latestVersion = result.latestRelease.version;
      final prefs = await SharedPreferences.getInstance();
      if (!manual &&
          prefs.getString(_lastPromptedVersionKey) == latestVersion) {
        return true;
      }
      if (!manual) {
        await prefs.setString(_lastPromptedVersionKey, latestVersion);
      }
      if (!context.mounted) return true;

      final shouldUpdate = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => _UpdateDialog(result: result),
          ) ??
          false;
      if (shouldUpdate && context.mounted) {
        final opened = await launchUrl(
          result.latestRelease.releaseUrl,
          mode: LaunchMode.externalApplication,
        );
        if (!opened && context.mounted) {
          _showMessage(context, context.l10n.updateOpenFailed);
        }
      }
      return true;
    } catch (_) {
      if (manual && context.mounted) {
        _showMessage(context, context.l10n.updateCheckFailed);
      }
      return false;
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
                child: SingleChildScrollView(
                  child: SelectableText(notes),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.updateLater),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(l10n.updateGoToDownload),
        ),
      ],
    );
  }
}
