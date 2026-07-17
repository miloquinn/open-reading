import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/reader_layout.dart';
import 'package:xxread/core/reader/reader_settings.dart';

void main() {
  test('migrates legacy vertical spacing into shared independent margins',
      () async {
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.legacyVerticalMarginKey: 38.0,
    });

    final settings = await const ReaderSettingsStore().load(
      fallbackPageMode: ReaderPageMode.verticalScroll,
    );

    expect(settings.topMargin, 14);
    expect(settings.bottomMargin, 10);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(ReaderSettingsStore.topMarginKey), 14);
    expect(prefs.getDouble(ReaderSettingsStore.bottomMarginKey), 10);
  });

  test('persists one settings model for every reader entry', () async {
    SharedPreferences.setMockInitialValues({});
    const store = ReaderSettingsStore();
    const settings = ReaderSettings(
      fontSize: 22,
      lineHeight: 1.8,
      horizontalMargin: 20,
      topMargin: 7,
      bottomMargin: 3,
      themeId: 'mist',
      pageMode: ReaderPageMode.pageCurl,
    );

    await store.save(settings);
    final restored = await store.load(
      fallbackPageMode: ReaderPageMode.verticalScroll,
    );

    expect(restored.fontSize, 22);
    expect(restored.topMargin, 7);
    expect(restored.bottomMargin, 3);
    expect(restored.themeId, 'mist');
    expect(restored.pageMode, ReaderPageMode.pageCurl);
  });
}
