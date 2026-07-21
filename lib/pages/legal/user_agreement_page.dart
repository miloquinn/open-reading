// 用户首次启动时展示的欢迎页、使用条款与隐私说明。
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/widgets/app_brand_icon.dart';

class UserAgreementPage extends StatefulWidget {
  final VoidCallback onAgreed;
  final VoidCallback? onDisagreed;

  const UserAgreementPage({
    super.key,
    required this.onAgreed,
    this.onDisagreed,
  });

  @override
  State<UserAgreementPage> createState() => _UserAgreementPageState();
}

class _UserAgreementPageState extends State<UserAgreementPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _termsConfirmed = false;
  bool _sourceBoundaryConfirmed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.025),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF11110F) : const Color(0xFFF4F1EA),
      body: Stack(
        children: [
          Positioned.fill(
              child: CustomPaint(painter: _PaperGrainPainter(isDark))),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 880;
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1160),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            wide ? 48 : 20,
                            wide ? 40 : 18,
                            wide ? 48 : 20,
                            wide ? 32 : 18,
                          ),
                          child: wide
                              ? Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                        flex: 4,
                                        child: _buildIntroduction(scheme)),
                                    const SizedBox(width: 52),
                                    Expanded(
                                        flex: 6,
                                        child: _buildAgreementPanel(scheme)),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildCompactHeader(scheme),
                                    const SizedBox(height: 18),
                                    Expanded(
                                        child: _buildAgreementPanel(scheme)),
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroduction(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrand(scheme, compact: false),
          const Spacer(),
          Text(
            context.l10n.agreementV2HeroTitle,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  height: 1.08,
                  letterSpacing: -1.4,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.agreementV2HeroBody,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.75,
                  color: scheme.onSurface.withValues(alpha: 0.68),
                ),
          ),
          const SizedBox(height: 30),
          _buildPrinciple(
            scheme,
            Icons.folder_outlined,
            context.l10n.agreementV2LocalTitle,
            context.l10n.agreementV2LocalBody,
          ),
          const SizedBox(height: 16),
          _buildPrinciple(
            scheme,
            Icons.code_rounded,
            context.l10n.agreementV2OpenSourceTitle,
            context.l10n.agreementV2OpenSourceBody,
          ),
          const Spacer(flex: 2),
          Text(
            context.l10n.agreementV2VersionLabel(
                UserAgreementService.currentAgreementVersion),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.42),
                  letterSpacing: 0.4,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeader(ColorScheme scheme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: _buildBrand(scheme, compact: true),
    );
  }

  Widget _buildBrand(ColorScheme scheme, {required bool compact}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBrandIcon(
          size: compact ? 42 : 52,
          borderRadius: compact ? 11 : 14,
          border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
        ),
        SizedBox(width: compact ? 12 : 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.appTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
            ),
            if (!compact)
              Text(
                'OPEN READING',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.46),
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w600,
                    ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrinciple(
    ColorScheme scheme,
    IconData icon,
    String title,
    String body,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              size: 18, color: scheme.onSurface.withValues(alpha: 0.74)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.55,
                      color: scheme.onSurface.withValues(alpha: 0.58),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgreementPanel(ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = <(String, String)>[
      (context.l10n.agreementV2Section1Title, context.l10n.agreementV2Section1Body),
      (context.l10n.agreementV2Section2Title, context.l10n.agreementV2Section2Body),
      (context.l10n.agreementV2Section3Title, context.l10n.agreementV2Section3Body),
      (context.l10n.agreementV2Section4Title, context.l10n.agreementV2Section4Body),
      (context.l10n.agreementV2Section5Title, context.l10n.agreementV2Section5Body),
      (context.l10n.agreementV2Section6Title, context.l10n.agreementV2Section6Body),
      (context.l10n.agreementV2Section7Title, context.l10n.agreementV2Section7Body),
      (context.l10n.agreementV2Section8Title, context.l10n.agreementV2Section8Body),
      (context.l10n.agreementV2Section9Title, context.l10n.agreementV2Section9Body),
      (context.l10n.agreementV2Section10Title, context.l10n.agreementV2Section10Body),
      (context.l10n.agreementV2Section11Title, context.l10n.agreementV2Section11Body),
    ];
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B18) : const Color(0xFFFCFBF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.agreementV2Title,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.6,
                                ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.l10n.agreementV2Subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.52),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.article_outlined,
                    color: scheme.onSurface.withValues(alpha: 0.34)),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outline.withValues(alpha: 0.13)),
          Expanded(
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImportantNotice(scheme),
                    const SizedBox(height: 16),
                    _buildSourceBoundary(scheme),
                    const SizedBox(height: 26),
                    for (var i = 0; i < sections.length; i++) ...[
                      _buildLegalSection(
                        scheme,
                        i + 1,
                        sections[i].$1,
                        sections[i].$2,
                      ),
                      if (i != sections.length - 1)
                        const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outline.withValues(alpha: 0.13)),
          _buildConsentArea(scheme),
        ],
      ),
    );
  }

  Widget _buildImportantNotice(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.13)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 20, color: scheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.agreementV2ImportantNotice,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.65,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.78),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBoundary(ColorScheme scheme) {
    final points = <String>[
      context.l10n.agreementV2SourceBoundaryPoint1,
      context.l10n.agreementV2SourceBoundaryPoint2,
      context.l10n.agreementV2SourceBoundaryPoint3,
    ];
    return Container(
      key: const Key('agreementSourceBoundaryCard'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.agreementV2SourceBoundaryTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final point in points) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    point,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.55,
                          color:
                              scheme.onPrimaryContainer.withValues(alpha: 0.84),
                        ),
                  ),
                ),
              ],
            ),
            if (point != points.last)
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildLegalSection(
    ColorScheme scheme,
    int index,
    String title,
    String body,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.34),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.72,
                  color: scheme.onSurface.withValues(alpha: 0.68),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsentArea(ColorScheme scheme) {
    final canContinue = _termsConfirmed && _sourceBoundaryConfirmed && !_saving;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      child: Column(
        children: [
          _buildConsentCheckbox(
            key: const Key('agreementTermsConsent'),
            scheme: scheme,
            value: _termsConfirmed,
            label: context.l10n.agreementV2ConfirmLabel,
            onChanged: (value) => setState(() => _termsConfirmed = value),
          ),
          const SizedBox(height: 6),
          _buildConsentCheckbox(
            key: const Key('agreementSourceConsent'),
            scheme: scheme,
            value: _sourceBoundaryConfirmed,
            label: context.l10n.agreementV2SourceConfirmLabel,
            emphasized: true,
            onChanged: (value) =>
                setState(() => _sourceBoundaryConfirmed = value),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: _saving ? null : _onDisagreePressed,
                child: Text(context.l10n.agreementV2ExitLabel),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('agreementContinueButton'),
                  onPressed: canContinue ? _onAgreePressed : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.agreementV2ContinueLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCheckbox({
    required Key key,
    required ColorScheme scheme,
    required bool value,
    required String label,
    required ValueChanged<bool> onChanged,
    bool emphasized = false,
  }) {
    return Material(
      color: emphasized
          ? scheme.primaryContainer.withValues(alpha: 0.24)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: key,
        onTap: _saving ? null : () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: _saving
                    ? null
                    : (nextValue) => onChanged(nextValue ?? false),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.45,
                        fontWeight:
                            emphasized ? FontWeight.w600 : FontWeight.normal,
                        color: scheme.onSurface.withValues(alpha: 0.76),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAgreePressed() async {
    if (!_termsConfirmed || !_sourceBoundaryConfirmed || _saving) return;
    setState(() => _saving = true);
    try {
      await UserAgreementService.acceptAgreement(
        locale: Localizations.localeOf(context).toLanguageTag(),
      );
      if (mounted) widget.onAgreed();
    } catch (error) {
      debugPrint('保存用户协议状态失败: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.agreementV2SaveFailed)),
      );
    }
  }

  void _onDisagreePressed() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.agreementV2ExitDialogTitle),
        content: Text(context.l10n.agreementV2ExitDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.agreementV2CancelLabel),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onDisagreed?.call();
            },
            child: Text(context.l10n.agreementV2ConfirmExitLabel),
          ),
        ],
      ),
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  final bool isDark;
  const _PaperGrainPainter(this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.018)
      ..strokeWidth = 0.6;
    for (double y = 18; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final accentPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.032)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * 0.08, 0),
      Offset(size.width * 0.08, size.height),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class UserAgreementService {
  static const String currentAgreementVersion = '2026-07-19.2';
  static const String _keyAgreementAccepted = 'userAgreementAccepted';
  static const String _keyAcceptedDate = 'agreementAcceptedDate';
  static const String _keyAcceptedVersion = 'agreementAcceptedVersion';
  static const String _keyAcceptedLocale = 'agreementAcceptedLocale';
  static const String _keySourceBoundaryAccepted =
      'thirdPartySourceBoundaryAccepted';

  static Future<bool> hasUserAcceptedAgreement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getBool(_keyAgreementAccepted) ?? false) &&
          prefs.getString(_keyAcceptedVersion) == currentAgreementVersion &&
          (prefs.getBool(_keySourceBoundaryAccepted) ?? false);
    } catch (error) {
      debugPrint('检查用户协议状态失败: $error');
      return false;
    }
  }

  static Future<void> acceptAgreement({required String locale}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAgreementAccepted, true);
    await prefs.setString(
        _keyAcceptedDate, DateTime.now().toUtc().toIso8601String());
    await prefs.setString(_keyAcceptedVersion, currentAgreementVersion);
    await prefs.setString(_keyAcceptedLocale, locale);
    await prefs.setBool(_keySourceBoundaryAccepted, true);
  }

  static Future<DateTime?> getAgreementAcceptedDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_keyAcceptedDate);
      return value == null ? null : DateTime.tryParse(value);
    } catch (error) {
      debugPrint('读取用户协议同意时间失败: $error');
      return null;
    }
  }

  static Future<void> resetAgreementStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAgreementAccepted);
    await prefs.remove(_keyAcceptedDate);
    await prefs.remove(_keyAcceptedVersion);
    await prefs.remove(_keyAcceptedLocale);
    await prefs.remove(_keySourceBoundaryAccepted);
  }
}
