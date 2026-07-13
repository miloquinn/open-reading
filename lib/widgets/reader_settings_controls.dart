import 'package:flutter/material.dart';

import '../utils/reader_themes.dart';

class ReaderSettingsSheetFrame extends StatelessWidget {
  const ReaderSettingsSheetFrame({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 20),
  });

  final ReaderThemePalette palette;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // 拖动横条必须留在滚动视图之外：放进滚动区后，下拉手势会被
    // 滚动视图消费，弹窗无法通过拖动收起。
    return Theme(
      data: palette.toThemeData(typography: Theme.of(context).textTheme),
      child: Material(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ReaderSettingsDragHandle(palette: palette),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: padding,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReaderSettingsDragHandle extends StatelessWidget {
  const ReaderSettingsDragHandle({super.key, required this.palette});

  final ReaderThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: palette.secondaryText.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class ReaderThemeStrip extends StatelessWidget {
  const ReaderThemeStrip({
    super.key,
    required this.selectedThemeId,
    required this.labelFor,
    required this.onSelected,
  });

  final String selectedThemeId;
  final String Function(String themeId) labelFor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 1),
        physics: const BouncingScrollPhysics(),
        itemCount: ReaderThemes.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final palette = ReaderThemes.all[index];
          final selected = palette.id == selectedThemeId;
          final label = labelFor(palette.id);
          return SizedBox(
            width: 108,
            child: Semantics(
              button: true,
              selected: selected,
              label: label,
              child: InkWell(
                onTap: () => onSelected(palette.id),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? palette.accent : palette.border,
                      width: selected ? 2.2 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: palette.shadow.withValues(alpha: 0.16),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _iconFor(palette.id),
                            size: 18,
                            color: palette.secondaryText,
                          ),
                          const Spacer(),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: selected
                                  ? palette.accent
                                  : palette.controlBar,
                              shape: BoxShape.circle,
                              border: Border.all(color: palette.border),
                            ),
                            child: selected
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: palette.onAccent,
                                  )
                                : null,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        'Aa',
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 20,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(String id) => switch (id) {
        'pureBlack' => Icons.brightness_1_rounded,
        'night' => Icons.dark_mode_rounded,
        'navy' => Icons.nights_stay_rounded,
        'parchment' => Icons.auto_stories_rounded,
        'green' => Icons.eco_rounded,
        'rose' => Icons.local_florist_rounded,
        'mist' => Icons.cloud_outlined,
        _ => Icons.light_mode_rounded,
      };
}

class ReaderSettingSlider extends StatelessWidget {
  const ReaderSettingSlider({
    super.key,
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.onChangeEnd,
  });

  final String label;
  final double value;
  final String valueLabel;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  valueLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: Theme.of(context).sliderTheme.copyWith(
                  trackHeight: 4,
                  activeTrackColor: colors.primary,
                  inactiveTrackColor: colors.outlineVariant,
                  thumbColor: colors.primary,
                  overlayColor: colors.primary.withValues(alpha: 0.12),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 9),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 20),
                  showValueIndicator: ShowValueIndicator.never,
                ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}
