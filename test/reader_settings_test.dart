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
      firstLineIndent: 3,
      paragraphSpacing: 1,
      pageTurnStyle: ReaderPageTurnStyle.classicFold,
      pullBookmarkEnabled: true,
      tapPageAnimationEnabled: false,
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
    expect(restored.firstLineIndent, 3);
    expect(restored.paragraphSpacing, 1);
    expect(restored.pageTurnStyle, ReaderPageTurnStyle.classicFold);
    expect(restored.pullBookmarkEnabled, isTrue);
    expect(restored.tapPageAnimationEnabled, isFalse);
  });

  test('allows a zero horizontal page margin', () async {
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.horizontalMarginKey: 0.0,
    });

    final restored = await const ReaderSettingsStore().load(
      fallbackPageMode: ReaderPageMode.verticalScroll,
    );

    expect(restored.horizontalMargin, 0);
    expect(restored.copyWith(horizontalMargin: -1).horizontalMargin, 0);
  });

  test('shares the chapter-scoped scrolling preference across readers',
      () async {
    SharedPreferences.setMockInitialValues({});
    const store = ReaderSettingsStore();

    expect(await store.loadScrollByChapter(), isTrue);

    await store.saveScrollByChapter(false);

    expect(await store.loadScrollByChapter(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(ReaderSettingsStore.scrollByChapterKey),
      isFalse,
    );
  });

  test('clamps typography settings and defaults to cylinder turns', () async {
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.firstLineIndentKey: 20,
      ReaderSettingsStore.paragraphSpacingKey: -3,
    });

    final restored = await const ReaderSettingsStore().load(
      fallbackPageMode: ReaderPageMode.verticalScroll,
    );

    expect(restored.firstLineIndent, 4);
    expect(restored.paragraphSpacing, 0);
    expect(restored.pageTurnStyle, ReaderPageTurnStyle.cylinder);
    expect(restored.pullBookmarkEnabled, isFalse);
    expect(restored.tapPageAnimationEnabled, isTrue);
    expect(restored.copyWith(firstLineIndent: -1).firstLineIndent, 0);
    expect(restored.copyWith(paragraphSpacing: 9).paragraphSpacing, 2);
  });
}
