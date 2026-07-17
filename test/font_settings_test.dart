import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/services/core/app_settings_service.dart';
import 'package:xxread/utils/font_catalog_helper.dart';

Future<AppSettingsNotifier> _loadNotifier() async {
  final notifier = AppSettingsNotifier();
  if (notifier.isInitialized) return notifier;

  final initialized = Completer<void>();
  void listener() {
    if (notifier.isInitialized && !initialized.isCompleted) {
      initialized.complete();
    }
  }

  notifier.addListener(listener);
  listener();
  await initialized.future;
  notifier.removeListener(listener);
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('font domains have independent defaults', () async {
    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.appFontId, FontCatalog.sourceHanSerifId);
    expect(notifier.appFontFamily, 'SourceHanSerifCN');
    expect(notifier.readerFontId, FontCatalog.systemId);
    expect(notifier.readerFont.family, isNull);
  });

  test('font selections persist as stable ids', () async {
    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    await notifier.setAppFontId(FontCatalog.instrumentSansId);
    await notifier.setReaderFontId(FontCatalog.newsreaderId);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_font_id_v2'), FontCatalog.instrumentSansId);
    expect(prefs.getString('reader_font_id_v2'), FontCatalog.newsreaderId);
  });

  test('legacy app font family migrates to the matching id', () async {
    SharedPreferences.setMockInitialValues({
      'app_font_family': 'SourceHanSansCN',
    });

    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.appFontId, FontCatalog.sourceHanSansId);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_font_id_v2'), FontCatalog.sourceHanSansId);
  });

  test('invalid stored ids fall back within their own domain', () async {
    SharedPreferences.setMockInitialValues({
      'app_font_id_v2': 'missing-app-font',
      'reader_font_id_v2': 'missing-reader-font',
    });

    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.appFontId, FontCatalog.defaultAppFont.id);
    expect(notifier.readerFontId, FontCatalog.defaultReaderFont.id);
  });

  test('app and reader catalogs expose distinct curated choices', () {
    expect(FontCatalog.appFonts.first, FontCatalog.defaultAppFont);
    expect(FontCatalog.readerFonts.first, FontCatalog.defaultReaderFont);
    expect(
      FontCatalog.readerFonts.map((font) => font.id),
      contains(FontCatalog.newsreaderId),
    );
    expect(
      FontCatalog.appFonts.map((font) => font.id),
      contains(FontCatalog.instrumentSansId),
    );
  });
}
