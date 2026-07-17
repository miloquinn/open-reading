// 文件说明：Web 平台用户字体占位实现；首版仅在原生平台持久化字体文件。

import 'dart:typed_data';

import 'custom_font_models.dart';

class CustomFontService {
  CustomFontService();

  bool get isSupported => false;
  List<CustomFontRecord> get fonts => const <CustomFontRecord>[];

  Future<void> initialize() async {}

  Future<CustomFontImportResult> importFont() async {
    throw const CustomFontException(CustomFontErrorCode.unsupported);
  }

  Future<CustomFontImportResult> importFontBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    throw const CustomFontException(CustomFontErrorCode.unsupported);
  }

  Future<bool> ensureLoaded(String id) async => false;
  Future<void> loadAvailableFonts() async {}

  Future<void> renameFont(String id, String displayName) async {
    throw const CustomFontException(CustomFontErrorCode.unsupported);
  }

  Future<void> deleteFont(String id) async {
    throw const CustomFontException(CustomFontErrorCode.unsupported);
  }
}
