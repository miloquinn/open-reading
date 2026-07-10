// 文件说明：滚动文本组件，用于超长文本的自动滚动显示。
// 技术要点：Flutter UI。

import 'package:flutter/material.dart';

/// 自动滚动文本组件，当文本过长时会自动滚动显示
class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final Duration pauseDuration;

  const ScrollingText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(seconds: 3),
    this.pauseDuration = const Duration(seconds: 1),
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  bool _needsScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfNeedsScrolling();
    });
  }

  void _checkIfNeedsScrolling() {
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      setState(() {
        _needsScrolling = true;
      });
      _startScrolling();
    }
  }

  void _startScrolling() async {
    if (!_needsScrolling || !mounted) return;

    await Future.delayed(widget.pauseDuration);
    if (!mounted) return;

    _animationController.forward().then((_) async {
      if (!mounted) return;
      await Future.delayed(widget.pauseDuration);
      if (!mounted) return;
      _animationController.reverse().then((_) {
        if (mounted) {
          _startScrolling();
        }
      });
    });
  }

  @override
  void didUpdateWidget(ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _animationController.reset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkIfNeedsScrolling();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        if (_scrollController.hasClients && _needsScrolling) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(maxScroll * _animationController.value);
        }
        return child!;
      },
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _scrollController,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          style: widget.style,
          maxLines: 1,
        ),
      ),
    );
  }
}
