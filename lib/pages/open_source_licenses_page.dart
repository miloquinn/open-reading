import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/localization_extension.dart';
import '../utils/page_style_helper.dart';

class OpenSourceLicensesPage extends StatelessWidget {
  const OpenSourceLicensesPage({
    required this.appVersion,
    super.key,
  });

  final String appVersion;

  static const _fontLicenses = [
    _BundledLicense(
      name: 'Noto Serif SC / Source Han Serif',
      assetPath: 'assets/fonts/licenses/NotoSerifSC-OFL.txt',
    ),
    _BundledLicense(
      name: 'Source Han Sans CN',
      assetPath: 'assets/fonts/licenses/SourceHanSans-OFL.txt',
    ),
    _BundledLicense(
      name: 'Instrument Sans',
      assetPath: 'assets/fonts/licenses/InstrumentSans-OFL.txt',
    ),
    _BundledLicense(
      name: 'Newsreader',
      assetPath: 'assets/fonts/licenses/Newsreader-OFL.txt',
    ),
    _BundledLicense(
      name: 'JetBrains Mono',
      assetPath: 'assets/fonts/licenses/JetBrainsMono-OFL.txt',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.openSourceLicensesTitle),
        scrolledUnderElevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _IntroCard(text: l10n.openSourceLicensesIntro),
              const SizedBox(height: 22),
              _SectionTitle(title: l10n.openSourceProjectSection),
              const SizedBox(height: 8),
              _LicenseEntryCard(
                key: const ValueKey('open-reading-agpl-license'),
                title: 'Open Reading',
                subtitle: 'GNU Affero General Public License v3.0',
                icon: Icons.code_rounded,
                onTap: () => _openBundledLicense(
                  context,
                  title: 'Open Reading · AGPL-3.0',
                  assetPath: 'LICENSE',
                ),
              ),
              const SizedBox(height: 10),
              _LicenseEntryCard(
                title: l10n.openSourceLegacyLicenseTitle,
                subtitle: 'MIT License · v1.0.0 and earlier',
                icon: Icons.history_rounded,
                onTap: () => _openBundledLicense(
                  context,
                  title: '${l10n.openSourceLegacyLicenseTitle} · MIT',
                  assetPath: 'LICENSE-MIT-LEGACY',
                ),
              ),
              const SizedBox(height: 22),
              _SectionTitle(title: l10n.openSourceFontsSection),
              const SizedBox(height: 8),
              for (var index = 0; index < _fontLicenses.length; index++) ...[
                _LicenseEntryCard(
                  key: ValueKey('font-license-${_fontLicenses[index].name}'),
                  title: _fontLicenses[index].name,
                  subtitle: 'SIL Open Font License 1.1',
                  icon: Icons.font_download_outlined,
                  onTap: () => _openBundledLicense(
                    context,
                    title: _fontLicenses[index].name,
                    assetPath: _fontLicenses[index].assetPath,
                  ),
                ),
                if (index != _fontLicenses.length - 1)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 22),
              _SectionTitle(title: l10n.openSourceDependenciesSection),
              const SizedBox(height: 8),
              _LicenseEntryCard(
                key: const ValueKey('flutter-package-licenses'),
                title: l10n.openSourceDependenciesTitle,
                subtitle: l10n.openSourceDependenciesSubtitle,
                icon: Icons.widgets_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LicensePage(
                      applicationName: l10n.settingsAppName,
                      applicationVersion: appVersion,
                      applicationLegalese: l10n.openSourceLicenseLegalese,
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

  void _openBundledLicense(
    BuildContext context, {
    required String title,
    required String assetPath,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LicenseTextPage(
          title: title,
          assetPath: assetPath,
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = PageStyleHelper.palette(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.hero,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.balance_rounded, color: scheme.primary),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.55,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _LicenseEntryCard extends StatelessWidget {
  const _LicenseEntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = PageStyleHelper.palette(context);
    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 13, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 21, color: scheme.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LicenseTextPage extends StatefulWidget {
  const _LicenseTextPage({
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  State<_LicenseTextPage> createState() => _LicenseTextPageState();
}

class _LicenseTextPageState extends State<_LicenseTextPage> {
  late final Future<String> _licenseText =
      rootBundle.loadString(widget.assetPath);

  @override
  Widget build(BuildContext context) {
    final palette = PageStyleHelper.palette(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        scrolledUnderElevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: SafeArea(
          top: false,
          child: FutureBuilder<String>(
            future: _licenseText,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(context.l10n.openSourceLicenseLoadFailed),
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                  ),
                  child: SelectableText(
                    snapshot.data ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily:
                              defaultTargetPlatform == TargetPlatform.iOS
                                  ? 'Menlo'
                                  : 'monospace',
                          height: 1.55,
                        ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BundledLicense {
  const _BundledLicense({
    required this.name,
    required this.assetPath,
  });

  final String name;
  final String assetPath;
}
