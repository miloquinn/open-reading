import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/services/books/book_import_models.dart';
import 'package:xxread/services/books/book_import_source_service.dart';
import 'package:xxread/services/storage/android_book_folder_registry.dart';
import 'package:xxread/services/storage/platform_storage_bridge.dart';

void main() {
  test('文件选择器只保留支持格式且扩展名不区分大小写', () async {
    final directory = await Directory.systemTemp.createTemp('source-test-');
    addTearDown(() => directory.delete(recursive: true));
    final epub = File('${directory.path}/A.EPUB');
    final json = File('${directory.path}/readme.json');
    await epub.writeAsString('epub');
    await json.writeAsString('{}');

    final pickerResult = FilePickerResult(<PlatformFile>[
      PlatformFile(name: 'A.EPUB', path: epub.path, size: 4),
      PlatformFile(name: 'readme.json', path: json.path, size: 2),
    ]);
    final service = BookImportSourceService(
      filePicker: () async => pickerResult,
    );

    final sources = await service.pickFiles();

    expect(sources, hasLength(1));
    expect(sources.single.extension, 'epub');
    expect(sources.single.kind, BookImportSourceKind.filePicker);
    expect(sources.single.ownership, BookImportOwnership.externalCopy);
  });

  test('iOS 共享 Documents 中的书籍按原地管理来源返回', () async {
    final documents = await Directory.systemTemp.createTemp('documents-test-');
    addTearDown(() => documents.delete(recursive: true));
    final books = Directory('${documents.path}/books');
    await books.create(recursive: true);
    final book = File('${books.path}/本地书.txt');
    await book.writeAsString('内容');

    final service = BookImportSourceService(
      documentsDirectory: () async => documents,
    );

    final sources = await service.scanIosSharedDocuments();

    expect(sources, hasLength(1));
    expect(sources.single.localPath, book.path);
    expect(sources.single.ownership, BookImportOwnership.managedInPlace);
    expect(sources.single.kind, BookImportSourceKind.iosSharedDocuments);
  });

  test('Android 文档物化通过 MethodChannel 传递 content URI', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('test.storage.bridge');
    MethodCall? invocation;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      invocation = call;
      return '/tmp/materialized.epub';
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final bridge = PlatformStorageBridge(channel: channel);

    final path = await bridge.materializeAndroidDocument(
      documentUri: 'content://provider/tree/root/document/book-1',
      destinationPath: '/tmp/book.epub',
    );

    expect(path, '/tmp/materialized.epub');
    expect(invocation?.method, 'materializeDocument');
    expect(
      (invocation?.arguments as Map<Object?, Object?>)['documentUri'],
      'content://provider/tree/root/document/book-1',
    );
  });

  test('Android 文件夹元数据与系统持久化权限对齐', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const channel = MethodChannel('test.folder.registry');
    var persistedUris = <String>{'content://tree/available'};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'pickDirectory':
          return <String, Object?>{
            'treeUri': 'content://tree/available',
            'displayName': 'Books',
          };
        case 'listDocuments':
          return const <Object?>[];
        case 'listPersistedDirectories':
          return persistedUris
              .map(
                (uri) => <String, Object?>{
                  'treeUri': uri,
                  'displayName': 'Books',
                },
              )
              .toList();
        case 'releaseDirectory':
          persistedUris.remove(
            (call.arguments as Map<Object?, Object?>)['treeUri'],
          );
          return true;
      }
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final bridge = PlatformStorageBridge(channel: channel);
    final registry = AndroidBookFolderRegistry(
      bridge: bridge,
      sourceService: BookImportSourceService(platformBridge: bridge),
    );

    await registry.pickAndScan();
    expect(
      (await registry.registeredDirectories()).single.permissionAvailable,
      isTrue,
    );

    persistedUris = <String>{};
    final lost = (await registry.registeredDirectories()).single;
    expect(lost.displayName, 'Books');
    expect(lost.permissionAvailable, isFalse);
  });
}
