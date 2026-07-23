import 'package:flutter/material.dart';
import 'package:xxread/utils/app_themes.dart';
import 'package:xxread/utils/localization_extension.dart';

class AccentColorPickerSheet extends StatefulWidget {
  const AccentColorPickerSheet({super.key, required this.initialColor});

  final Color initialColor;

  @override
  State<AccentColorPickerSheet> createState() => _AccentColorPickerSheetState();
}

class _AccentColorPickerSheetState extends State<AccentColorPickerSheet> {
  late HSVColor _selected = HSVColor.fromColor(widget.initialColor);
  late final TextEditingController _hexController = TextEditingController(
    text: _hex(widget.initialColor),
  );
  String? _hexError;

  Color get _color => _selected.toColor();

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _select(Color color) {
    setState(() {
      _selected = HSVColor.fromColor(color);
      _hexController.text = _hex(color);
      _hexError = null;
    });
  }

  void _setHsv(HSVColor color) {
    setState(() {
      _selected = color;
      _hexController.text = _hex(color.toColor());
      _hexError = null;
    });
  }

  void _applyHex(String raw) {
    final normalized = raw.trim().replaceFirst('#', '');
    if (normalized.length != 6 ||
        !RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized)) {
      setState(() => _hexError = context.l10n.readerCustomThemeHexInvalid);
      return;
    }
    _select(Color(int.parse('FF$normalized', radix: 16)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final previewScheme = ColorScheme.fromSeed(
      seedColor: _color,
      brightness: theme.brightness,
    );

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              key: const ValueKey('accent-color-drag-area'),
              padding: const EdgeInsets.only(top: 18, bottom: 14),
              child: Center(
                child: Container(
                  key: const ValueKey('accent-color-drag-handle'),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('accent-color-scroll-view'),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.color_lens_rounded,
                          color: previewScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.l10n.settingsAccentColorTitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _color,
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.settingsAccentColorAdvice,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.l10n.settingsAccentPresetColors,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final color in AppThemes.accentColors)
                          _PresetColor(
                            color: color,
                            selected: color.toARGB32() == _color.toARGB32(),
                            onTap: () => _select(color),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      context.l10n.settingsAccentCustomColor,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SaturationValuePicker(
                      hsv: _selected,
                      onChanged: _setHsv,
                      semanticsLabel:
                          context.l10n.settingsAccentSaturationBrightness,
                    ),
                    const SizedBox(height: 14),
                    _HuePicker(
                      hue: _selected.hue,
                      onChanged: (hue) => _setHsv(_selected.withHue(hue)),
                      semanticsLabel: context.l10n.settingsAccentHue,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('accent-color-hex-field'),
                      controller: _hexController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 7,
                      decoration: InputDecoration(
                        labelText: context.l10n.readerCustomThemeHexLabel,
                        errorText: _hexError,
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
                    const SizedBox(height: 16),
                    _ColorSchemePreview(colorScheme: previewScheme),
                  ],
                ),
              ),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: DecoratedBox(
                  key: const ValueKey('accent-color-footer'),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FilledButton.icon(
                      key: const ValueKey('accent-color-confirm'),
                      onPressed: () => Navigator.of(context).pop(_color),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(context.l10n.settingsDone),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetColor extends StatelessWidget {
  const _PresetColor({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        customBorder: const CircleBorder(),
        radius: 25,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: color.computeLuminance() > 0.45
                      ? Colors.black
                      : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}

class _SaturationValuePicker extends StatelessWidget {
  const _SaturationValuePicker({
    required this.hsv,
    required this.onChanged,
    required this.semanticsLabel,
  });

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 180);

        void update(Offset localPosition) {
          final saturation = (localPosition.dx / size.width).clamp(0.0, 1.0);
          final value = (1 - localPosition.dy / size.height).clamp(0.0, 1.0);
          onChanged(hsv.withSaturation(saturation).withValue(value));
        }

        return Semantics(
          label: semanticsLabel,
          child: GestureDetector(
            key: const ValueKey('accent-color-spectrum'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => update(details.localPosition),
            onPanStart: (details) => update(details.localPosition),
            onPanUpdate: (details) => update(details.localPosition),
            child: SizedBox.fromSize(
              size: size,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CustomPaint(
                  painter: _SaturationValuePainter(hue: hsv.hue),
                  foregroundPainter: _PickerThumbPainter(
                    position: Offset(
                      hsv.saturation * size.width,
                      (1 - hsv.value) * size.height,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HuePicker extends StatelessWidget {
  const _HuePicker({
    required this.hue,
    required this.onChanged,
    required this.semanticsLabel,
  });

  final double hue;
  final ValueChanged<double> onChanged;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const height = 28.0;
        final width = constraints.maxWidth;

        void update(double dx) {
          onChanged((dx / width).clamp(0.0, 1.0) * 360);
        }

        return Semantics(
          label: semanticsLabel,
          child: GestureDetector(
            key: const ValueKey('accent-color-hue'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => update(details.localPosition.dx),
            onPanStart: (details) => update(details.localPosition.dx),
            onPanUpdate: (details) => update(details.localPosition.dx),
            child: SizedBox(
              width: width,
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: CustomPaint(
                  painter: const _HuePainter(),
                  foregroundPainter: _PickerThumbPainter(
                    position: Offset((hue / 360) * width, height / 2),
                    radius: 9,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ColorSchemePreview extends StatelessWidget {
  const _ColorSchemePreview({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.settingsAccentPreview,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _PreviewDot(
            color: colorScheme.primaryContainer,
            iconColor: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          _PreviewDot(
            color: colorScheme.secondaryContainer,
            iconColor: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          _PreviewDot(
            color: colorScheme.tertiaryContainer,
            iconColor: colorScheme.onTertiaryContainer,
          ),
        ],
      ),
    );
  }
}

class _PreviewDot extends StatelessWidget {
  const _PreviewDot({required this.color, required this.iconColor});

  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(Icons.circle, size: 10, color: iconColor),
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) =>
      oldDelegate.hue != hue;
}

class _HuePainter extends CustomPainter {
  const _HuePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PickerThumbPainter extends CustomPainter {
  const _PickerThumbPainter({required this.position, this.radius = 10});

  final Offset position;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final clamped = Offset(
      position.dx.clamp(radius, size.width - radius),
      position.dy.clamp(radius, size.height - radius),
    );
    canvas.drawCircle(
      clamped,
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawCircle(
      clamped,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _PickerThumbPainter oldDelegate) =>
      oldDelegate.position != position || oldDelegate.radius != radius;
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
