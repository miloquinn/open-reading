// 文件说明：维护 Android SAF 已授权书籍目录及其面向用户的显示元数据。
// 技术要点：系统持久化 URI 权限、SharedPreferences 元数据、权限状态对齐。

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/services/books/book_import_models.dart';
import 'package:xxread/services/books/book_import_source_service.dart';
import 'package:xxread/services/storage/platform_storage_bridge.dart';

class AndroidBookFolder {
  const AndroidBookFolder({
    required this.treeUri,
    required this.displayName,
    required this.permissionAvailable,
  });

  final String treeUri;
  final String displayName;
  final bool permissionAvailable;

  Map<String, Object?> toJson() => <String, Object?>{
    'treeUri': treeUri,
    'displayName': displayName,
  };
}

class AndroidBookFolderRegistry {
  AndroidBookFolderRegistry({
    PlatformStorageBridge? bridge,
    BookImportSourceService? sourceService,
    Future<SharedPreferences> Function()? preferences,
  }) : _bridge = bridge ?? PlatformStorageBridge(),
       _sourceService = sourceService ?? BookImportSourceService(),
       _preferences = preferences ?? SharedPreferences.getInstance;

  static const _metadataKey = 'android_book_folder_metadata_v1';

  final PlatformStorageBridge _bridge;
  final BookImportSourceService _sourceService;
  final Future<SharedPreferences> Function() _preferences;

  Future<List<BookImportSource>> pickAndScan() async {
    final selected = await _bridge.pickAndroidDirectory();
    final treeUri = selected?['treeUri']?.toString();
    if (treeUri == null || treeUri.isEmpty) return const [];
    final displayName = selected?['displayName']?.toString() ?? treeUri;
    await _saveMetadata(treeUri: treeUri, displayName: displayName);
    return _sourceService.scanAndroidTree(treeUri);
  }

  Future<List<AndroidBookFolder>> registeredDirectories() async {
    final saved = await _readMetadata();
    final persistedRows = await _bridge.listPersistedAndroidDirectories();
    final persisted = <String, String>{
      for (final row in persistedRows)
        if (row['treeUri']?.toString().isNotEmpty == true)
          row['treeUri'].toString():
              row['displayName']?.toString() ?? row['treeUri'].toString(),
    };
    final allUris = <String>{...saved.keys, ...persisted.keys};
    final folders = allUris
        .map(
          (treeUri) => AndroidBookFolder(
            treeUri: treeUri,
            displayName: saved[treeUri] ?? persisted[treeUri] ?? treeUri,
            permissionAvailable: persisted.containsKey(treeUri),
          ),
        )
        .toList();
    folders.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return folders;
  }

  Future<List<BookImportSource>> scanRegisteredDirectories() async {
    final directories = await registeredDirectories();
    final sources = <BookImportSource>[];
    for (final directory in directories) {
      if (!directory.permissionAvailable) continue;
      sources.addAll(await _sourceService.scanAndroidTree(directory.treeUri));
    }
    return sources;
  }

  Future<void> removeDirectory(String treeUri) async {
    await _bridge.releaseAndroidDirectory(treeUri);
    final metadata = await _readMetadata();
    metadata.remove(treeUri);
    await _writeMetadata(metadata);
  }

  Future<void> _saveMetadata({
    required String treeUri,
    required String displayName,
  }) async {
    final metadata = await _readMetadata();
    metadata[treeUri] = displayName;
    await _writeMetadata(metadata);
  }

  Future<Map<String, String>> _readMetadata() async {
    final prefs = await _preferences();
    final raw = prefs.getString(_metadataKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _writeMetadata(Map<String, String> metadata) async {
    final prefs = await _preferences();
    await prefs.setString(_metadataKey, jsonEncode(metadata));
  }
}
