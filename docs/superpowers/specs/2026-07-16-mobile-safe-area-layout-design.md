# Mobile Safe-Area Layout Design

## Goal

Make the shared Flutter mobile shell adapt automatically to iPhone notches,
Dynamic Island, the iOS home indicator, Android gesture navigation, rotation,
and different phone sizes without per-model branches.

## Current problem

The shell combines system insets with fixed layout constants such as a 76 pt
top bar, a 68 pt floating navigation bar, and a 25 pt bottom gap. Child pages
repeat parts of the same formulas, including raw `68 + 25` expressions. The
larger iOS safe areas therefore produce excessive bottom whitespace, while
multiple owners of the top inset make the overlay layout fragile.

## Design

1. Introduce one immutable `HomeMobileChromeMetrics` model in the shared home
   layout constants module.
2. Derive it from `MediaQuery.viewPadding` and screen dimensions:
   - system top and bottom insets come from Flutter;
   - the top content height and navigation height remain design dimensions;
   - the visual gap below the floating navigation is small and is added after
     the system bottom inset;
   - page top and bottom padding are exposed as computed values.
3. Expose the metrics to child pages through `HomeMobileChromeScope`, an
   inherited widget installed once by `HomeShellPage`.
4. Remove duplicated safe-area arithmetic from the home dashboard, library,
   discovery, and settings pages. Child pages consume scope metrics and retain
   rail-specific padding for tablets and desktop.
5. Keep reader controls separate because the reader has its own full-screen
   chrome and page-number reserve.

## Chosen dimensions

- Top content height: 60 pt
- Floating navigation height: 64 pt
- Gap above the safe bottom edge: 10 pt
- Content clearance below floating navigation: 10 pt

The total sizes remain dynamic because system insets are added at runtime.

## Verification

- Flutter formatting and analysis for touched files.
- Profile iOS build using the current Xcode beta toolchain.
- Install and launch on `SloanePro` without clearing app data.
- Confirm the process remains alive and no new crash report appears.
- Compare available device screenshots when a capture path is available.

## Scope boundary

This change covers the main mobile shell tabs only. It does not redesign
reader typography, tablet navigation rail, modal sheets, or individual feature
pages pushed outside the tab shell.
