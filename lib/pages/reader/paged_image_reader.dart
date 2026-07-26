// 文件说明：整页图片阅读器共用骨架（漫画 CBZ 与 PDF 共用）。
// 技术要点：PageView 翻页 + InteractiveViewer 双击/双指缩放（缩放中锁翻页）、
// 点击呼出顶栏/进度条、相邻页预载钩子；页数据由调用方按需提供并自行缓存。

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:xxread/utils/book_open_transition.dart';

/// 单页图片阅读器：加载、翻页、缩放、页码指示与跳页。
///
/// [loadPage] 返回某页的图片字节；调用方负责缓存（重复调用应命中缓存）。
/// 翻页后会对相邻页调用 [loadPage] 做预载，结果丢弃、错误忽略。
class PagedImageReader extends StatefulWidget {
  const PagedImageReader({
    super.key,
    required this.title,
    required this.pageCount,
    required this.initialPage,
    required this.loadPage,
    this.onPageChanged,
  });

  final String title;
  final int pageCount;
  final int initialPage;
  final Future<Uint8List> Function(int index) loadPage;
  final ValueChanged<int>? onPageChanged;

  @override
  State<PagedImageReader> createState() => _PagedImageReaderState();
}

class _PagedImageReaderState extends State<PagedImageReader> {
  late final PageController _pageController;
  late int _currentPage;
  bool _chromeVisible = false;

  /// 任一页处于放大状态时禁用 PageView 滑动，把手势留给平移。
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, widget.pageCount - 1);
    _pageController = PageController(initialPage: _currentPage);
    _preloadAround(_currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _preloadAround(int index) {
    for (final neighbor in <int>[index + 1, index - 1, index + 2]) {
      if (neighbor < 0 || neighbor >= widget.pageCount) continue;
      unawaited(
        widget.loadPage(neighbor).then((_) {}, onError: (Object _) {}),
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _preloadAround(index);
    widget.onPageChanged?.call(index);
  }

  void _setZoomed(bool zoomed) {
    if (_zoomed == zoomed) return;
    setState(() => _zoomed = zoomed);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _chromeVisible = !_chromeVisible),
            child: PageView.builder(
              controller: _pageController,
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: widget.pageCount,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) => _ZoomablePageView(
                bytes: widget.loadPage(index),
                onZoomChanged: _setZoomed,
              ),
            ),
          ),
        ),
        _buildChrome(context),
      ],
    );
  }

  Widget _buildChrome(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final pageCount = widget.pageCount;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: AnimatedOpacity(
          opacity: _chromeVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.only(top: safeTop),
                color: Colors.black.withValues(alpha: 0.72),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        BookOpenTransition.beginExit();
                        Navigator.of(context).maybePop();
                      },
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${_currentPage + 1} / $pageCount',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.only(bottom: safeBottom + 4),
                color: Colors.black.withValues(alpha: 0.72),
                child: Slider(
                  value: (_currentPage + 1).clamp(1, pageCount).toDouble(),
                  min: 1,
                  max: pageCount.toDouble(),
                  divisions: pageCount > 1 ? pageCount - 1 : null,
                  label: '${_currentPage + 1}',
                  onChanged: (value) =>
                      _pageController.jumpToPage(value.round() - 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单页视图：加载中转圈，加载后 InteractiveViewer 支持双击/双指缩放。
class _ZoomablePageView extends StatefulWidget {
  const _ZoomablePageView({required this.bytes, required this.onZoomChanged});

  final Future<Uint8List> bytes;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePageView> createState() => _ZoomablePageViewState();
}

class _ZoomablePageViewState extends State<_ZoomablePageView> {
  final TransformationController _transform = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _reportZoom() {
    widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.02);
  }

  void _handleDoubleTap() {
    if (_transform.value.getMaxScaleOnAxis() > 1.02) {
      _transform.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition;
      const scale = 2.4;
      if (position != null) {
        _transform.value = Matrix4.identity()
          ..translate(-position.dx * (scale - 1), -position.dy * (scale - 1))
          ..scale(scale);
      }
    }
    _reportZoom();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: widget.bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white38),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white24),
          );
        }
        return GestureDetector(
          onDoubleTapDown: (details) => _doubleTapDetails = details,
          onDoubleTap: _handleDoubleTap,
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 5,
            onInteractionEnd: (_) => _reportZoom(),
            child: Center(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 打开失败 / 无内容时的全屏提示页。
class PagedReaderMessageScaffold extends StatelessWidget {
  const PagedReaderMessageScaffold({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
