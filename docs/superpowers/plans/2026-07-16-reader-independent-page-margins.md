# Reader Independent Page Margins Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the native reader's vertical margin into independently persisted top and bottom controls, use close-to-screen defaults, and move the page indicator closer to the iOS bottom edge without overlapping the Home Indicator.

**Architecture:** Add a small immutable margin-settings value object for defaults, clamping, and legacy migration. Refactor `ReaderSafeAreaMetrics` to consume explicit top and bottom margins and keep page-indicator placement independent. Wire the values through `NativeReaderPage`, expose two localized sliders, and retain the existing safe-area-based cross-platform calculation.

**Tech Stack:** Flutter, Dart, `SharedPreferences`, Flutter localization generation, `flutter_test`, `xcrun devicectl`.

## Global Constraints

- Top margin range is exactly `0–40pt`, step `1pt`, default `4pt`.
- Bottom margin range is exactly `0–40pt`, step `1pt`, default `0pt`.
- Final top padding is the system top safe-area inset plus the user top margin.
- The page indicator does not move when the user changes the bottom margin.
- Page-indicator bottom is `max(8pt, systemBottomInset - 20pt)`; SloanePro therefore uses approximately `14pt`.
- Legacy `28pt` vertical margin migrates to `4pt` top and `0pt` bottom; legacy user-added margin is preserved on both new values.
- Do not add dependencies or platform/model-specific layout branches.
- Keep unrelated dirty-worktree changes out of every commit.

---

### Task 1: Margin settings model and safe-area calculation

**Files:**
- Create: `lib/core/reader/reader_margin_settings.dart`
- Modify: `lib/core/reader/reader_safe_area.dart`
- Create: `test/reader_margin_settings_test.dart`
- Modify: `test/reader_safe_area_metrics_test.dart`

**Interfaces:**
- Produces: `ReaderMarginSettings({required double top, required double bottom})` with `defaultTop`, `defaultBottom`, `min`, `max`, and `fromStored({double? top, double? bottom, double? legacyVertical})`.
- Produces: `ReaderSafeAreaMetrics({required EdgeInsets viewPadding, required double topMargin, required double bottomMargin})` with `contentTop`, `contentBottom`, `pageNumberBottom`, and `paginationSignature`.

- [ ] **Step 1: Write failing migration tests**

Create `test/reader_margin_settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_margin_settings.dart';

void main() {
  group('ReaderMarginSettings', () {
    test('uses close-to-screen defaults without stored values', () {
      final margins = ReaderMarginSettings.fromStored();
      expect(margins.top, 4);
      expect(margins.bottom, 0);
    });

    test('migrates the legacy default to the new defaults', () {
      final margins = ReaderMarginSettings.fromStored(legacyVertical: 28);
      expect(margins.top, 4);
      expect(margins.bottom, 0);
    });

    test('preserves legacy user-added spacing on both edges', () {
      final margins = ReaderMarginSettings.fromStored(legacyVertical: 38);
      expect(margins.top, 14);
      expect(margins.bottom, 10);
    });

    test('prefers and clamps independently stored values', () {
      final margins = ReaderMarginSettings.fromStored(top: 48, bottom: -2);
      expect(margins.top, 40);
      expect(margins.bottom, 0);
    });
  });
}
```

- [ ] **Step 2: Update safe-area tests for independent inputs**

Replace the old `verticalMargin` cases in `test/reader_safe_area_metrics_test.dart` with exact expectations:

```dart
const iphone = ReaderSafeAreaMetrics(
  viewPadding: EdgeInsets.only(top: 59, bottom: 34),
  topMargin: 4,
  bottomMargin: 0,
);
expect(iphone.contentTop, 63);
expect(iphone.pageNumberBottom, 14);
expect(iphone.contentBottom, 34);

const adjusted = ReaderSafeAreaMetrics(
  viewPadding: EdgeInsets.only(top: 59, bottom: 34),
  topMargin: 24,
  bottomMargin: 20,
);
expect(adjusted.contentTop, 83);
expect(adjusted.pageNumberBottom, 14);
expect(adjusted.contentBottom, 54);
```

Also retain Android and no-bottom-inset cases. Android with `top: 24`, `bottom: 24` must produce `contentTop: 28`, `pageNumberBottom: 8`, and `contentBottom: 24`. A device without insets must produce `contentTop: 4`, `pageNumberBottom: 8`, and `contentBottom: 24`.

- [ ] **Step 3: Run tests and verify failure**

Run:

```bash
flutter test --no-pub test/reader_margin_settings_test.dart test/reader_safe_area_metrics_test.dart
```

Expected: FAIL because `reader_margin_settings.dart` and the new `ReaderSafeAreaMetrics` constructor do not exist.

- [ ] **Step 4: Implement the margin settings value object**

Create `lib/core/reader/reader_margin_settings.dart`:

```dart
import 'package:flutter/foundation.dart';

@immutable
class ReaderMarginSettings {
  static const double min = 0;
  static const double max = 40;
  static const double defaultTop = 4;
  static const double defaultBottom = 0;
  static const double legacyDefault = 28;

  const ReaderMarginSettings({required this.top, required this.bottom});

  factory ReaderMarginSettings.fromStored({
    double? top,
    double? bottom,
    double? legacyVertical,
  }) {
    final legacyExtra = ((legacyVertical ?? legacyDefault) - legacyDefault)
        .clamp(min, max);
    return ReaderMarginSettings(
      top: (top ?? defaultTop + legacyExtra).clamp(min, max),
      bottom: (bottom ?? defaultBottom + legacyExtra).clamp(min, max),
    );
  }

  final double top;
  final double bottom;
}
```

- [ ] **Step 5: Refactor the safe-area metrics**

Change `ReaderSafeAreaMetrics` to store `topMargin` and `bottomMargin`, set `_pageNumberSafeAreaOverlap` to `20.0`, and compute:

```dart
double get contentTop => viewPadding.top + topMargin;

double get pageNumberBottom => math.max(
      _minimumPageNumberBottom,
      viewPadding.bottom - _pageNumberSafeAreaOverlap,
    );

double get contentBottom => math.max(
      viewPadding.bottom + bottomMargin,
      pageNumberBottom + pageNumberReserve + pageNumberGap,
    );
```

Remove `visualTopGap` and `visualBottomGap`. Keep `paginationSignature` based on final top and bottom values.

- [ ] **Step 6: Format and run focused tests**

Run:

```bash
dart format lib/core/reader/reader_margin_settings.dart lib/core/reader/reader_safe_area.dart test/reader_margin_settings_test.dart test/reader_safe_area_metrics_test.dart
flutter test --no-pub test/reader_margin_settings_test.dart test/reader_safe_area_metrics_test.dart
```

Expected: all margin and safe-area tests pass.

- [ ] **Step 7: Commit only Task 1 files**

```bash
git add lib/core/reader/reader_margin_settings.dart lib/core/reader/reader_safe_area.dart test/reader_margin_settings_test.dart test/reader_safe_area_metrics_test.dart
git diff --cached --check
git commit -m "Let reader edges adapt independently"
```

Use Lore trailers recording safe-area constraints, migration behavior, focused tests, and narrow scope.

---

### Task 2: Persist and expose independent reader controls

**Files:**
- Modify: `lib/pages/native_reader_page.dart`
- Modify: `lib/widgets/reader_settings_controls.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ja.arb`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_zh_TW.arb`
- Regenerate: `lib/l10n/app_localizations.dart`
- Regenerate: `lib/l10n/app_localizations_en.dart`
- Regenerate: `lib/l10n/app_localizations_ja.dart`
- Regenerate: `lib/l10n/app_localizations_zh.dart`
- Create: `test/reader_margin_controls_test.dart`

**Interfaces:**
- Consumes: `ReaderMarginSettings.fromStored(...)` and `ReaderSafeAreaMetrics(topMargin:, bottomMargin:)` from Task 1.
- Produces: `ReaderMarginControls` widget with independent top/bottom values and callbacks.
- Persists: `native_reader_top_margin` and `native_reader_bottom_margin`; reads `native_reader_vertical_margin` only for migration.

- [ ] **Step 1: Write the margin-controls widget test**

Create `test/reader_margin_controls_test.dart` that pumps `ReaderMarginControls` with `topLabel: '上页边距'`, `bottomLabel: '下页边距'`, `topMargin: 4`, and `bottomMargin: 0`; assert both labels and value chips are present, then drag the first slider and assert only the top callback changes.

Use two keyed sliders in the production widget:

```dart
key: const ValueKey('reader-top-margin-slider')
key: const ValueKey('reader-bottom-margin-slider')
```

- [ ] **Step 2: Run the widget test and verify failure**

Run:

```bash
flutter test --no-pub test/reader_margin_controls_test.dart
```

Expected: FAIL because `ReaderMarginControls` does not exist.

- [ ] **Step 3: Add `ReaderMarginControls`**

In `lib/widgets/reader_settings_controls.dart`, build a focused stateless widget that renders two `ReaderSettingSlider` instances. Each uses `min: 0`, `max: 40`, `divisions: 40`, integer value labels, independent `onChanged`, and independent `onChangeEnd` callbacks. Add an optional `key` parameter to `ReaderSettingSlider` usage through its existing constructor rather than changing slider behavior.

```dart
class ReaderMarginControls extends StatelessWidget {
  const ReaderMarginControls({
    super.key,
    required this.topLabel,
    required this.bottomLabel,
    required this.topMargin,
    required this.bottomMargin,
    required this.onTopChanged,
    required this.onBottomChanged,
    this.onTopChangeEnd,
    this.onBottomChangeEnd,
  });

  final String topLabel;
  final String bottomLabel;
  final double topMargin;
  final double bottomMargin;
  final ValueChanged<double> onTopChanged;
  final ValueChanged<double> onBottomChanged;
  final ValueChanged<double>? onTopChangeEnd;
  final ValueChanged<double>? onBottomChangeEnd;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ReaderSettingSlider(
            key: const ValueKey('reader-top-margin-slider'),
            label: topLabel,
            value: topMargin,
            valueLabel: topMargin.round().toString(),
            min: 0,
            max: 40,
            divisions: 40,
            onChanged: onTopChanged,
            onChangeEnd: onTopChangeEnd,
          ),
          ReaderSettingSlider(
            key: const ValueKey('reader-bottom-margin-slider'),
            label: bottomLabel,
            value: bottomMargin,
            valueLabel: bottomMargin.round().toString(),
            min: 0,
            max: 40,
            divisions: 40,
            onChanged: onBottomChanged,
            onChangeEnd: onBottomChangeEnd,
          ),
        ],
      );
}
```

- [ ] **Step 4: Add localized labels and regenerate localization code**

Add these keys beside the existing margin labels:

```json
"readerTopMarginLabel": "Top margin",
"readerBottomMarginLabel": "Bottom margin"
```

Use `上余白` / `下余白` in Japanese, `上页边距` / `下页边距` in Simplified Chinese, and `上頁邊距` / `下頁邊距` in Traditional Chinese. Run:

```bash
flutter gen-l10n
```

Expected: generated localization getters exist for both labels with no untranslated-message additions.

- [ ] **Step 5: Replace the single native-reader margin state**

In `lib/pages/native_reader_page.dart`:

```dart
static const _topMarginKey = 'native_reader_top_margin';
static const _bottomMarginKey = 'native_reader_bottom_margin';
static const _legacyVerticalMarginKey = 'native_reader_vertical_margin';

double _topMargin = ReaderMarginSettings.defaultTop;
double _bottomMargin = ReaderMarginSettings.defaultBottom;
```

Load the two stored values and the legacy value through `ReaderMarginSettings.fromStored`. If either new key is absent, immediately persist both resolved values so migration occurs only once.

```dart
final storedTopMargin = prefs.getDouble(_topMarginKey);
final storedBottomMargin = prefs.getDouble(_bottomMarginKey);
final margins = ReaderMarginSettings.fromStored(
  top: storedTopMargin,
  bottom: storedBottomMargin,
  legacyVertical: prefs.getDouble(_legacyVerticalMarginKey),
);
if (storedTopMargin == null || storedBottomMargin == null) {
  await prefs.setDouble(_topMarginKey, margins.top);
  await prefs.setDouble(_bottomMarginKey, margins.bottom);
}
```

- [ ] **Step 6: Wire layout, persistence, cache signatures, and controls**

Change `_updateLayout` to accept `double? topMargin` and `double? bottomMargin`, clamp each with `ReaderMarginSettings.min/max`, persist both new keys, reset the page index, and restore the canonical anchor. Include both values in `_layoutSignature`.

```dart
Future<void> _updateLayout({
  double? fontSize,
  double? lineHeight,
  double? horizontalMargin,
  double? topMargin,
  double? bottomMargin,
}) async {
  setState(() {
    _fontSize = fontSize ?? _fontSize;
    _lineHeight = (lineHeight ?? _lineHeight).clamp(1.4, 2.1);
    _horizontalMargin = (horizontalMargin ?? _horizontalMargin).clamp(8, 48);
    _topMargin = (topMargin ?? _topMargin)
        .clamp(ReaderMarginSettings.min, ReaderMarginSettings.max);
    _bottomMargin = (bottomMargin ?? _bottomMargin)
        .clamp(ReaderMarginSettings.min, ReaderMarginSettings.max);
    _pageIndex = 0;
    _restoreAnchorAfterLayout = true;
  });
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(_fontSizeKey, _fontSize);
  await prefs.setDouble(_lineHeightKey, _lineHeight);
  await prefs.setDouble(_horizontalMarginKey, _horizontalMargin);
  await prefs.setDouble(_topMarginKey, _topMargin);
  await prefs.setDouble(_bottomMarginKey, _bottomMargin);
}
```

Construct safe-area metrics with:

```dart
ReaderSafeAreaMetrics(
  viewPadding: MediaQuery.viewPaddingOf(context),
  topMargin: _topMargin,
  bottomMargin: _bottomMargin,
)
```

Pass `_topMargin + _bottomMargin` to the legacy-named `ReaderLayoutFingerprint.verticalMargin` field and retain `_readerSafeArea.paginationSignature` in `extra`, ensuring distinct top/bottom combinations cannot share cached pages.

Replace the single vertical slider with `ReaderMarginControls`, using localized labels and calling `_updateLayout(topMargin: value)` or `_updateLayout(bottomMargin: value)` only for the corresponding edge.

- [ ] **Step 7: Run focused tests and localization checks**

Run:

```bash
dart format lib/pages/native_reader_page.dart lib/widgets/reader_settings_controls.dart test/reader_margin_controls_test.dart
flutter test --no-pub test/reader_margin_controls_test.dart test/reader_margin_settings_test.dart test/reader_safe_area_metrics_test.dart test/reader_layout_test.dart test/native_text_paginator_test.dart
flutter analyze --no-pub
```

Expected: all tests pass and analysis reports `No issues found!`.

- [ ] **Step 8: Commit only Task 2 files and exact native-reader hunks**

Use interactive staging for `native_reader_page.dart` because the worktree already contains unrelated edits:

```bash
git add lib/widgets/reader_settings_controls.dart lib/l10n/app_en.arb lib/l10n/app_ja.arb lib/l10n/app_zh.arb lib/l10n/app_zh_TW.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_ja.dart lib/l10n/app_localizations_zh.dart test/reader_margin_controls_test.dart
git add -p lib/pages/native_reader_page.dart
git diff --cached --check
git commit -m "Give readers separate control of each page edge"
```

Use Lore trailers recording the migration constraint, page-indicator independence, tests, and any unstaged pre-existing reader-page hunks.

---

### Task 3: Profile build and SloanePro visual verification

**Files:**
- Verify: `build/ios/iphoneos/OpenReading.app`
- Capture: `/Users/xiaoyuan/.codex/visualizations/2026/07/16/019f6989-8ec5-70a3-8071-9dd2a2ffdcb2/SloanePro-independent-margins.png`

**Interfaces:**
- Consumes: bundle ID `com.niki.xxread`, device ID `00008140-001979421E93001C`, Xcode path `/Applications/Xcode-beta.app/Contents/Developer`.
- Produces: a running Profile build and a true-device screenshot showing the default margins and lower page indicator.

- [ ] **Step 1: Build the Profile app**

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
flutter build ios --profile --no-pub
```

Expected: `✓ Built build/ios/iphoneos/OpenReading.app`.

- [ ] **Step 2: Install and launch on SloanePro**

```bash
xcrun devicectl device install app --timeout 120 --device 00008140-001979421E93001C build/ios/iphoneos/OpenReading.app
xcrun devicectl device process launch --timeout 60 --device 00008140-001979421E93001C --terminate-existing com.niki.xxread
```

Expected: installation succeeds and the app launches. If the device is locked, retry after it becomes unlocked without rebuilding or reinstalling.

- [ ] **Step 3: Capture and inspect the reader**

Open the same native book page, leave both new sliders at defaults, then run:

```bash
xcrun devicectl device capture screenshot --timeout 60 --device 00008140-001979421E93001C --destination /Users/xiaoyuan/.codex/visualizations/2026/07/16/019f6989-8ec5-70a3-8071-9dd2a2ffdcb2/SloanePro-independent-margins.png
```

Verify the first text line remains below the Dynamic Island, the page indicator is approximately `14pt` from the bottom, and the body bottom padding is no larger than the system-required safe value at the default `0pt` setting.

- [ ] **Step 4: Verify persistence and independence**

Set top margin to `12pt` and bottom margin to `6pt`, close the settings sheet, reopen it, and verify both values remain. Confirm changing the bottom value does not move the page indicator and changing the top value does not alter the body bottom edge.

- [ ] **Step 5: Final repository audit**

Run:

```bash
git status --short
git diff --check
```

Expected: no whitespace errors; unrelated pre-existing changes remain unstaged and untouched.
