import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_tap_zones.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_tap_zone_editor.dart';

void main() {
  group('ReaderTapZones', () {
    test('defaults keep the legacy left/menu/right columns', () {
      const zones = ReaderTapZones.defaults;
      for (var row = 0; row < ReaderTapZones.rows; row++) {
        expect(
          zones[row * ReaderTapZones.columns],
          ReaderTapZoneAction.previousPage,
        );
        expect(
          zones[row * ReaderTapZones.columns + 1],
          ReaderTapZoneAction.menu,
        );
        expect(
          zones[row * ReaderTapZones.columns + 2],
          ReaderTapZoneAction.nextPage,
        );
      }
    });

    test('actionAt maps positions to the 3x3 grid', () {
      const size = Size(300, 600);
      final zones = ReaderTapZones.of(const [
        ReaderTapZoneAction.nextPage,
        ReaderTapZoneAction.previousPage,
        ReaderTapZoneAction.nextChapter,
        ReaderTapZoneAction.previousChapter,
        ReaderTapZoneAction.menu,
        ReaderTapZoneAction.none,
        ReaderTapZoneAction.previousPage,
        ReaderTapZoneAction.nextPage,
        ReaderTapZoneAction.menu,
      ]);
      expect(
        zones.actionAt(const Offset(10, 10), size),
        ReaderTapZoneAction.nextPage,
      );
      expect(
        zones.actionAt(const Offset(150, 10), size),
        ReaderTapZoneAction.previousPage,
      );
      expect(
        zones.actionAt(const Offset(290, 10), size),
        ReaderTapZoneAction.nextChapter,
      );
      expect(
        zones.actionAt(const Offset(10, 300), size),
        ReaderTapZoneAction.previousChapter,
      );
      expect(
        zones.actionAt(const Offset(150, 300), size),
        ReaderTapZoneAction.menu,
      );
      expect(
        zones.actionAt(const Offset(290, 300), size),
        ReaderTapZoneAction.none,
      );
      expect(
        zones.actionAt(const Offset(10, 590), size),
        ReaderTapZoneAction.previousPage,
      );
      expect(
        zones.actionAt(const Offset(150, 590), size),
        ReaderTapZoneAction.nextPage,
      );
      expect(
        zones.actionAt(const Offset(290, 590), size),
        ReaderTapZoneAction.menu,
      );
      // 边界外与退化尺寸不产生动作。
      expect(
        zones.actionAt(const Offset(150, 300), Size.zero),
        ReaderTapZoneAction.none,
      );
    });

    test('a layout without menu restores menu on the center zone', () {
      final zones = ReaderTapZones.of(
        List.filled(ReaderTapZones.zoneCount, ReaderTapZoneAction.nextPage),
      );
      expect(zones[ReaderTapZones.centerZoneIndex], ReaderTapZoneAction.menu);
    });

    test('replacing the only menu zone falls back to the center', () {
      var zones = ReaderTapZones.of(const [
        ReaderTapZoneAction.menu,
        ReaderTapZoneAction.nextPage,
        ReaderTapZoneAction.nextPage,
        ReaderTapZoneAction.previousPage,
        ReaderTapZoneAction.nextPage,
        ReaderTapZoneAction.nextPage,
        ReaderTapZoneAction.previousPage,
        ReaderTapZoneAction.nextPage,
        ReaderTapZoneAction.nextPage,
      ]);
      zones = zones.withAction(0, ReaderTapZoneAction.previousChapter);
      expect(zones[0], ReaderTapZoneAction.previousChapter);
      expect(zones[ReaderTapZones.centerZoneIndex], ReaderTapZoneAction.menu);
    });

    test('encode and decode round trip, invalid input falls back', () {
      final zones = ReaderTapZones.defaults
          .withAction(0, ReaderTapZoneAction.nextChapter)
          .withAction(8, ReaderTapZoneAction.none);
      expect(ReaderTapZones.decode(zones.encode()), zones);
      expect(ReaderTapZones.decode(null), ReaderTapZones.defaults);
      expect(ReaderTapZones.decode(''), ReaderTapZones.defaults);
      expect(ReaderTapZones.decode('nonsense'), ReaderTapZones.defaults);
      expect(ReaderTapZones.decode('menu,nextPage'), ReaderTapZones.defaults);
    });
  });

  group('ReaderTapZoneEditorOverlay', () {
    Future<void> pumpEditor(
      WidgetTester tester, {
      required ReaderTapZones zones,
      required ValueChanged<ReaderTapZones> onZonesChanged,
      required VoidCallback onClose,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ReaderTapZoneEditorOverlay(
              palette: ReaderThemes.day,
              zones: zones,
              onZonesChanged: onZonesChanged,
              onClose: onClose,
            ),
          ),
        ),
      );
    }

    testWidgets('tapping a cell picks a new action for that zone', (
      tester,
    ) async {
      ReaderTapZones? changed;
      await pumpEditor(
        tester,
        zones: ReaderTapZones.defaults,
        onZonesChanged: (zones) => changed = zones,
        onClose: () {},
      );

      await tester.tap(find.byKey(const ValueKey('tap-zone-cell-0')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('tap-zone-action-nextChapter')),
      );
      await tester.pumpAndSettle();

      expect(changed, isNotNull);
      expect(changed![0], ReaderTapZoneAction.nextChapter);
      expect(changed![1], ReaderTapZoneAction.menu);
    });

    testWidgets('close and reset controls forward to the host', (tester) async {
      var closed = false;
      ReaderTapZones? changed;
      await pumpEditor(
        tester,
        zones: ReaderTapZones.defaults.withAction(
          0,
          ReaderTapZoneAction.nextChapter,
        ),
        onZonesChanged: (zones) => changed = zones,
        onClose: () => closed = true,
      );

      await tester.tap(find.byKey(const ValueKey('tap-zone-editor-reset')));
      expect(changed, ReaderTapZones.defaults);

      await tester.tap(find.byKey(const ValueKey('tap-zone-editor-close')));
      expect(closed, isTrue);
    });
  });
}
