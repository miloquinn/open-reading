import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/localization_extension.dart';
import '../utils/page_style_helper.dart';

class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = _entries(l10n);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.changelogPageTitle),
        scrolledUnderElevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: SafeArea(
          top: false,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _VersionCard(
              entry: entries[index],
              currentLabel: l10n.changelogCurrentVersion,
            ),
          ),
        ),
      ),
    );
  }

  List<_ChangelogEntry> _entries(AppLocalizations l10n) {
    return [
      _ChangelogEntry(
        version: 'v1.2.2',
        current: true,
        items: [l10n.changelog122ContinuousTap],
      ),
      _ChangelogEntry(
        version: 'v1.2.1',
        items: [
          l10n.changelog121ContinuousScroll,
          l10n.changelog121Typography,
        ],
      ),
      _ChangelogEntry(
        version: 'v1.2.0',
        items: [
          l10n.changelog120Typography,
          l10n.changelog120VolumeKeys,
          l10n.changelog120CustomFonts,
          l10n.changelog120SystemBars,
          l10n.changelog120BookAnimations,
          l10n.changelog120TabletLibrary,
          l10n.changelog120Import,
          l10n.changelog120Covers,
          l10n.changelog120Licenses,
        ],
      ),
      _ChangelogEntry(
        version: 'v1.1.0',
        items: [
          l10n.changelog110CustomFonts,
          l10n.changelog110Bookmarks,
        ],
      ),
      _ChangelogEntry(
        version: 'v1.0.2',
        items: [l10n.changelog102Summary],
      ),
      _ChangelogEntry(
        version: 'v1.0.1',
        items: [l10n.changelog101Summary],
      ),
      _ChangelogEntry(
        version: 'v1.0.0',
        items: [l10n.changelog100Summary],
      ),
      _ChangelogEntry(
        version: 'v0.9.1',
        items: [l10n.changelog091Summary],
      ),
    ];
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({
    required this.entry,
    required this.currentLabel,
  });

  final _ChangelogEntry entry;
  final String currentLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = PageStyleHelper.palette(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.version,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (entry.current) ...[
                const SizedBox(width: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    currentLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          for (final item in entry.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChangelogEntry {
  const _ChangelogEntry({
    required this.version,
    required this.items,
    this.current = false,
  });

  final String version;
  final List<String> items;
  final bool current;
}
