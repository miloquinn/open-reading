// 文件说明：设置页封面相关操作的 part 拆分文件，减少主页面复杂度。
// 技术要点：Flutter UI、Dart part。

part of '../settings_page.dart';

extension _SettingsPageCoverActions on _SettingsPageState {
  // ignore: unused_element
  void _showRestartDialog({String? reason}) {
    final l10n = context.l10n;
    final effectiveReason = reason ?? l10n.settingsRestartRequiredReason;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.restart_alt, color: Colors.orange),
            const SizedBox(width: 8),
            Text(l10n.settingsRestartRequiredTitle),
          ],
        ),
        content: Text(l10n.settingsRestartPrompt(effectiveReason)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.settingsRestartLater),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              RestartableApp.restart(this.context);
            },
            child: Text(l10n.settingsRestartNow),
          ),
        ],
      ),
    );
  }
}
