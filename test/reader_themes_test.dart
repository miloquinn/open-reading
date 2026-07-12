import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/utils/reader_themes.dart';

double _relativeLuminance(Color color) {
  double channel(double value) => value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color foreground, Color background) {
  final first = _relativeLuminance(foreground);
  final second = _relativeLuminance(background);
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('reader themes remain independent and readable', () {
    expect(ReaderThemes.all, hasLength(8));
    expect(
      ReaderThemes.all.map((theme) => theme.id).toSet(),
      hasLength(ReaderThemes.all.length),
    );
    expect(ReaderThemes.day.background, const Color(0xFFFFFFFF));
    expect(ReaderThemes.pureBlack.background, const Color(0xFF000000));
    expect(ReaderThemes.pureBlack.surface, const Color(0xFF000000));
    for (final theme in ReaderThemes.all) {
      expect(
        _contrast(theme.text, theme.background),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.id} body text must meet WCAG AA',
      );
      expect(
        _contrast(theme.text, theme.controlBar),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.id} control text must meet WCAG AA',
      );
    }
  });

  test('unknown saved theme falls back to day', () {
    expect(ReaderThemes.byId('missing'), ReaderThemes.day);
  });
}
