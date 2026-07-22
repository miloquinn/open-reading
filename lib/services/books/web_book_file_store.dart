// 文件说明：在 Web SQLite/IndexedDB 数据库中持久化浏览器选择的书籍文件。
// 技术要点：安全虚拟路径、惰性建表、二进制 BLOB 存取。

import 'dart:typed_data';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xxread/services/core/database_service.dart';

class WebBookFileStore {
  WebBookFileStore({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService();

  static const String pathPrefix = 'web-book://';
  static final RegExp _hashPattern = RegExp(r'^(?:[a-f0-9]{32}|[a-f0-9]{64})$');

  final DatabaseService _databaseService;
  Future<void>? _initializing;

  static bool isWebBookPath(String path) => path.startsWith(pathPrefix);

  static String hashFromPath(String path) {
    if (!isWebBookPath(path)) {
      throw FormatException('不是 Web 书籍虚拟路径', path);
    }
    final hash = path.substring(pathPrefix.length);
    if (!_hashPattern.hasMatch(hash)) {
      throw FormatException('Web 书籍虚拟路径包含无效哈希', path);
    }
    return hash;
  }

  static String pathForHash(String hash) {
    if (!_hashPattern.hasMatch(hash)) {
      throw FormatException('无效的书籍内容哈希', hash);
    }
    return '$pathPrefix$hash';
  }

  Future<void> put(String path, Uint8List bytes) async {
    final hash = hashFromPath(path);
    final database = await _readyDatabase();
    await database.insert('web_book_files', <String, Object?>{
      'content_hash': hash,
      'bytes': Uint8List.fromList(bytes),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Uint8List?> read(String path) async {
    final hash = hashFromPath(path);
    final database = await _readyDatabase();
    final rows = await database.query(
      'web_book_files',
      columns: const <String>['bytes'],
      where: 'content_hash = ?',
      whereArgs: <Object?>[hash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.single['bytes'];
    if (value is! Uint8List) return null;
    return Uint8List.fromList(value);
  }

  Future<bool> exists(String path) async {
    final hash = hashFromPath(path);
    final database = await _readyDatabase();
    final rows = await database.rawQuery(
      'SELECT 1 FROM web_book_files WHERE content_hash = ? LIMIT 1',
      <Object?>[hash],
    );
    return rows.isNotEmpty;
  }

  Future<void> delete(String path) async {
    final hash = hashFromPath(path);
    final database = await _readyDatabase();
    await database.delete(
      'web_book_files',
      where: 'content_hash = ?',
      whereArgs: <Object?>[hash],
    );
  }

  Future<Database> _readyDatabase() async {
    final database = await _databaseService.database;
    await (_initializing ??= _createTable(database));
    return database;
  }

  Future<void> _createTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS web_book_files(
        content_hash TEXT PRIMARY KEY NOT NULL,
        bytes BLOB NOT NULL
      )
    ''');
  }
}
