// 文件说明：侧边提示组件，提供全局浮层式提示反馈。
// 技术要点：Flutter UI、渲染层。

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../utils/glass_config.dart';
import '../utils/ui_style.dart';

OverlayEntry? _activeSideToastEntry;

enum SideToastKind { info, success, warning, error }

void showSideToast(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  Color? textColor,
  Duration? duration,
  IconData? icon,
  SideToastKind kind = SideToastKind.info,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _activeSideToastEntry?.remove();
  _activeSideToastEntry = null;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _SideToast(
      message: message,
      backgroundColor: backgroundColor,
      textColor: textColor,
      duration: duration == null || duration <= Duration.zero
          ? _defaultDuration(kind)
          : duration,
      icon: icon,
      kind: kind,
      onDismissed: () {
        if (identical(_activeSideToastEntry, entry)) {
          _activeSideToastEntry = null;
        }
        entry.remove();
      },
    ),
  );
  _activeSideToastEntry = entry;
  overlay.insert(entry);
}

Duration _defaultDuration(SideToastKind kind) => switch (kind) {
      SideToastKind.info ||
      SideToastKind.success =>
        const Duration(milliseconds: 2200),
      SideToastKind.warning => const Duration(milliseconds: 2800),
      SideToastKind.error => const Duration(milliseconds: 3400),
    };

class _SideToast extends StatefulWidget {
  final String message;
  final Color? backgroundColor;
  final Color? textColor;
  final Duration duration;
  final IconData? icon;
  final SideToastKind kind;
  final VoidCallback onDismissed;

  const _SideToast({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.duration,
    required this.icon,
    required this.kind,
    required this.onDismissed,
  });

  @override
  State<_SideToast> createState() => _SideToastState();
}

class _SideToastState extends State<_SideToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;
  bool _dismissed = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.22),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.duration = Duration.zero;
      _controller.reverseDuration = Duration.zero;
    }
    _controller.forward();
    if (widget.duration > Duration.zero) {
      _autoDismissTimer = Timer(widget.duration, _dismissWithAnimation);
    }
  }

  Future<void> _dismissWithAnimation() async {
    if (_dismissed) return;
    _dismissed = true;
    _autoDismissTimer?.cancel();
    if (mounted) {
      await _controller.reverse();
    }
    widget.onDismissed();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMaterial3Style = Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;
    final useBlur = !isMaterial3Style && !GlassEffectConfig.shouldDisableBlur;
    final mediaQuery = MediaQuery.of(context);
    final compact = mediaQuery.size.width < 700;
    final background = widget.backgroundColor ??
        (isMaterial3Style
            ? scheme.surfaceContainerHigh
            : GlassEffectConfig.surfaceColor(context, opacity: 0.88));
    final foreground = widget.textColor ?? scheme.onSurface;
    final accent = switch (widget.kind) {
      SideToastKind.info => scheme.primary,
      SideToastKind.success => scheme.tertiary,
      SideToastKind.warning => scheme.secondary,
      SideToastKind.error => scheme.error,
    };
    final icon = widget.icon ??
        switch (widget.kind) {
          SideToastKind.info => Icons.info_outline_rounded,
          SideToastKind.success => Icons.check_circle_outline_rounded,
          SideToastKind.warning => Icons.warning_amber_rounded,
          SideToastKind.error => Icons.error_outline_rounded,
        };
    final toastCard = Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              scheme.outline.withValues(alpha: isMaterial3Style ? 0.18 : 0.16),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color:
                scheme.shadow.withValues(alpha: isMaterial3Style ? 0.08 : 0.16),
            blurRadius: isMaterial3Style ? 14 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isMaterial3Style ? 0.13 : 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: accent,
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                widget.message,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: SafeArea(
          minimum: EdgeInsets.fromLTRB(
            compact ? 12 : 24,
            compact ? 8 : 16,
            compact ? 12 : 24,
            0,
          ),
          child: Align(
            alignment: compact ? Alignment.topCenter : Alignment.topRight,
            child: Semantics(
              container: true,
              liveRegion: true,
              label: widget.message,
              child: ExcludeSemantics(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: compact ? mediaQuery.size.width - 24 : 420,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: useBlur
                              ? BackdropFilter(
                                  enabled: useBlur,
                                  filter:
                                      ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                  child: toastCard,
                                )
                              : toastCard,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
