import 'dart:async';

import 'package:flutter/material.dart';

import '../core/reader/reader_custom_theme.dart';
import '../services/core/reader_theme_background_service.dart';
import '../utils/localization_extension.dart';
import '../utils/reader_themes.dart';
import '../widgets/reader_settings_controls.dart';
import '../widgets/reader_theme_background.dart';

class ReaderCustomThemePage extends StatefulWidget {
  const ReaderCustomThemePage({
    super.key,
    required this.initialTheme,
    this.isNewTheme = false,
  });

  final ReaderCustomTheme initialTheme;
  final bool isNewTheme;

  @override
  State<ReaderCustomThemePage> createState() => _ReaderCustomThemePageState();
}

class _ReaderCustomThemePageState extends State<ReaderCustomThemePage> {
  late ReaderCustomTheme _theme = widget.initialTheme;
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialTheme.name,
  );
  final ReaderThemeBackgroundService _backgroundService =
      ReaderThemeBackgroundService();
  final Set<String> _stagedBackgrounds = <String>{};
  bool _committed = false;

  ReaderThemePalette get _palette {
    return ReaderThemes.fromCustomTheme(_theme);
  }

  Future<void> _pickColor({
    required String title,
    required Color current,
    required ValueChanged<Color> onChanged,
  }) async {
    final selected = await showModalBottomSheet<Color>(
      context: context,
      backgroundColor: _palette.surface,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ReaderColorPickerSheet(
        title: title,
        current: current,
        palette: _palette,
      ),
    );
    if (selected != null && mounted) setState(() => onChanged(selected));
  }

  Future<void> _pickBackgroundImage() async {
    if (!_backgroundService.isSupported) {
      _showMessage(context.l10n.readerCustomThemeImageUnsupported);
      return;
    }
    try {
      final imagePath = await _backgroundService.pickAndStore();
      if (imagePath == null || !mounted) return;
      final previous = _theme.backgroundImagePath;
      setState(() {
        _stagedBackgrounds.add(imagePath);
        _theme = _theme.copyWith(backgroundImagePath: imagePath);
      });
      if (previous != null && _stagedBackgrounds.remove(previous)) {
        await _backgroundService.delete(previous);
      }
    } on ReaderThemeBackgroundException catch (error) {
      if (!mounted) return;
      _showMessage(switch (error.code) {
        ReaderThemeBackgroundError.fileTooLarge =>
          context.l10n.readerCustomThemeImageTooLarge,
        ReaderThemeBackgroundError.unsupportedFormat =>
          context.l10n.readerCustomThemeImageFormat,
        _ => context.l10n.readerCustomThemeImageFailed,
      });
    } catch (_) {
      if (mounted) _showMessage(context.l10n.readerCustomThemeImageFailed);
    }
  }

  Future<void> _removeBackgroundImage() async {
    final previous = _theme.backgroundImagePath;
    setState(() => _theme = _theme.copyWith(backgroundImagePath: null));
    if (previous != null && _stagedBackgrounds.remove(previous)) {
      await _backgroundService.delete(previous);
    }
  }

  void _resetTheme() {
    final staged = [..._stagedBackgrounds];
    _stagedBackgrounds.clear();
    setState(() {
      _theme = ReaderCustomTheme.defaults.copyWith(
        id: _theme.id,
        name: _nameController.text,
      );
    });
    for (final imagePath in staged) {
      unawaited(_backgroundService.delete(imagePath));
    }
  }

  void _saveTheme() {
    final normalizedName = _nameController.text.trim();
    _committed = true;
    Navigator.of(context).pop(
      _theme.copyWith(
        name: normalizedName.isEmpty
            ? context.l10n.readerThemeCustom
            : normalizedName,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    if (!_committed) {
      for (final imagePath in _stagedBackgrounds) {
        unawaited(_backgroundService.delete(imagePath));
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final themeData = palette.toThemeData(
      typography: Theme.of(context).textTheme,
    );
    final contrast = _contrastRatio(_theme.text, _theme.background);
    return Theme(
      data: themeData,
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          title: Text(
            widget.isNewTheme
                ? context.l10n.readerCustomThemeNewTitle
                : context.l10n.readerCustomThemeEditTitle,
          ),
          actions: [
            TextButton(
              onPressed: _resetTheme,
              child: Text(context.l10n.readerCustomThemeReset),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
            children: [
              TextField(
                key: const ValueKey('custom-theme-name'),
                controller: _nameController,
                maxLength: 24,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.l10n.readerCustomThemeName,
                  hintText: context.l10n.readerCustomThemeNameHint,
                  counterText: '',
                  prefixIcon: const Icon(Icons.label_outline_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _ReaderThemePreview(palette: palette),
              const SizedBox(height: 24),
              Text(
                context.l10n.readerCustomThemeColors,
                style: themeData.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _ColorSettingTile(
                key: const ValueKey('custom-theme-text-color'),
                palette: palette,
                icon: Icons.format_color_text_rounded,
                title: context.l10n.readerCustomThemeTextColor,
                subtitle: context.l10n.readerCustomThemeTextColorHint,
                color: _theme.text,
                onTap: () => _pickColor(
                  title: context.l10n.readerCustomThemeTextColor,
                  current: _theme.text,
                  onChanged: (color) => _theme = _theme.copyWith(text: color),
                ),
              ),
              const SizedBox(height: 10),
              _BackgroundImageSetting(
                palette: palette,
                hasImage: _theme.hasBackgroundImage,
                supported: _backgroundService.isSupported,
                onChoose: _pickBackgroundImage,
                onRemove: _removeBackgroundImage,
              ),
              if (_theme.hasBackgroundImage) ...[
                const SizedBox(height: 8),
                ReaderSettingSlider(
                  label: context.l10n.readerCustomThemeImageStrength,
                  value: _theme.backgroundImageOpacity,
                  valueLabel:
                      '${(_theme.backgroundImageOpacity * 100).round()}%',
                  min: 0.1,
                  max: 0.75,
                  divisions: 13,
                  onChanged: (value) => setState(
                    () => _theme = _theme.copyWith(
                      backgroundImageOpacity: value,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _ColorSettingTile(
                key: const ValueKey('custom-theme-background-color'),
                palette: palette,
                icon: Icons.menu_book_rounded,
                title: context.l10n.readerCustomThemeBackground,
                subtitle: context.l10n.readerCustomThemeBackgroundHint,
                color: _theme.background,
                onTap: () => _pickColor(
                  title: context.l10n.readerCustomThemeBackground,
                  current: _theme.background,
                  onChanged: (color) =>
                      _theme = _theme.copyWith(background: color),
                ),
              ),
              const SizedBox(height: 10),
              _ColorSettingTile(
                key: const ValueKey('custom-theme-control-color'),
                palette: palette,
                icon: Icons.tune_rounded,
                title: context.l10n.readerCustomThemeControlBar,
                subtitle: context.l10n.readerCustomThemeControlBarHint,
                color: _theme.controlBar,
                onTap: () => _pickColor(
                  title: context.l10n.readerCustomThemeControlBar,
                  current: _theme.controlBar,
                  onChanged: (color) =>
                      _theme = _theme.copyWith(controlBar: color),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: contrast >= 4.5
                      ? palette.controlFill.withValues(alpha: 0.7)
                      : const Color(0xFFFFB74D).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: contrast >= 4.5
                        ? palette.border
                        : const Color(0xFFFF9800),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      contrast >= 4.5
                          ? Icons.visibility_rounded
                          : Icons.warning_amber_rounded,
                      color: contrast >= 4.5
                          ? palette.text
                          : const Color(0xFFE67800),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        contrast >= 4.5
                            ? context.l10n.readerCustomThemeContrastGood
                            : context.l10n.readerCustomThemeContrastLow,
                        style: themeData.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      contrast.toStringAsFixed(1),
                      style: themeData.textTheme.labelLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: FilledButton.icon(
            key: const ValueKey('save-custom-reader-theme'),
            onPressed: _saveTheme,
            icon: const Icon(Icons.check_rounded),
            label: Text(context.l10n.readerCustomThemeSave),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderThemePreview extends StatelessWidget {
  const _ReaderThemePreview({required this.palette});

  final ReaderThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ReaderThemeBackground(
        palette: palette,
        child: Column(
          children: [
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: palette.controlBar.withValues(alpha: 0.94),
              child: Row(
                children: [
                  Icon(Icons.arrow_back_rounded, size: 19, color: palette.text),
                  const Spacer(),
                  Text(
                    context.l10n.readerCustomThemePreview,
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.more_horiz_rounded, size: 19, color: palette.text),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.readerCustomThemePreviewChapter,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    context.l10n.readerCustomThemePreviewBody,
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 16,
                      height: 1.75,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      '12 / 36',
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundImageSetting extends StatelessWidget {
  const _BackgroundImageSetting({
    required this.palette,
    required this.hasImage,
    required this.supported,
    required this.onChoose,
    required this.onRemove,
  });

  final ReaderThemePalette palette;
  final bool hasImage;
  final bool supported;
  final VoidCallback onChoose;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: palette.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ReaderThemeBackground(
                  palette: palette,
                  child: Icon(
                    hasImage ? Icons.image_rounded : Icons.add_photo_alternate,
                    color: palette.text.withValues(alpha: 0.78),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.readerCustomThemeBackgroundImage,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  supported
                      ? context.l10n.readerCustomThemeBackgroundImageHint
                      : context.l10n.readerCustomThemeImageUnsupported,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: supported ? onChoose : null,
                      icon: Icon(hasImage
                          ? Icons.swap_horiz_rounded
                          : Icons.upload_rounded),
                      label: Text(
                        hasImage
                            ? context.l10n.readerCustomThemeReplaceImage
                            : context.l10n.readerCustomThemeChooseImage,
                      ),
                    ),
                    if (hasImage)
                      TextButton.icon(
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(context.l10n.readerCustomThemeRemoveImage),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSettingTile extends StatelessWidget {
  const _ColorSettingTile({
    super.key,
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final ReaderThemePalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.controlFill,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: palette.text, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.border, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.12),
                      blurRadius: 7,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: palette.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderColorPickerSheet extends StatefulWidget {
  const _ReaderColorPickerSheet({
    required this.title,
    required this.current,
    required this.palette,
  });

  final String title;
  final Color current;
  final ReaderThemePalette palette;

  @override
  State<_ReaderColorPickerSheet> createState() =>
      _ReaderColorPickerSheetState();
}

class _ReaderColorPickerSheetState extends State<_ReaderColorPickerSheet> {
  static const _presets = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFFF7F1E3),
    Color(0xFFEAD9B8),
    Color(0xFFE9F1E5),
    Color(0xFFDCEBE6),
    Color(0xFFDDE8F2),
    Color(0xFFF4E8E7),
    Color(0xFFE8E0EF),
    Color(0xFFB9A27A),
    Color(0xFF8D9B82),
    Color(0xFF708A96),
    Color(0xFF8B6F72),
    Color(0xFF4A4238),
    Color(0xFF34413A),
    Color(0xFF293B4A),
    Color(0xFF3B3344),
    Color(0xFF202124),
    Color(0xFF151816),
    Color(0xFF000000),
    Color(0xFF5C4033),
    Color(0xFF70451F),
    Color(0xFF3F63B8),
    Color(0xFF527451),
    Color(0xFF8B5A60),
  ];

  late Color _selected = widget.current;
  late final TextEditingController _hexController = TextEditingController(
    text: _hex(widget.current),
  );
  String? _error;

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _select(Color color) {
    setState(() {
      _selected = color;
      _hexController.text = _hex(color);
      _error = null;
    });
  }

  void _applyHex(String raw) {
    final cleaned = raw.trim().replaceFirst('#', '');
    final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    if (normalized.length != 8 ||
        !RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(normalized)) {
      setState(() => _error = context.l10n.readerCustomThemeHexInvalid);
      return;
    }
    _select(Color(int.parse(normalized, radix: 16)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Theme(
      data: palette.toThemeData(typography: Theme.of(context).textTheme),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.secondaryText.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: _presets.length,
              itemBuilder: (context, index) {
                final color = _presets[index];
                final selected = color.toARGB32() == _selected.toARGB32();
                return InkWell(
                  onTap: () => _select(color),
                  customBorder: const CircleBorder(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? palette.accent : palette.border,
                        width: selected ? 3 : 1.5,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            color: color.computeLuminance() > 0.45
                                ? Colors.black
                                : Colors.white,
                          )
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _hexController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 9,
              decoration: InputDecoration(
                labelText: context.l10n.readerCustomThemeHexLabel,
                hintText: '#F6F0E4',
                errorText: _error,
                counterText: '',
                prefixIcon: const Icon(Icons.tag_rounded),
                suffixIcon: IconButton(
                  onPressed: () => _applyHex(_hexController.text),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onSubmitted: _applyHex,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      ),
    );
  }
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

double _contrastRatio(Color first, Color second) {
  final l1 = first.computeLuminance();
  final l2 = second.computeLuminance();
  final light = l1 > l2 ? l1 : l2;
  final dark = l1 > l2 ? l2 : l1;
  return (light + 0.05) / (dark + 0.05);
}
