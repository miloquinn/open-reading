import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/services/core/app_settings_service.dart';
import 'package:xxread/services/core/custom_font_service.dart';
import 'package:xxread/services/core/online_font_service.dart';
import 'package:xxread/utils/font_catalog_helper.dart';

Future<AppSettingsNotifier> _loadNotifier({
  CustomFontService? customFontService,
  OnlineFontService? onlineFontService,
}) async {
  final notifier = AppSettingsNotifier(
    customFontService: customFontService,
    onlineFontService: onlineFontService,
  );
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

/// 预置在线字体清单与占位文件，模拟"用户此前已下载完成"的磁盘状态，
/// 使 AppSettingsNotifier 恢复选择时无需真实网络下载即可 ensureLoaded 成功。
Future<OnlineFontService> _seededOnlineFontService(
  List<FontOption> alreadyDownloaded,
) async {
  final sandbox =
      await Directory.systemTemp.createTemp('online-font-settings-test-');
  addTearDown(() => sandbox.delete(recursive: true));

  final fontsRoot = Directory(path.join(sandbox.path, 'online_fonts'));
  await fontsRoot.create(recursive: true);

  final records = <Map<String, Object?>>[];
  for (final option in alreadyDownloaded) {
    final fontDir = Directory(path.join(fontsRoot.path, option.id));
    await fontDir.create(recursive: true);
    final fileRecords = <Map<String, Object?>>[];
    for (final file in option.downloadFiles) {
      await File(path.join(fontDir.path, file.fileName))
          .writeAsBytes(const <int>[0, 1, 0, 0]);
      fileRecords.add(<String, Object?>{
        'fileName': file.fileName,
        'sha256': 'test',
        'size': 4,
      });
    }
    records.add(<String, Object?>{
      'id': option.id,
      'files': fileRecords,
      'downloadedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
  await File(path.join(fontsRoot.path, 'manifest.json'))
      .writeAsString(jsonEncode(records));

  return OnlineFontService(
    supportDirectory: () async => sandbox,
    registrar: (family, bytes, style) async {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('fresh install defaults both domains to the system font', () async {
    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.appFontId, FontCatalog.systemId);
    expect(notifier.appFontFamily, isNull);
    expect(notifier.readerFontId, FontCatalog.systemId);
    expect(notifier.readerFont.family, isNull);
  });

  test('font selections persist as stable ids once downloaded', () async {
    final onlineFontService = await _seededOnlineFontService([
      FontCatalog.instrumentSans,
      FontCatalog.newsreader,
    ]);
    final notifier =
        await _loadNotifier(onlineFontService: onlineFontService);
    addTearDown(notifier.dispose);

    await notifier.setAppFontId(FontCatalog.instrumentSansId);
    await notifier.setReaderFontId(FontCatalog.newsreaderId);

    expect(notifier.appFontId, FontCatalog.instrumentSansId);
    expect(notifier.readerFontId, FontCatalog.newsreaderId);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_font_id_v2'), FontCatalog.instrumentSansId);
    expect(prefs.getString('reader_font_id_v2'), FontCatalog.newsreaderId);
  });

  test('selecting an undownloaded online font is a no-op', () async {
    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    await notifier.setAppFontId(FontCatalog.instrumentSansId);

    expect(notifier.appFontId, FontCatalog.systemId);
  });

  test('legacy app font family migrates to the matching id when downloaded',
      () async {
    SharedPreferences.setMockInitialValues({
      'app_font_family': 'SourceHanSansCN',
    });
    final onlineFontService =
        await _seededOnlineFontService([FontCatalog.sourceHanSans]);

    final notifier =
        await _loadNotifier(onlineFontService: onlineFontService);
    addTearDown(notifier.dispose);

    expect(notifier.appFontId, FontCatalog.sourceHanSansId);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_font_id_v2'), FontCatalog.sourceHanSansId);
  });

  test(
      'legacy app font family falls back to system when not yet downloaded',
      () async {
    SharedPreferences.setMockInitialValues({
      'app_font_family': 'SourceHanSansCN',
    });

    final notifier = await _loadNotifier();
    addTearDown(notifier.dispose);

    expect(notifier.appFontId, FontCatalog.systemId);
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

  test('an imported font is shared by both domains but applied independently',
      () async {
    final sandbox =
        await Directory.systemTemp.createTemp('font-settings-test-');
    addTearDown(() => sandbox.delete(recursive: true));
    final bytes = Uint8List.fromList(<int>[0, 1, 0, 0, 1, 2, 3, 4]);
    final service = CustomFontService(
      supportDirectory: () async => sandbox,
      filePicker: () async => FilePickerResult(<PlatformFile>[
        PlatformFile(
          name: 'Reader Custom.ttf',
          size: bytes.length,
          bytes: bytes,
        ),
      ]),
      registrar: (family, bytes) async {},
    );
    final notifier = await _loadNotifier(customFontService: service);
    addTearDown(notifier.dispose);

    final result = await notifier.importCustomFont(FontDomain.reader);
    final customId = result.font!.id;

    expect(notifier.readerFontId, customId);
    expect(notifier.appFontId, FontCatalog.defaultAppFont.id);
    expect(notifier.appFontOptions.map((font) => font.id), contains(customId));
    expect(
      notifier.readerFontOptions.map((font) => font.id),
      contains(customId),
    );

    await notifier.setAppFontId(customId);
    expect(notifier.appFontId, customId);
    await notifier.deleteCustomFont(customId);
    expect(notifier.appFontId, FontCatalog.defaultAppFont.id);
    expect(notifier.readerFontId, FontCatalog.defaultReaderFont.id);
  });
}
