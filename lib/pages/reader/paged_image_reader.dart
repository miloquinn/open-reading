// 文件说明：整页图片阅读器共用骨架（漫画 CBZ/CBT/CBR 与 PDF 共用）。
// 技术要点：PageView 翻页 + InteractiveViewer 双击/双指缩放（缩放中锁翻页）；
// 复用共享 3×3 点击区域（RTL 下镜像列）、Android 音量键翻页与屏幕常亮；
// 控制层提供上/下一页、进度滑条、跳页输入、按书持久化的阅读方向
// 与页面背景设置；页数据由调用方按需提供并自行缓存。

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/core/reader/paged_image_reader_settings.dart';
import 'package:xxread/core/reader/reader_keep_screen_on.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/core/reader/reader_tap_zones.dart';
import 'package:xxread/core/reader/reader_volume_key_controller.dart';
import 'package:xxread/utils/book_open_transition.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_theme_background.dart';

/// 单页图片阅读器：加载、翻页、缩放、点击区域、页码指示与跳页。
///
/// [loadPage] 返回某页的图片字节；调用方负责缓存（重复调用应命中缓存）。
/// 翻页后会对相邻页调用 [loadPage] 做预载，结果丢弃、错误忽略。
/// [bookId] 用于按书持久化阅读方向；为 null 时方向仅在会话内生效。
class PagedImageReader extends StatefulWidget {
  const PagedImageReader({
    super.key,
    required this.title,
    required this.pageCount,
    required this.initialPage,
    required this.loadPage,
    this.onPageChanged,
    this.bookId,
  });

  final String title;
  final int pageCount;
  final int initialPage;
  final Future<Uint8List> Function(int index) loadPage;
  final ValueChanged<int>? onPageChanged;
  final int? bookId;

  @override
  State<PagedImageReader> createState() => _PagedImageReaderState();
}

class _PagedImageReaderState extends State<PagedImageReader> {
  static const Color _chromeBackground = Color(0xB8000000);
  static const Color _sheetBackground = Color(0xFF1C1C1E);

  late final PageController _pageController;
  late int _currentPage;
  bool _chromeVisible = false;

  /// 任一页处于放大状态时禁用 PageView 滑动，把手势留给平移。
  bool _zoomed = false;

  static const _settingsStore = PagedImageReaderSettingsStore();
  ReaderTapZones _tapZones = ReaderTapZones.defaults;
  ImageReaderDirection _direction = ImageReaderDirection.ltr;
  ImageReaderBackground _background = ImageReaderBackground.black;

  bool get _rtl => _direction == ImageReaderDirection.rtl;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, widget.pageCount - 1);
    _pageController = PageController(initialPage: _currentPage);
    _preloadAround(_currentPage);
    unawaited(_restoreSettings());
    unawaited(ReaderKeepScreenOnController.activate(this));
    unawaited(_activateVolumeKeys());
  }

  @override
  void dispose() {
    unawaited(ReaderVolumeKeyController.deactivate(this));
    unawaited(ReaderKeepScreenOnController.deactivate(this));
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _restoreSettings() async {
    final zones = await const ReaderSettingsStore().loadTapZones();
    final direction = await _settingsStore.loadDirection(widget.bookId);
    final background = await _settingsStore.loadBackground();
    if (!mounted) return;
    setState(() {
      _tapZones = zones;
      _direction = direction;
      _background = background;
    });
  }

  Future<void> _activateVolumeKeys() {
    return ReaderVolumeKeyController.activate(
      owner: this,
      pageTurningAvailable: true,
      onNextPage: _goToNextPage,
      onPreviousPage: _goToPreviousPage,
    );
  }

  void _preloadAround(int index) {
    for (final neighbor in <int>[index + 1, index - 1, index + 2]) {
      if (neighbor < 0 || neighbor >= widget.pageCount) continue;
      unawaited(widget.loadPage(neighbor).then((_) {}, onError: (Object _) {}));
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

  void _goToPage(int index, {bool animate = true}) {
    final target = index.clamp(0, widget.pageCount - 1);
    if (target == _currentPage || !_pageController.hasClients) return;
    if (animate) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _pageController.jumpToPage(target);
    }
  }

  void _goToNextPage() => _goToPage(_currentPage + 1);

  void _goToPreviousPage() => _goToPage(_currentPage - 1);

  void _handleTap(Offset position, Size size) {
    if (_chromeVisible) {
      setState(() => _chromeVisible = false);
      return;
    }
    // RTL 时镜像列：默认「左列上一页」在日漫方向下自然变成「点左边翻下一页」。
    final lookup = _rtl
        ? Offset(size.width - position.dx, position.dy)
        : position;
    switch (_tapZones.actionAt(lookup, size)) {
      case ReaderTapZoneAction.previousPage:
        _goToPreviousPage();
      case ReaderTapZoneAction.nextPage:
        _goToNextPage();
      case ReaderTapZoneAction.menu:
        setState(() => _chromeVisible = true);
      case ReaderTapZoneAction.previousChapter:
      case ReaderTapZoneAction.nextChapter:
      case ReaderTapZoneAction.none:
        // 整页图片书没有章节结构，章节动作与无操作一样忽略。
        break;
    }
  }

  Future<void> _toggleDirection() async {
    final next = _rtl ? ImageReaderDirection.ltr : ImageReaderDirection.rtl;
    setState(() => _direction = next);
    await _settingsStore.saveDirection(widget.bookId, next);
  }

  Future<void> _setBackground(ImageReaderBackground background) async {
    setState(() => _background = background);
    await _settingsStore.saveBackground(background);
  }

  Future<void> _showJumpDialog() async {
    final target = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _JumpPageDialog(
        pageCount: widget.pageCount,
        initialPage: _currentPage + 1,
      ),
    );
    if (target == null) return;
    _goToPage(target - 1, animate: false);
  }

  Future<void> _showSettingsSheet() async {
    final l10n = context.l10n;
    final prefs = await SharedPreferences.getInstance();
    var keepScreenOn =
        prefs.getBool(ReaderKeepScreenOnController.preferenceKey) ?? false;
    var volumeKeys =
        prefs.getBool(ReaderVolumeKeyController.preferenceKey) ?? true;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.imageReaderSettings,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _SheetSectionLabel(text: l10n.imageReaderDirectionTitle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _SheetChoiceChip(
                      label: l10n.imageReaderDirectionLtr,
                      selected: !_rtl,
                      onTap: () async {
                        if (_rtl) await _toggleDirection();
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    _SheetChoiceChip(
                      label: l10n.imageReaderDirectionRtl,
                      selected: _rtl,
                      onTap: () async {
                        if (!_rtl) await _toggleDirection();
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SheetSectionLabel(text: l10n.imageReaderBackgroundTitle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final background in ImageReaderBackground.values) ...[
                      _SheetChoiceChip(
                        label: switch (background) {
                          ImageReaderBackground.black =>
                            l10n.imageReaderBackgroundBlack,
                          ImageReaderBackground.gray =>
                            l10n.imageReaderBackgroundGray,
                          ImageReaderBackground.white =>
                            l10n.imageReaderBackgroundWhite,
                        },
                        swatch: background.color,
                        selected: _background == background,
                        onTap: () async {
                          await _setBackground(background);
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.settingsKeepScreenOnTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    l10n.settingsKeepScreenOnSubtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  value: keepScreenOn,
                  onChanged: (value) async {
                    setSheetState(() => keepScreenOn = value);
                    await ReaderKeepScreenOnController.setPreference(value);
                    await ReaderKeepScreenOnController.reapply(this);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.settingsVolumeKeyTurnTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    l10n.settingsVolumeKeyTurnSubtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  value: volumeKeys,
                  onChanged: (value) async {
                    setSheetState(() => volumeKeys = value);
                    await prefs.setBool(
                      ReaderVolumeKeyController.preferenceKey,
                      value,
                    );
                    await _activateVolumeKeys();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _background.color,
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) =>
                    _handleTap(details.localPosition, constraints.biggest),
                child: PageView.builder(
                  controller: _pageController,
                  reverse: _rtl,
                  physics: _zoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: widget.pageCount,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) => _ZoomablePageView(
                    bytes: widget.loadPage(index),
                    onZoomChanged: _setZoomed,
                    lightBackground: _background.isLight,
                  ),
                ),
              ),
            ),
          ),
          _buildChrome(context),
        ],
      ),
    );
  }

  Widget _buildChrome(BuildContext context) {
    final l10n = context.l10n;
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
                color: _chromeBackground,
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
                    GestureDetector(
                      onTap: _showJumpDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '${_currentPage + 1} / $pageCount',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.only(bottom: safeBottom + 4),
                color: _chromeBackground,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Directionality(
                      textDirection: _rtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: l10n.tapZonePreviousPage,
                            color: Colors.white,
                            disabledColor: Colors.white24,
                            icon: Icon(
                              _rtl ? Icons.chevron_right : Icons.chevron_left,
                            ),
                            onPressed: _currentPage > 0
                                ? _goToPreviousPage
                                : null,
                          ),
                          Expanded(
                            child: Slider(
                              value: (_currentPage + 1)
                                  .clamp(1, pageCount)
                                  .toDouble(),
                              min: 1,
                              max: pageCount.toDouble(),
                              divisions: pageCount > 1 ? pageCount - 1 : null,
                              label: '${_currentPage + 1}',
                              onChanged: (value) =>
                                  _goToPage(value.round() - 1, animate: false),
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.tapZoneNextPage,
                            color: Colors.white,
                            disabledColor: Colors.white24,
                            icon: Icon(
                              _rtl ? Icons.chevron_left : Icons.chevron_right,
                            ),
                            onPressed: _currentPage < pageCount - 1
                                ? _goToNextPage
                                : null,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ChromeAction(
                          icon: Icons.swap_horiz,
                          label: _rtl
                              ? l10n.imageReaderDirectionRtl
                              : l10n.imageReaderDirectionLtr,
                          onTap: _toggleDirection,
                        ),
                        _ChromeAction(
                          icon: Icons.pin_outlined,
                          label: l10n.imageReaderJumpToPage,
                          onTap: _showJumpDialog,
                        ),
                        _ChromeAction(
                          icon: Icons.settings_outlined,
                          label: l10n.imageReaderSettings,
                          onTap: _showSettingsSheet,
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
    );
  }
}

/// 跳页对话框：自持输入控制器，随路由销毁一起释放，返回 1-based 页码。
class _JumpPageDialog extends StatefulWidget {
  const _JumpPageDialog({required this.pageCount, required this.initialPage});

  final int pageCount;
  final int initialPage;

  @override
  State<_JumpPageDialog> createState() => _JumpPageDialogState();
}

class _JumpPageDialogState extends State<_JumpPageDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.initialPage}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
      ),
      child: AlertDialog(
        title: Text(l10n.imageReaderJumpToPage),
        content: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1 - ${widget.pageCount}'),
          onSubmitted: (value) =>
              Navigator.of(context).pop(int.tryParse(value)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(_controller.text)),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}

/// 底部操作项：图标 + 短标签，白色前景适配黑色控制栏。
class _ChromeAction extends StatelessWidget {
  const _ChromeAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 13),
    );
  }
}

/// 设置面板的选择胶囊；[swatch] 可选显示色样圆点。
class _SheetChoiceChip extends StatelessWidget {
  const _SheetChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.swatch,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white12,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (swatch != null) ...[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单页视图：加载中转圈，加载后 InteractiveViewer 支持双击/双指缩放。
class _ZoomablePageView extends StatefulWidget {
  const _ZoomablePageView({
    required this.bytes,
    required this.onZoomChanged,
    required this.lightBackground,
  });

  final Future<Uint8List> bytes;
  final ValueChanged<bool> onZoomChanged;
  final bool lightBackground;

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
    final placeholderColor = widget.lightBackground
        ? Colors.black26
        : Colors.white38;
    final progressColor = widget.lightBackground
        ? Colors.black26
        : Colors.white24;
    return FutureBuilder<Uint8List>(
      future: widget.bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Icon(Icons.broken_image_outlined, color: placeholderColor),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return Center(child: CircularProgressIndicator(color: progressColor));
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
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.broken_image_outlined, color: placeholderColor),
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
    required this.palette,
  });

  final String title;
  final String message;
  final ReaderThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: palette.toThemeData(typography: Theme.of(context).textTheme),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(title)),
        body: ReaderThemeBackground(
          palette: palette,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.text, height: 1.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
