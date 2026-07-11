// 用户首次启动时展示的欢迎页、使用条款与隐私说明。
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/localization_extension.dart';
import '../widgets/app_brand_icon.dart';

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
  bool _confirmed = false;
  bool _saving = false;

  bool get _isChinese =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';

  _AgreementCopy get _copy =>
      _isChinese ? _AgreementCopy.chinese : _AgreementCopy.english;

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
    final copy = _copy;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrand(scheme, compact: false),
          const Spacer(),
          Text(
            copy.heroTitle,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  height: 1.08,
                  letterSpacing: -1.4,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
          ),
          const SizedBox(height: 18),
          Text(
            copy.heroBody,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.75,
                  color: scheme.onSurface.withValues(alpha: 0.68),
                ),
          ),
          const SizedBox(height: 30),
          _buildPrinciple(
            scheme,
            Icons.folder_outlined,
            copy.localTitle,
            copy.localBody,
          ),
          const SizedBox(height: 16),
          _buildPrinciple(
            scheme,
            Icons.code_rounded,
            copy.openSourceTitle,
            copy.openSourceBody,
          ),
          const Spacer(flex: 2),
          Text(
            copy.versionLabel,
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
    return Row(
      children: [
        Expanded(child: _buildBrand(scheme, compact: true)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            'MIT · LOCAL FIRST',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),
        ),
      ],
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
    final copy = _copy;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                        copy.agreementTitle,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.6,
                                ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        copy.agreementSubtitle,
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
                    _buildImportantNotice(scheme, copy),
                    const SizedBox(height: 26),
                    for (var i = 0; i < copy.sections.length; i++) ...[
                      _buildLegalSection(scheme, i + 1, copy.sections[i]),
                      if (i != copy.sections.length - 1)
                        const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outline.withValues(alpha: 0.13)),
          _buildConsentArea(scheme, copy),
        ],
      ),
    );
  }

  Widget _buildImportantNotice(ColorScheme scheme, _AgreementCopy copy) {
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
              copy.importantNotice,
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

  Widget _buildLegalSection(
    ColorScheme scheme,
    int index,
    _AgreementSection section,
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
                section.title,
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
            section.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.72,
                  color: scheme.onSurface.withValues(alpha: 0.68),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsentArea(ColorScheme scheme, _AgreementCopy copy) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      child: Column(
        children: [
          InkWell(
            onTap:
                _saving ? null : () => setState(() => _confirmed = !_confirmed),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: _confirmed,
                    onChanged: _saving
                        ? null
                        : (value) =>
                            setState(() => _confirmed = value ?? false),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      copy.confirmLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.45,
                            color: scheme.onSurface.withValues(alpha: 0.72),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: _saving ? null : _onDisagreePressed,
                child: Text(copy.exitLabel),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _confirmed && !_saving ? _onAgreePressed : null,
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
                      : Text(copy.continueLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAgreePressed() async {
    if (!_confirmed || _saving) return;
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
        SnackBar(content: Text(_copy.saveFailed)),
      );
    }
  }

  void _onDisagreePressed() {
    final copy = _copy;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy.exitDialogTitle),
        content: Text(copy.exitDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(copy.cancelLabel),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onDisagreed?.call();
            },
            child: Text(copy.confirmExitLabel),
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
  static const String currentAgreementVersion = '2026-07-11.1';
  static const String _keyAgreementAccepted = 'userAgreementAccepted';
  static const String _keyAcceptedDate = 'agreementAcceptedDate';
  static const String _keyAcceptedVersion = 'agreementAcceptedVersion';
  static const String _keyAcceptedLocale = 'agreementAcceptedLocale';

  static Future<bool> hasUserAcceptedAgreement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getBool(_keyAgreementAccepted) ?? false) &&
          prefs.getString(_keyAcceptedVersion) == currentAgreementVersion;
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
  }
}

class _AgreementSection {
  final String title;
  final String body;
  const _AgreementSection(this.title, this.body);
}

class _AgreementCopy {
  final String heroTitle;
  final String heroBody;
  final String localTitle;
  final String localBody;
  final String openSourceTitle;
  final String openSourceBody;
  final String versionLabel;
  final String agreementTitle;
  final String agreementSubtitle;
  final String importantNotice;
  final List<_AgreementSection> sections;
  final String confirmLabel;
  final String exitLabel;
  final String continueLabel;
  final String exitDialogTitle;
  final String exitDialogBody;
  final String cancelLabel;
  final String confirmExitLabel;
  final String saveFailed;

  const _AgreementCopy({
    required this.heroTitle,
    required this.heroBody,
    required this.localTitle,
    required this.localBody,
    required this.openSourceTitle,
    required this.openSourceBody,
    required this.versionLabel,
    required this.agreementTitle,
    required this.agreementSubtitle,
    required this.importantNotice,
    required this.sections,
    required this.confirmLabel,
    required this.exitLabel,
    required this.continueLabel,
    required this.exitDialogTitle,
    required this.exitDialogBody,
    required this.cancelLabel,
    required this.confirmExitLabel,
    required this.saveFailed,
  });

  static const chinese = _AgreementCopy(
    heroTitle: '把阅读，留在自己的设备里。',
    heroBody: '开元阅读是一款开源、跨平台、本地优先的电子书阅读工具。它提供阅读能力，但不提供、托管或审核你导入的书籍。',
    localTitle: '本地优先',
    localBody: '书籍、进度与笔记原则上保存在你的设备中，由你自行管理与备份。',
    openSourceTitle: 'MIT 开源',
    openSourceBody: '源代码按 MIT License 提供；软件按“原样”交付，不附带任何明示或默示担保。',
    versionLabel: '条款版本 2026-07-11.1',
    agreementTitle: '使用条款与隐私说明',
    agreementSubtitle: '使用前请完整阅读，重点条款已直接说明',
    importantNotice:
        '特别提示：你导入、打开、转换、朗读或通过第三方书源获取的任何文件和内容，均由你自行选择并承担责任。开元阅读及其开发者不提供盗版内容，不对用户内容的来源、合法性、安全性或准确性负责。',
    sections: [
      _AgreementSection('协议范围与接受',
          '本协议适用于你对开元阅读软件及其附带功能的下载、安装和使用。点击“同意并继续”即表示你已阅读、理解并同意本协议；如你不同意，请停止使用并退出应用。若你未达到所在地法律规定的独立同意年龄，应由监护人阅读并同意。'),
      _AgreementSection('开源软件与许可',
          '开元阅读是按 MIT License 发布的开源软件。你可以在该许可证允许的范围内使用、复制、修改、合并、发布、分发、再许可或销售软件副本，但须保留许可证要求的版权与许可声明。本协议仅规范你对已分发应用及相关服务的使用，不限制 MIT License 已授予的权利；第三方组件仍适用各自许可证。'),
      _AgreementSection('用户内容与版权责任',
          '“用户内容”包括你导入、下载、打开、转换、缓存、标注、朗读或以其他方式处理的书籍、文档、图片、元数据及链接。你须确保自己对用户内容拥有合法权利或已取得必要授权，并自行承担因内容引起的版权、商标、隐私、名誉、违法信息、恶意文件及其他争议或损失。软件和开发者不上传、出售、授权、背书或审核你的用户内容，也不因软件能够读取某种格式而表示该内容可以被合法使用。'),
      _AgreementSection('禁止使用',
          '你不得利用本软件侵犯知识产权或其他合法权益，不得传播违法、有害或恶意内容，不得绕过数字版权保护、访问控制或付费限制，不得攻击、干扰第三方系统，亦不得将本软件用于任何违反适用法律的活动。因你的使用行为导致的投诉、索赔、处罚或损失由你自行承担。'),
      _AgreementSection('书源、链接与第三方服务',
          '自定义书源、网络接口、外部链接、封面检索、在线内容、系统 TTS、AI 服务及其他第三方能力由相应第三方提供和控制。开发者不保证其持续可用、合法合规、安全、准确或不侵权，也不对第三方的收费、内容变更、数据处理或服务中断负责。启用前请自行审查来源、接口协议、隐私政策和使用条款；因第三方服务产生的责任由你与相应第三方处理。'),
      _AgreementSection('数据与隐私',
          '本软件采用本地优先设计，书籍、阅读进度、笔记和设置通常保存在你的设备。除非你主动启用联网书源、封面搜索、AI、同步或其他联网功能，本软件不会为了提供本地阅读而主动将书籍正文发送给开发者。启用联网功能时，相关查询、文本片段、设备网络信息或必要参数可能发送给你选择的第三方服务，具体以该服务规则为准。你应自行保护设备、访问密钥和备份；卸载、清理数据、设备故障或误操作可能导致数据永久丢失。'),
      _AgreementSection('AI 与自动化输出',
          'AI 摘要、问答、翻译、推荐或其他自动生成结果可能不准确、不完整、过时或具有误导性，仅供辅助阅读，不构成法律、医疗、投资、学术或其他专业意见。你应独立核验后再使用，不应依赖其作出高风险决定。你提交给 AI 服务的内容还受对应服务商条款约束。'),
      _AgreementSection('无担保声明',
          '在适用法律允许的最大范围内，本软件及相关资料均按“原样”和“可用”状态提供，不作任何明示、默示或法定担保，包括但不限于适销性、特定用途适用性、权利完整、不侵权、准确性、兼容性、安全性、无错误、不中断或数据不丢失。开源贡献者没有义务提供维护、更新、技术支持或缺陷修复。'),
      _AgreementSection('责任限制',
          '在适用法律允许的最大范围内，开发者、版权人及贡献者不对因安装、使用或无法使用本软件，用户内容，第三方服务，数据丢失，设备异常，业务中断或安全事件产生的任何直接、间接、附带、特殊、惩罚性或后果性损失承担责任，无论该责任基于合同、侵权或其他理论。法律不得排除的责任不受本条排除，但应限制在法律允许的最低范围。'),
      _AgreementSection('赔偿与责任承担',
          '如因你的用户内容、违法使用、侵权行为、违反本协议或使用第三方服务，导致开发者、版权人或贡献者遭受第三方索赔、行政调查、处罚、损失或合理费用，你应在适用法律允许的范围内承担相应责任并使其免受损害。'),
      _AgreementSection('变更、停止与适用规则',
          '软件功能、项目维护状态和本协议可能因开源项目发展、法律变化或风险控制需要而调整。重大条款更新时，应用可要求你重新确认；不同意新条款的，你应停止使用。你可随时卸载软件。争议优先友好协商；在不影响你依法享有的强制性消费者权益前提下，适用开发者所在地法律并由有管辖权的法院处理。若部分条款无效，其余条款仍然有效。'),
    ],
    confirmLabel: '我已完整阅读并同意以上条款，知悉用户导入内容、第三方书源及联网服务的风险由我自行承担。',
    exitLabel: '不同意',
    continueLabel: '同意并继续',
    exitDialogTitle: '不同意条款？',
    exitDialogBody: '你需要同意使用条款后才能继续使用开元阅读。若不同意，请退出应用。',
    cancelLabel: '返回阅读',
    confirmExitLabel: '确认退出',
    saveFailed: '无法保存同意状态，请稍后重试。',
  );

  static const english = _AgreementCopy(
    heroTitle: 'Keep reading on your own device.',
    heroBody:
        'OpenReading is an open-source, cross-platform, local-first ebook reader. It provides reading tools; it does not provide, host, or review books you import.',
    localTitle: 'Local first',
    localBody:
        'Books, progress, and notes generally remain on your device for you to manage and back up.',
    openSourceTitle: 'MIT licensed',
    openSourceBody:
        'Source code is provided under the MIT License and the software is supplied “as is,” without warranties.',
    versionLabel: 'Terms version 2026-07-11.1',
    agreementTitle: 'Terms of Use & Privacy Notice',
    agreementSubtitle: 'Please read before using OpenReading',
    importantNotice:
        'Important: You are solely responsible for every file or item you import, open, convert, read aloud, or obtain through a third-party source. OpenReading and its developers do not provide pirated material and do not verify the origin, legality, safety, or accuracy of user content.',
    sections: [
      _AgreementSection('Scope and acceptance',
          'These terms apply to your download, installation, and use of OpenReading and its included features. By selecting “Agree and continue,” you confirm that you have read, understood, and accepted them. If you do not agree, stop using and exit the app. A guardian must consent where required by local law.'),
      _AgreementSection('Open-source license',
          'OpenReading is released under the MIT License. You may use, copy, modify, merge, publish, distribute, sublicense, or sell copies as permitted by that license, provided required copyright and license notices are retained. These terms govern use of the distributed app and related features without restricting rights granted by the MIT License. Third-party components remain subject to their own licenses.'),
      _AgreementSection('User content and rights',
          '“User content” includes books, documents, images, metadata, links, and other material you import, download, open, convert, cache, annotate, or read aloud. You must have all rights and permissions required to use it. You are solely responsible for copyright, trademark, privacy, defamation, unlawful-content, malware, and other claims or losses involving user content. The software and its developers do not upload, sell, license, endorse, or review that content, and format support does not imply lawful permission to use a file.'),
      _AgreementSection('Prohibited use',
          'You may not use the software to infringe intellectual property or other rights; distribute unlawful, harmful, or malicious content; bypass digital rights management, access controls, or paywalls; attack or disrupt third-party systems; or engage in activity prohibited by applicable law. You are responsible for complaints, claims, penalties, and losses resulting from your conduct.'),
      _AgreementSection('Book sources and third parties',
          'Custom book sources, network APIs, external links, cover search, online content, system text-to-speech, AI services, and other integrations are provided and controlled by third parties. The developers do not warrant their availability, legality, safety, accuracy, or non-infringement and are not responsible for third-party charges, content changes, data practices, or outages. Review each provider and its terms before enabling it.'),
      _AgreementSection('Data and privacy',
          'OpenReading is local-first. Books, reading progress, notes, and settings are normally stored on your device. Unless you enable a network book source, cover search, AI, sync, or another online feature, the app does not need to send book text to the developers to provide local reading. When an online feature is used, queries, selected text, network information, or necessary parameters may be sent to the provider you selected under that provider’s policies. Protect your device, API keys, and backups; uninstalling, clearing data, device failure, or user error may permanently erase data.'),
      _AgreementSection('AI and automated output',
          'AI summaries, answers, translations, recommendations, and other generated output may be inaccurate, incomplete, outdated, or misleading. They are reading aids only and are not legal, medical, financial, academic, or other professional advice. Verify output independently and do not rely on it for high-risk decisions. Material submitted to an AI provider is also governed by that provider’s terms.'),
      _AgreementSection('Disclaimer of warranties',
          'To the fullest extent permitted by law, the software and related materials are provided “as is” and “as available,” without express, implied, or statutory warranties, including merchantability, fitness for a particular purpose, title, non-infringement, accuracy, compatibility, security, error-free operation, uninterrupted availability, or preservation of data. Open-source contributors have no duty to maintain, update, support, or fix the software.'),
      _AgreementSection('Limitation of liability',
          'To the fullest extent permitted by law, developers, copyright holders, and contributors are not liable for direct, indirect, incidental, special, punitive, or consequential loss arising from installation, use, inability to use, user content, third-party services, data loss, device issues, business interruption, or security incidents, whether under contract, tort, or another theory. Liability that cannot legally be excluded remains limited to the minimum extent permitted by law.'),
      _AgreementSection('Indemnity',
          'To the extent permitted by applicable law, you are responsible for and will hold developers, copyright holders, and contributors harmless from third-party claims, investigations, penalties, losses, and reasonable costs arising from your user content, unlawful or infringing conduct, breach of these terms, or use of third-party services.'),
      _AgreementSection('Changes, termination, and law',
          'Features, maintenance status, and these terms may change as the open-source project, law, or risk controls evolve. Material updates may require renewed consent; if you disagree, stop using the app. You may uninstall at any time. Disputes should first be resolved informally. Subject to mandatory consumer protections, the law of the developer’s location and courts with lawful jurisdiction apply. If one provision is unenforceable, the rest remain effective.'),
    ],
    confirmLabel:
        'I have read and agree to these terms and understand that I am responsible for user-imported content, third-party book sources, and online services.',
    exitLabel: 'Decline',
    continueLabel: 'Agree and continue',
    exitDialogTitle: 'Decline the terms?',
    exitDialogBody:
        'You must accept the Terms of Use to continue using OpenReading. If you do not agree, please exit the app.',
    cancelLabel: 'Go back',
    confirmExitLabel: 'Exit',
    saveFailed: 'Could not save your consent. Please try again.',
  );
}
