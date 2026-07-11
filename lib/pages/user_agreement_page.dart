// 文件说明：用户协议页面，同时管理首次启动协议确认状态。
// 技术要点：Flutter UI、SharedPreferences、渲染层。

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/glass_config.dart';
import '../utils/localization_extension.dart';
import '../utils/ui_style.dart';
import '../widgets/app_brand_icon.dart';

/// 用户协议页面
///
/// 在首次启动应用时显示，包含用户协议内容和同意按钮
/// 具有优美的动画效果和符合项目风格的毛玻璃设计
///
/// 核心功能：
/// - [_showAnimatedContent] 显示带动画的协议内容
/// - [_onAgreePressed] 处理用户同意操作
/// - [_onDisagreePressed] 处理用户拒绝操作
class UserAgreementPage extends StatefulWidget {
  /// 用户同意协议后的回调
  final VoidCallback onAgreed;

  /// 用户拒绝协议后的回调（可选）
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
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  bool _showContent = false;

  bool get _isMaterial3Style {
    return Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;
  }

  bool get _useBlur =>
      !_isMaterial3Style && !GlassEffectConfig.shouldDisableBlur;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
  }

  /// 初始化所有动画控制器和动画
  void _initAnimations() {
    // 淡入动画
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // 缩放动画
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // 滑动动画
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
  }

  /// 启动动画序列
  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));

    // 并行启动背景动画
    _fadeController.forward();
    _scaleController.forward();

    // 延迟启动内容动画
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _showContent = true);
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 动态背景
          _buildAnimatedBackground(),
          // 主内容
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: _buildContent(),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 构建动态背景
  Widget _buildAnimatedBackground() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final startColor = Color.alphaBlend(
      scheme.primary.withValues(alpha: isDark ? 0.28 : 0.12),
      scheme.surface,
    );
    final midColor = Color.alphaBlend(
      scheme.secondary.withValues(alpha: isDark ? 0.22 : 0.10),
      scheme.surface,
    );
    final endColor = scheme.surface;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.3, 0.7, 1.0],
                colors: [
                  startColor,
                  midColor,
                  scheme.tertiaryContainer
                      .withValues(alpha: isDark ? 0.22 : 0.16),
                  endColor,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  left: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          scheme.primary.withValues(alpha: 0.20),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -150,
                  right: -150,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          scheme.secondary.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 120,
                  right: -70,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          scheme.tertiary.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建主要内容
  Widget _buildContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          children: [
            // 应用图标和标题
            _buildHeader(),
            const SizedBox(height: 20),
            // 协议内容卡片
            Expanded(
              flex: 7,
              child: _showContent
                  ? SlideTransition(
                      position: _slideAnimation,
                      child: _buildAgreementCard(),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            // 底部按钮
            if (_showContent)
              SlideTransition(
                position: _slideAnimation,
                child: _buildButtons(),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// 构建页面头部（应用图标和标题）
  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const AppBrandIcon(
            size: 80,
            borderRadius: 20,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          context.l10n.appTitle,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                letterSpacing: 0.3,
              ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Text(
            context.l10n.agreementTagline,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  /// 构建协议内容卡片
  Widget _buildAgreementCard() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBody = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _isMaterial3Style
            ? scheme.surfaceContainerHigh
            : (isDark
                ? Colors.black.withValues(
                    alpha: GlassEffectConfig.effectiveOpacity(0.4),
                  )
                : Colors.white.withValues(
                    alpha: GlassEffectConfig.effectiveOpacity(0.85),
                  )),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isMaterial3Style
              ? scheme.outline.withValues(alpha: 0.24)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.5)),
          width: _isMaterial3Style ? 1.0 : 1.5,
        ),
      ),
      child: Column(
        children: [
          // 卡片标题 - 渐变背景
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.12),
                  scheme.secondary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.20),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: scheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.agreementCardTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.agreementCardSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 协议内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              child: _buildAgreementContent(),
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _useBlur
            ? BackdropFilter(
                enabled: _useBlur,
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: cardBody,
              )
            : cardBody,
      ),
    );
  }

  /// 构建协议内容文本
  Widget _buildAgreementContent() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 欢迎信息
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: 0.12),
                scheme.secondary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              AppBrandIcon(
                size: 54,
                borderRadius: 14,
                border:
                    Border.all(color: scheme.primary.withValues(alpha: 0.20)),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.agreementWelcomeTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.agreementWelcomeBody,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                      color: scheme.onSurface.withValues(alpha: 0.8),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 功能特色列表
        _buildFeatureItem(
          icon: Icons.layers_rounded,
          title: context.l10n.agreementFeatureFormatsTitle,
          description: context.l10n.agreementFeatureFormatsBody,
          accent: scheme.primary,
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          icon: Icons.palette_rounded,
          title: context.l10n.agreementFeatureCustomizationTitle,
          description: context.l10n.agreementFeatureCustomizationBody,
          accent: scheme.secondary,
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          icon: Icons.lock_outline_rounded,
          title: context.l10n.agreementFeatureSyncTitle,
          description: context.l10n.agreementFeatureSyncBody,
          accent: scheme.tertiary,
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          icon: Icons.record_voice_over_rounded,
          title: context.l10n.agreementFeatureTtsTitle,
          description: context.l10n.agreementFeatureTtsBody,
          accent: scheme.primary,
        ),

        const SizedBox(height: 24),

        // 提示信息
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: 0.16),
                scheme.secondary.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.tips_and_updates_rounded,
                  color: scheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.agreementTapToAgreeHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建功能特色项
  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required Color accent,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isMaterial3Style
            ? scheme.surfaceContainerLow
            : scheme.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.24),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部按钮
  Widget _buildButtons() {
    return Row(
      children: [
        // 拒绝按钮
        Expanded(
          child: _buildActionButton(
            label: context.l10n.agreementExitApp,
            onPressed: _onDisagreePressed,
            isPrimary: false,
          ),
        ),
        const SizedBox(width: 16),
        // 同意按钮
        Expanded(
          flex: 2,
          child: _buildActionButton(
            label: context.l10n.agreementAgreeAndContinue,
            onPressed: _onAgreePressed,
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final buttonBody = Material(
      color: isPrimary ? Colors.transparent : Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            border: isPrimary
                ? null
                : Border.all(
                    color: scheme.outline.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
            borderRadius: BorderRadius.circular(28),
            color: isPrimary
                ? Colors.transparent
                : (_isMaterial3Style
                    ? scheme.surfaceContainer
                    : scheme.surface.withValues(alpha: 0.8)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPrimary)
                Icon(
                  Icons.check_circle_rounded,
                  color: scheme.onPrimary,
                  size: 22,
                ),
              if (isPrimary) const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: isPrimary
                      ? scheme.onPrimary
                      : scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: isPrimary
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary,
                  scheme.secondary,
                ],
              )
            : null,
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: scheme.secondary.withValues(alpha: 0.22),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: _useBlur
            ? BackdropFilter(
                enabled: _useBlur,
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: buttonBody,
              )
            : buttonBody,
      ),
    );
  }

  /// 处理用户同意操作
  ///
  /// 保存用户同意状态到SharedPreferences，并调用成功回调
  Future<void> _onAgreePressed() async {
    try {
      // 保存用户同意状态
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('userAgreementAccepted', true);
      await prefs.setString(
        'agreementAcceptedDate',
        DateTime.now().toIso8601String(),
      );

      debugPrint('✅ 用户协议已同意，状态已保存');

      // 添加触觉反馈
      // HapticFeedback.lightImpact();

      // 调用成功回调
      widget.onAgreed();
    } catch (e) {
      debugPrint('❌ 保存协议状态失败: $e');
      // 即使保存失败，也允许用户继续使用
      widget.onAgreed();
    }
  }

  /// 处理用户拒绝操作
  ///
  /// 如果用户拒绝协议，可以退出应用或显示说明
  void _onDisagreePressed() {
    // 显示确认对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.agreementExitApp),
        content: Text(context.l10n.agreementExitDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onDisagreed != null) {
                widget.onDisagreed!();
              }
            },
            child: Text(context.l10n.agreementConfirmExit),
          ),
        ],
      ),
    );
  }
}

/// 用户协议服务
///
/// 提供协议相关的辅助方法
class UserAgreementService {
  static const String _keyAgreementAccepted = 'userAgreementAccepted';
  static const String _keyAcceptedDate = 'agreementAcceptedDate';

  /// 检查用户是否已同意协议
  static Future<bool> hasUserAcceptedAgreement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyAgreementAccepted) ?? false;
    } catch (e) {
      debugPrint('❌ 检查协议状态失败: $e');
      return false;
    }
  }

  /// 获取用户同意协议的日期
  static Future<DateTime?> getAgreementAcceptedDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateString = prefs.getString(_keyAcceptedDate);
      return dateString != null ? DateTime.parse(dateString) : null;
    } catch (e) {
      debugPrint('❌ 获取协议日期失败: $e');
      return null;
    }
  }

  /// 重置协议状态（用于测试或重新显示协议）
  static Future<void> resetAgreementStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAgreementAccepted);
      await prefs.remove(_keyAcceptedDate);
      debugPrint('🔄 协议状态已重置');
    } catch (e) {
      debugPrint('❌ 重置协议状态失败: $e');
    }
  }
}
