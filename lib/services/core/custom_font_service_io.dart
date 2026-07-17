// 文件说明：原生平台用户字体导入、私有存储与运行时注册服务。
// 技术要点：FilePicker、SHA-256 去重、FontLoader、原子清单持久化。

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'custom_font_models.dart';

typedef CustomFontDirectoryProvider = Future<Directory> Function();
typedef CustomFontPicker = Future<FilePickerResult?> Function();
typedef CustomFontRegistrar = Future<void> Function(
  String family,
  Uint8List bytes,
);

class CustomFontService {
  CustomFontService({
    CustomFontDirectoryProvider? supportDirectory,
    CustomFontPicker? filePicker,
    CustomFontRegistrar? registrar,
  })  : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
        _filePicker = filePicker ?? _pickFontFile,
        _registrar = registrar ?? _registerFont;

  static const int maxFontBytes = 50 * 1024 * 1024;
  static const String _directoryName = 'custom_fonts';
  static const String _manifestName = 'manifest.json';

  final CustomFontDirectoryProvider _supportDirectory;
  final CustomFontPicker _filePicker;
  final CustomFontRegistrar _registrar;
  final List<CustomFontRecord> _fonts = <CustomFontRecord>[];
  final Set<String> _loadedFontIds = <String>{};

  Directory? _fontDirectory;
  bool _isSupported = true;

  bool get isSupported => _isSupported;
  List<CustomFontRecord> get fonts => List.unmodifiable(_fonts);

  static Future<FilePickerResult?> _pickFontFile() {
    return FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['ttf', 'otf'],
      allowMultiple: false,
      withData: false,
    );
  }

  static Future<void> _registerFont(String family, Uint8List bytes) async {
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  Future<void> initialize() async {
    try {
      final support = await _supportDirectory();
      final directory = Directory(path.join(support.path, _directoryName));
      await directory.create(recursive: true);
      _fontDirectory = directory;
      await _readManifest();
    } catch (_) {
      _isSupported = false;
      _fonts.clear();
    }
  }

  Future<void> _readManifest() async {
    final directory = _fontDirectory;
    if (directory == null) return;
    final manifest = File(path.join(directory.path, _manifestName));
    if (!await manifest.exists()) return;

    try {
      final decoded = jsonDecode(await manifest.readAsString());
      if (decoded is! List<Object?>) return;
      _fonts
        ..clear()
        ..addAll(decoded.whereType<Map<String, Object?>>().map((json) {
          final record = CustomFontRecord.fromJson(json);
          final file = File(path.join(directory.path, record.relativePath));
          return record.copyWith(available: file.existsSync());
        }));
    } catch (_) {
      _fonts.clear();
    }
  }

  Future<void> _writeManifest() async {
    final directory = _fontDirectory;
    if (directory == null) {
      throw const CustomFontException(CustomFontErrorCode.storageFailed);
    }
    final manifest = File(path.join(directory.path, _manifestName));
    final temporary = File('${manifest.path}.tmp');
    try {
      await temporary.writeAsString(
        const JsonEncoder.withIndent('  ')
            .convert(_fonts.map((font) => font.toJson()).toList()),
        flush: true,
      );
      if (await manifest.exists()) await manifest.delete();
      await temporary.rename(manifest.path);
    } catch (error) {
      if (await temporary.exists()) await temporary.delete();
      throw CustomFontException(CustomFontErrorCode.storageFailed, error);
    }
  }

  Future<CustomFontImportResult> importFont() async {
    if (!_isSupported) {
      throw const CustomFontException(CustomFontErrorCode.unsupported);
    }
    final result = await _filePicker();
    if (result == null || result.files.isEmpty) {
      return const CustomFontImportResult.cancelled();
    }
    final selected = result.files.single;
    try {
      final bytes = selected.bytes ??
          (selected.path == null
              ? null
              : await File(selected.path!).readAsBytes());
      if (bytes == null) {
        throw const CustomFontException(CustomFontErrorCode.readFailed);
      }
      return importFontBytes(fileName: selected.name, bytes: bytes);
    } on CustomFontException {
      rethrow;
    } catch (error) {
      throw CustomFontException(CustomFontErrorCode.readFailed, error);
    }
  }

  Future<CustomFontImportResult> importFontBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (!_isSupported || _fontDirectory == null) {
      throw const CustomFontException(CustomFontErrorCode.unsupported);
    }
    if (bytes.length > maxFontBytes) {
      throw const CustomFontException(CustomFontErrorCode.fileTooLarge);
    }

    final extension = path.extension(fileName).toLowerCase();
    if (extension != '.ttf' && extension != '.otf') {
      throw const CustomFontException(CustomFontErrorCode.unsupportedFormat);
    }
    if (!_matchesFontSignature(bytes, extension)) {
      throw const CustomFontException(CustomFontErrorCode.invalidFont);
    }

    final hash = sha256.convert(bytes).toString();
    CustomFontRecord? unavailableDuplicate;
    for (final existing in _fonts) {
      if (existing.sha256 == hash) {
        if (existing.available) {
          await ensureLoaded(existing.id);
          return CustomFontImportResult(
            status: CustomFontImportStatus.duplicate,
            font: existing,
          );
        }
        unavailableDuplicate = existing;
        break;
      }
    }

    final shortHash = hash.substring(0, 16);
    final id = 'custom_$shortHash';
    final storedFileName = '$id$extension';
    final record = CustomFontRecord(
      id: id,
      displayName: path.basenameWithoutExtension(fileName).trim(),
      runtimeFamily: 'OpenReadingCustom_$shortHash',
      fileName: fileName,
      relativePath: storedFileName,
      format: extension.substring(1),
      sha256: hash,
      fileSize: bytes.length,
      importedAt: DateTime.now().toUtc(),
    );
    final destination = File(path.join(_fontDirectory!.path, storedFileName));

    try {
      if (unavailableDuplicate != null) {
        _fonts.removeWhere((font) => font.id == unavailableDuplicate!.id);
      }
      await destination.writeAsBytes(bytes, flush: true);
      await _registrar(record.runtimeFamily, bytes);
      _loadedFontIds.add(record.id);
      _fonts.add(record);
      await _writeManifest();
      return CustomFontImportResult(
        status: CustomFontImportStatus.imported,
        font: record,
      );
    } on CustomFontException {
      _fonts.removeWhere((font) => font.id == record.id);
      if (unavailableDuplicate != null &&
          !_fonts.any((font) => font.id == unavailableDuplicate!.id)) {
        _fonts.add(unavailableDuplicate);
      }
      if (await destination.exists()) await destination.delete();
      rethrow;
    } catch (error) {
      _fonts.removeWhere((font) => font.id == record.id);
      if (unavailableDuplicate != null &&
          !_fonts.any((font) => font.id == unavailableDuplicate!.id)) {
        _fonts.add(unavailableDuplicate);
      }
      if (await destination.exists()) await destination.delete();
      throw CustomFontException(CustomFontErrorCode.loadFailed, error);
    }
  }

  static bool _matchesFontSignature(Uint8List bytes, String extension) {
    if (bytes.length < 4) return false;
    final tag = String.fromCharCodes(bytes.take(4));
    if (extension == '.otf') return tag == 'OTTO';
    return (bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 0 && bytes[3] == 0) ||
        tag == 'true' ||
        tag == 'typ1';
  }

  Future<bool> ensureLoaded(String id) async {
    if (_loadedFontIds.contains(id)) return true;
    final record = _fontForId(id);
    final directory = _fontDirectory;
    if (record == null || !record.available || directory == null) return false;
    final file = File(path.join(directory.path, record.relativePath));
    try {
      final bytes = await file.readAsBytes();
      await _registrar(record.runtimeFamily, bytes);
      _loadedFontIds.add(id);
      return true;
    } catch (_) {
      final index = _fonts.indexWhere((font) => font.id == id);
      if (index >= 0) {
        _fonts[index] = record.copyWith(available: false);
        await _writeManifest();
      }
      return false;
    }
  }

  Future<void> loadAvailableFonts() async {
    for (final font in List<CustomFontRecord>.of(_fonts)) {
      if (font.available) await ensureLoaded(font.id);
    }
  }

  Future<void> renameFont(String id, String displayName) async {
    final normalized = displayName.trim();
    if (normalized.isEmpty) return;
    final index = _fonts.indexWhere((font) => font.id == id);
    if (index < 0) return;
    _fonts[index] = _fonts[index].copyWith(displayName: normalized);
    await _writeManifest();
  }

  Future<void> deleteFont(String id) async {
    final index = _fonts.indexWhere((font) => font.id == id);
    if (index < 0) return;
    final record = _fonts[index];
    final directory = _fontDirectory;
    if (directory == null) return;
    final file = File(path.join(directory.path, record.relativePath));
    try {
      if (await file.exists()) await file.delete();
      _fonts.removeAt(index);
      _loadedFontIds.remove(id);
      await _writeManifest();
    } catch (error) {
      throw CustomFontException(CustomFontErrorCode.storageFailed, error);
    }
  }

  CustomFontRecord? _fontForId(String id) {
    for (final font in _fonts) {
      if (font.id == id) return font;
    }
    return null;
  }
}
