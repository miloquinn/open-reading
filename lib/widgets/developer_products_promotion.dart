import 'package:flutter/material.dart';

import '../utils/localization_extension.dart';

class DeveloperProductsPromotion extends StatelessWidget {
  const DeveloperProductsPromotion({
    super.key,
    required this.onOpenXiaoyuanReading,
    required this.onOpenXiaoyuanCommunity,
  });

  final VoidCallback onOpenXiaoyuanReading;
  final VoidCallback onOpenXiaoyuanCommunity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _DeveloperProductCard(
            key: const ValueKey('settings-xiaoyuan-reading-link'),
            onTap: onOpenXiaoyuanReading,
            accent: scheme.primary,
            icon: Icons.auto_stories_rounded,
            title: l10n.settingsXiaoyuanReadingTitle,
            subtitle: l10n.settingsXiaoyuanReadingSubtitle,
            domain: 'xxread.top',
          ),
          const SizedBox(height: 10),
          _DeveloperProductCard(
            key: const ValueKey('settings-xiaoyuan-community-link'),
            onTap: onOpenXiaoyuanCommunity,
            accent: scheme.tertiary,
            icon: Icons.forum_rounded,
            title: l10n.settingsXiaoyuanCommunityTitle,
            subtitle: l10n.settingsXiaoyuanCommunitySubtitle,
            domain: 'community.xxread.top',
          ),
        ],
      ),
    );
  }
}

class _DeveloperProductCard extends StatelessWidget {
  const _DeveloperProductCard({
    super.key,
    required this.onTap,
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.domain,
  });

  final VoidCallback onTap;
  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final String domain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: '$title, $subtitle, $domain',
      child: Material(
        color: accent.withValues(alpha: isDark ? 0.14 : 0.075),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: accent.withValues(alpha: 0.18)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 13, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.22 : 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: accent, size: 23),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Icon(
                            Icons.language_rounded,
                            size: 14,
                            color: accent,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              domain,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.12,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_outward_rounded,
                            size: 18,
                            color: accent.withValues(alpha: 0.82),
                          ),
                        ],
                      ),
                    ],
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
