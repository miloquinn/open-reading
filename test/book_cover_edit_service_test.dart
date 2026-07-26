// 文件说明：自定义书籍封面服务测试，覆盖换封面、原封面备份还原与残留清理。
// 技术要点：注入假图片选择器与临时目录、覆写 DAO 记录封面路径更新。

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_cover_edit_service.dart';
import 'package:xxread/services/books/book_dao.dart';

class _RecordingBookDao extends BookDao {
  final List<(int, String?)> coverUpdates = [];

  @override
  Future<void> updateBookCoverPath(int bookId, String? coverImagePath) async {
    coverUpdates.add((bookId, coverImagePath));
  }
}

void main() {
  late Directory documentsDir;
  late _RecordingBookDao dao;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp(
      'cover_edit_service_test',
    );
    dao = _RecordingBookDao();
  });

  tearDown(() async {
    if (await documentsDir.exists()) {
      await documentsDir.delete(recursive: true);
    }
  });

  BookCoverEditService buildService({FilePickerResult? Function()? pick}) {
    return BookCoverEditService(
      bookDao: dao,
      imagePicker: () async => pick?.call(),
      documentsDirectory: () async => documentsDir,
    );
  }

  FilePickerResult pickedImage(String name, Uint8List bytes) {
    return FilePickerResult([
      PlatformFile(name: name, size: bytes.length, bytes: bytes),
    ]);
  }

  Book book({int id = 1, String? coverPath}) {
    return Book(
      id: id,
      title: '测试书籍',
      filePath: p.join(documentsDir.path, 'books', 'test.epub'),
      format: 'epub',
      coverImagePath: coverPath,
    );
  }

  String coversPath(String fileName) =>
      p.join(documentsDir.path, 'covers', fileName);

  test('hasCustomCover 只识别本书的 custom_ 命名封面', () {
    expect(BookCoverEditService.hasCustomCover(book()), isFalse);
    expect(
      BookCoverEditService.hasCustomCover(
        book(coverPath: coversPath('1_extracted.jpg')),
      ),
      isFalse,
    );
    expect(
      BookCoverEditService.hasCustomCover(
        book(coverPath: coversPath('custom_2_123.jpg')),
      ),
      isFalse,
      reason: '别的书的自定义封面不算本书的',
    );
    expect(
      BookCoverEditService.hasCustomCover(
        book(coverPath: coversPath('custom_1_123.jpg')),
      ),
      isTrue,
    );
  });

  test('挑选图片后写入 covers 目录并更新 DAO 封面路径', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final service = buildService(pick: () => pickedImage('cover.png', bytes));

    final applied = await service.pickAndApplyCover(book());

    expect(applied, isTrue);
    expect(dao.coverUpdates, hasLength(1));
    final (bookId, newPath) = dao.coverUpdates.single;
    expect(bookId, 1);
    expect(newPath, isNotNull);
    expect(p.basename(newPath!), matches(RegExp(r'^custom_1_\d+\.png$')));
    expect(await File(newPath).readAsBytes(), bytes);
  });

  test('用户取消挑选时返回 false 且不动数据库', () async {
    final service = buildService(pick: () => null);

    expect(await service.pickAndApplyCover(book()), isFalse);
    expect(dao.coverUpdates, isEmpty);
  });

  test('不支持的扩展名抛 unsupportedFormat', () async {
    final service = buildService(
      pick: () => pickedImage('cover.svg', Uint8List.fromList([1])),
    );

    await expectLater(
      service.pickAndApplyCover(book()),
      throwsA(
        isA<BookCoverEditException>().having(
          (e) => e.code,
          'code',
          BookCoverEditError.unsupportedFormat,
        ),
      ),
    );
  });

  test('超过 20 MB 的图片抛 fileTooLarge', () async {
    final service = buildService(
      pick: () => pickedImage(
        'big.jpg',
        Uint8List(BookCoverEditService.maxImageBytes + 1),
      ),
    );

    await expectLater(
      service.pickAndApplyCover(book()),
      throwsA(
        isA<BookCoverEditException>().having(
          (e) => e.code,
          'code',
          BookCoverEditError.fileTooLarge,
        ),
      ),
    );
  });

  test('替换已有封面时备份原封面，恢复默认时无损还原', () async {
    final originalPath = coversPath('1_extracted.jpg');
    final originalBytes = [9, 8, 7];
    await File(originalPath).create(recursive: true);
    await File(originalPath).writeAsBytes(originalBytes);
    final service = buildService(
      pick: () => pickedImage('new.png', Uint8List.fromList([1, 2])),
    );

    await service.pickAndApplyCover(book(coverPath: originalPath));

    final backup = File(coversPath('original_1.jpg'));
    expect(await backup.exists(), isTrue);
    expect(await backup.readAsBytes(), originalBytes);
    expect(await File(originalPath).exists(), isFalse);

    final customPath = dao.coverUpdates.single.$2!;
    await service.resetCover(book(coverPath: customPath));

    expect(dao.coverUpdates.last.$2, backup.path);
    expect(await File(customPath).exists(), isFalse);
    expect(await backup.readAsBytes(), originalBytes);
  });

  test('原本没有本地封面的书恢复默认时清空封面路径', () async {
    final service = buildService(
      pick: () => pickedImage('new.png', Uint8List.fromList([1])),
    );

    await service.pickAndApplyCover(book());
    final customPath = dao.coverUpdates.single.$2!;

    await service.resetCover(book(coverPath: customPath));

    expect(dao.coverUpdates.last.$2, isNull);
    expect(await File(customPath).exists(), isFalse);
  });

  test('连续替换封面只保留最新自定义文件和最初的原封面备份', () async {
    final originalPath = coversPath('1_extracted.jpg');
    await File(originalPath).create(recursive: true);
    await File(originalPath).writeAsBytes([9]);
    final service = buildService(
      pick: () => pickedImage('new.png', Uint8List.fromList([1])),
    );

    await service.pickAndApplyCover(book(coverPath: originalPath));
    final firstCustom = dao.coverUpdates.single.$2!;
    // 唯一命名依赖毫秒时间戳，隔一毫秒再换第二次
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await service.pickAndApplyCover(book(coverPath: firstCustom));
    final secondCustom = dao.coverUpdates.last.$2!;

    expect(secondCustom, isNot(firstCustom));
    expect(await File(firstCustom).exists(), isFalse);
    expect(await File(secondCustom).exists(), isTrue);
    expect(await File(coversPath('original_1.jpg')).exists(), isTrue);
  });

  test('cleanupForDeletedBook 只清理本书的自定义封面与备份', () async {
    final coversDir = Directory(p.join(documentsDir.path, 'covers'));
    await coversDir.create(recursive: true);
    final mine = [coversPath('custom_1_123.png'), coversPath('original_1.jpg')];
    final others = [
      coversPath('custom_2_456.png'),
      coversPath('original_2.jpg'),
      coversPath('1_extracted.jpg'),
    ];
    for (final filePath in [...mine, ...others]) {
      await File(filePath).writeAsBytes([1]);
    }

    await buildService().cleanupForDeletedBook(book());

    for (final filePath in mine) {
      expect(await File(filePath).exists(), isFalse, reason: filePath);
    }
    for (final filePath in others) {
      expect(await File(filePath).exists(), isTrue, reason: filePath);
    }
  });
}
