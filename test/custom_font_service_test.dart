import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/core/custom_font_service.dart';

Uint8List _validTtfBytes([int marker = 1]) => Uint8List.fromList(
      <int>[0, 1, 0, 0, marker, 2, 3, 4],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('imports, persists, reloads, renames and deletes a font', () async {
    final sandbox = await Directory.systemTemp.createTemp('custom-font-test-');
    addTearDown(() => sandbox.delete(recursive: true));
    final registeredFamilies = <String>[];
    final service = CustomFontService(
      supportDirectory: () async => sandbox,
      registrar: (family, bytes) async => registeredFamilies.add(family),
    );

    await service.initialize();
    final imported = await service.importFontBytes(
      fileName: 'Reading Font.ttf',
      bytes: _validTtfBytes(),
    );

    expect(imported.status, CustomFontImportStatus.imported);
    expect(imported.font?.displayName, 'Reading Font');
    expect(service.fonts, hasLength(1));
    expect(registeredFamilies, <String>[imported.font!.runtimeFamily]);

    final duplicate = await service.importFontBytes(
      fileName: 'renamed-copy.ttf',
      bytes: _validTtfBytes(),
    );
    expect(duplicate.status, CustomFontImportStatus.duplicate);
    expect(service.fonts, hasLength(1));

    await service.renameFont(imported.font!.id, 'My Reading Font');
    expect(service.fonts.single.displayName, 'My Reading Font');

    final reloadedFamilies = <String>[];
    final reloaded = CustomFontService(
      supportDirectory: () async => sandbox,
      registrar: (family, bytes) async => reloadedFamilies.add(family),
    );
    await reloaded.initialize();
    expect(reloaded.fonts.single.displayName, 'My Reading Font');
    expect(await reloaded.ensureLoaded(imported.font!.id), isTrue);
    expect(reloadedFamilies, <String>[imported.font!.runtimeFamily]);

    await reloaded.deleteFont(imported.font!.id);
    expect(reloaded.fonts, isEmpty);
  });

  test('rejects unsupported extensions and invalid font signatures', () async {
    final sandbox = await Directory.systemTemp.createTemp('custom-font-test-');
    addTearDown(() => sandbox.delete(recursive: true));
    final service = CustomFontService(
      supportDirectory: () async => sandbox,
      registrar: (family, bytes) async {},
    );
    await service.initialize();

    await expectLater(
      service.importFontBytes(
        fileName: 'font.woff',
        bytes: _validTtfBytes(),
      ),
      throwsA(
        isA<CustomFontException>().having(
          (error) => error.code,
          'code',
          CustomFontErrorCode.unsupportedFormat,
        ),
      ),
    );
    await expectLater(
      service.importFontBytes(
        fileName: 'font.ttf',
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      ),
      throwsA(
        isA<CustomFontException>().having(
          (error) => error.code,
          'code',
          CustomFontErrorCode.invalidFont,
        ),
      ),
    );
  });
}
