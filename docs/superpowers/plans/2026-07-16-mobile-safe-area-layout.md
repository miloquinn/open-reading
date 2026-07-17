# Mobile Safe-Area Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize mobile safe-area calculations so the main Flutter tabs adapt to iOS Dynamic Island/home indicator and Android system navigation without per-device branches.

**Architecture:** `HomeMobileChromeMetrics` derives all shell extents from `MediaQuery.viewPadding`, and `HomeMobileChromeScope` exposes one instance beneath the mobile shell. The top bar, floating navigation, and tab pages consume those metrics instead of duplicating fixed inset formulas.

**Tech Stack:** Flutter 3.35, Dart 3.9, Material widgets, `MediaQueryData`, `InheritedWidget`, flutter_test, iOS Profile build.

## Global Constraints

- Do not add dependencies.
- Preserve the reader's independent full-screen chrome.
- Preserve existing dirty-worktree changes outside the named files.
- Use system `viewPadding`; do not add device-model or platform branches.
- Keep tablet and desktop NavigationRail behavior unchanged.

---

### Task 1: Safe-area metrics model

**Files:**
- Modify: `lib/pages/home_layout_constants.dart`
- Create: `test/home_mobile_chrome_metrics_test.dart`

**Interfaces:**
- Produces: `HomeMobileChromeMetrics.fromMediaQuery(MediaQueryData)`
- Produces: `HomeMobileChromeScope.of(BuildContext)`
- Produces: `topBarHeight`, `pageTopPadding`, `navBottomInset`, `navContainerHeight`, `pageBottomPadding`, and `floatingActionBottomMargin`

- [ ] **Step 1: Write failing metric tests**

```dart
final metrics = HomeMobileChromeMetrics.fromMediaQuery(
  const MediaQueryData(
    size: Size(393, 852),
    viewPadding: EdgeInsets.only(top: 59, bottom: 34),
  ),
);
expect(metrics.topBarHeight, 119);
expect(metrics.pageTopPadding, 127);
expect(metrics.navBottomInset, 44);
expect(metrics.navContainerHeight, 108);
expect(metrics.pageBottomPadding, 118);
```

- [ ] **Step 2: Run the test and confirm the missing type failure**

Run: `flutter test --no-pub test/home_mobile_chrome_metrics_test.dart`

Expected: FAIL because `HomeMobileChromeMetrics` is not defined.

- [ ] **Step 3: Implement the metrics and scope**

```dart
const double kHomeMobileTopBarContentHeight = 60;
const double kHomeMobileFloatingNavHeight = 64;
const double kHomeMobileFloatingNavBottomGap = 10;
const double kHomeMobileContentTopExtra = 8;
const double kHomeMobileContentBottomExtra = 10;

class HomeMobileChromeMetrics {
  factory HomeMobileChromeMetrics.fromMediaQuery(MediaQueryData mediaQuery) {
    return HomeMobileChromeMetrics(
      systemTopInset: mediaQuery.viewPadding.top,
      systemBottomInset: mediaQuery.viewPadding.bottom,
    );
  }
}

class HomeMobileChromeScope extends InheritedWidget {
  static HomeMobileChromeMetrics of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeMobileChromeScope>()?.metrics ??
      HomeMobileChromeMetrics.fromMediaQuery(MediaQuery.of(context));
}
```

- [ ] **Step 4: Run the metric tests**

Run: `flutter test --no-pub test/home_mobile_chrome_metrics_test.dart`

Expected: PASS for iPhone and Android inset examples.

### Task 2: Make HomeShell the single chrome owner

**Files:**
- Modify: `lib/pages/home_shell_page.dart`
- Modify: `lib/pages/home_shell_layout_part.dart`
- Modify: `lib/pages/home_widgets/home_mobile_top_bar_widget.dart`

**Interfaces:**
- Consumes: `HomeMobileChromeMetrics.fromMediaQuery`
- Produces: a `HomeMobileChromeScope` wrapping the mobile `Stack`

- [ ] **Step 1: Replace `_BottomNavMetrics` with the shared model**

Construct `HomeMobileChromeMetrics` once in `_buildBottomNavigation`, wrap the
body stack in `HomeMobileChromeScope`, and remove `_computeBottomNavMetrics`.

- [ ] **Step 2: Use shared top and bottom extents**

Set the floating navigation container to `metrics.navContainerHeight`, its
bottom padding to `metrics.navBottomInset`, and its bar height to
`metrics.floatingNavHeight`.

- [ ] **Step 3: Make the top bar consume the scope**

Use `metrics.topBarHeight` for the container and
`metrics.systemTopInset + 8` for its top padding.

- [ ] **Step 4: Format and analyze the shell files**

Run: `dart format lib/pages/home_layout_constants.dart lib/pages/home_shell_page.dart lib/pages/home_shell_layout_part.dart lib/pages/home_widgets/home_mobile_top_bar_widget.dart`

Run: `flutter analyze --no-pub lib/pages/home_shell_page.dart`

Expected: no new errors.

### Task 3: Migrate tab content and verify on SloanePro

**Files:**
- Modify: `lib/pages/home_mobile_dashboard_page.dart`
- Modify: `lib/pages/library_page.dart`
- Modify: `lib/pages/book_sources_page.dart`
- Modify: `lib/pages/settings_page.dart`

**Interfaces:**
- Consumes: `HomeMobileChromeScope.of(context)`

- [ ] **Step 1: Replace home dashboard formulas**

For mobile navigation use `metrics.topBarHeight`, `metrics.pageTopPadding`, and
`metrics.pageBottomPadding`; retain the existing rail calculations.

- [ ] **Step 2: Replace library formulas**

Use `pageTopPadding`, `pageBottomPadding`, and
`floatingActionBottomMargin`; remove every raw `68 + 25` expression.

- [ ] **Step 3: Replace discovery and settings formulas**

Disable the outer top `SafeArea` on mobile discovery so the shared
`pageTopPadding` is not double-counted. Use shared top and bottom padding in
both discovery and settings lists.

- [ ] **Step 4: Run regression checks**

Run: `rg -n '68 \\+ 25|kHomeMobileSafeBottomMax' lib/pages`

Expected: no matches.

Run: `flutter test --no-pub test/home_mobile_chrome_metrics_test.dart`

Expected: PASS.

Run: `flutter analyze --no-pub`

Expected: no new errors; pre-existing warnings may remain.

- [ ] **Step 5: Build, install, and launch Profile**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer flutter build ios --profile --no-pub`

Expected: `build/ios/iphoneos/OpenReading.app` is produced.

Install with `xcrun devicectl device install app` and launch bundle
`com.niki.xxread` on device `00008140-001979421E93001C`.

Expected: the new process remains alive and no new Runner crash report appears.
