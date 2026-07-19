import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class FirstHomeSupportOverlay extends StatefulWidget {
  const FirstHomeSupportOverlay({
    super.key,
    required this.supportLabel,
    required this.laterLabel,
    required this.paperSemanticLabel,
    required this.onSupport,
    required this.onLater,
    this.paperAssetPath = 'assets/images/cyber_begging_paper.png',
  });

  final String supportLabel;
  final String laterLabel;
  final String paperSemanticLabel;
  final VoidCallback onSupport;
  final VoidCallback onLater;
  final String paperAssetPath;

  @override
  State<FirstHomeSupportOverlay> createState() =>
      _FirstHomeSupportOverlayState();
}

class _FirstHomeSupportOverlayState extends State<FirstHomeSupportOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _unrollController;
  late final AnimationController _floatController;
  late final AnimationController _exitController;
  bool _motionConfigured = false;
  bool _isClosing = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _unrollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionConfigured) return;
    _motionConfigured = true;
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion) {
      _unrollController.value = 1;
    } else {
      _unrollController.forward().whenComplete(() {
        if (mounted && !_isClosing) {
          _floatController.repeat();
        }
      });
    }
  }

  @override
  void dispose() {
    _unrollController.dispose();
    _floatController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _close(VoidCallback callback) async {
    if (_isClosing) return;
    _isClosing = true;
    _floatController.stop();
    if (!_reduceMotion) {
      await _exitController.reverse();
    }
    if (mounted) callback();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: FadeTransition(
        opacity: _exitController,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(
            CurvedAnimation(
              parent: _exitController,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: ColoredBox(
                  color: scheme.scrim.withValues(
                    alpha: scheme.brightness == Brightness.dark ? 0.62 : 0.42,
                  ),
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Center(
                  child: _buildAnimatedContents(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedContents(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const paperAspectRatio = 960 / 1326;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final maxPaperHeight = math.max(180.0, availableHeight - 78);
        final paperWidth = math.max(
          1.0,
          math.min(
            math.min(availableWidth, 430.0),
            maxPaperHeight * paperAspectRatio,
          ),
        );
        final paperHeight = paperWidth / paperAspectRatio;

        return AnimatedBuilder(
          animation: Listenable.merge([_unrollController, _floatController]),
          builder: (context, _) {
            final rawProgress = _unrollController.value;
            final revealProgress = Curves.easeOutCubic.transform(rawProgress);
            final buttonProgress = const Interval(
              0.72,
              1,
              curve: Curves.easeOutCubic,
            ).transform(rawProgress);
            final floatOffset = _reduceMotion || rawProgress < 1
                ? 0.0
                : math.sin(_floatController.value * math.pi * 2) * 3.5;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: Offset(0, floatOffset),
                  child: Semantics(
                    image: true,
                    label: widget.paperSemanticLabel,
                    child: _UnrollingPaper(
                      width: paperWidth,
                      height: paperHeight,
                      progress: revealProgress,
                      assetPath: widget.paperAssetPath,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Opacity(
                  opacity: buttonProgress,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - buttonProgress)),
                    child: IgnorePointer(
                      ignoring: buttonProgress < 0.95,
                      child: SizedBox(
                        width: math.min(paperWidth, 390.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                key: const ValueKey(
                                  'first-home-support-now-button',
                                ),
                                onPressed: () => _close(widget.onSupport),
                                icon: const Icon(
                                  Icons.favorite_rounded,
                                  size: 19,
                                ),
                                label: Text(widget.supportLabel),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                key: const ValueKey(
                                  'first-home-support-later-button',
                                ),
                                onPressed: () => _close(widget.onLater),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onSurface,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surface
                                      .withValues(alpha: 0.82),
                                  side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.42),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: Text(widget.laterLabel),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _UnrollingPaper extends StatelessWidget {
  const _UnrollingPaper({
    required this.width,
    required this.height,
    required this.progress,
    required this.assetPath,
  });

  final double width;
  final double height;
  final double progress;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final visibleProgress = math.max(0.035, progress);
    final rollHeight = math.max(1.0, math.min(18.0, width * 0.045));
    final rollCenter = (height * visibleProgress).clamp(
      rollHeight / 2,
      height - rollHeight / 2,
    );
    final rollOpacity = 1 - const Interval(0.84, 1).transform(progress);
    final paperShadowOpacity = const Interval(
      0.42,
      1,
      curve: Curves.easeOut,
    ).transform(progress);

    return SizedBox(
      width: width + 16,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            width: width,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.2 * paperShadowOpacity,
                    ),
                    blurRadius: 30,
                    spreadRadius: 1,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRect(
                clipper: _PaperRevealClipper(visibleProgress),
                child: Image.asset(
                  assetPath,
                  width: width,
                  height: height,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          if (rollOpacity > 0)
            Positioned(
              top: rollCenter - rollHeight / 2,
              width: width + 10,
              height: rollHeight,
              child: Opacity(
                opacity: rollOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(rollHeight / 2),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFFEF8),
                        Color(0xFFE8E0D2),
                        Color(0xFFB9AE9B),
                        Color(0xFFF6F0E5),
                      ],
                      stops: [0, 0.34, 0.63, 1],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaperRevealClipper extends CustomClipper<Rect> {
  const _PaperRevealClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * progress);

  @override
  bool shouldReclip(covariant _PaperRevealClipper oldClipper) =>
      oldClipper.progress != progress;
}
