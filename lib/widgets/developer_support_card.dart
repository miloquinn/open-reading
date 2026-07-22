import 'package:flutter/material.dart';

import '../utils/localization_extension.dart';

class DeveloperSupportCard extends StatelessWidget {
  const DeveloperSupportCard({
    super.key,
    required this.onWechatTap,
    required this.onAlipayTap,
  });

  final VoidCallback onWechatTap;
  final VoidCallback onAlipayTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const accent = Color(0xFFE05D6F);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: accent.withValues(alpha: isDark ? 0.14 : 0.075),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: accent.withValues(alpha: 0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 13, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.24 : 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settingsSupportDevelopmentCardTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.settingsSupportDevelopmentCardSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _DonationMethodButton(
                      key: const ValueKey('settings-wechat-donation-link'),
                      onPressed: onWechatTap,
                      color: const Color(0xFF07C160),
                      label: l10n.settingsDonationAction,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DonationMethodButton(
                      key: const ValueKey('settings-alipay-donation-link'),
                      onPressed: onAlipayTap,
                      color: const Color(0xFF1677FF),
                      label: l10n.settingsAlipayDonationAction,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonationMethodButton extends StatelessWidget {
  const _DonationMethodButton({
    super.key,
    required this.onPressed,
    required this.color,
    required this.label,
  });

  final VoidCallback onPressed;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: 0.075),
        side: BorderSide(color: color.withValues(alpha: 0.24)),
        minimumSize: const Size.fromHeight(42),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

enum DeveloperDonationMethod { wechat, alipay }

class DeveloperDonationDialog extends StatelessWidget {
  const DeveloperDonationDialog({super.key, required this.method});

  final DeveloperDonationMethod method;

  static const wechatAssetPath = 'assets/images/wechat_donation_qr.png';
  static const alipayAssetPath = 'assets/images/alipay_donation_qr.jpg';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxImageHeight = MediaQuery.sizeOf(context).height * 0.48;
    final isWechat = method == DeveloperDonationMethod.wechat;
    final accent = isWechat ? const Color(0xFF07C160) : const Color(0xFF1677FF);
    final title = isWechat
        ? l10n.settingsDonationDialogTitle
        : l10n.settingsAlipayDonationDialogTitle;
    final hint = isWechat
        ? l10n.settingsDonationDialogHint
        : l10n.settingsAlipayDonationDialogHint;
    final semanticLabel = isWechat
        ? l10n.settingsDonationQrCodeLabel
        : l10n.settingsAlipayDonationQrCodeLabel;
    final assetPath = isWechat ? wechatAssetPath : alipayAssetPath;
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.qr_code_2_rounded, color: accent, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxImageHeight),
                    child: Image.asset(
                      assetPath,
                      key: ValueKey(
                        isWechat
                            ? 'wechat-donation-qr-image'
                            : 'alipay-donation-qr-image',
                      ),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      semanticLabel: semanticLabel,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.settingsDonationVoluntaryNotice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}
