import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/sync/sync_models.dart';
import 'package:xxread/services/sync/webdav_sync_controller.dart';

void main() {
  test(
    'automatic book uploads return immediately and skip duplicate titles',
    () async {
      final controller = _FakeWebDavSyncController();
      final first = Book(
        title: '  同名书  ',
        filePath: '/tmp/first.epub',
        format: 'epub',
      );
      final duplicate = Book(
        title: '同名书',
        filePath: '/tmp/second.epub',
        format: 'epub',
      );

      expect(controller.enqueueNewBookUploads([first, duplicate]), 1);
      expect(controller.uploaded, isEmpty);

      controller.releaseFirstUpload();
      await controller.idle;
      expect(controller.uploaded, [first]);
      expect(controller.enqueueNewBookUploads([duplicate]), 0);
    },
  );

  test(
    'automatic book uploads skip titles already present remotely and continue after failure',
    () async {
      final controller = _FakeWebDavSyncController(
        remote: const [
          RemoteBookDescriptor(
            bookUid: 'remote-1',
            title: '远端已有书',
            author: '',
            format: 'epub',
          ),
        ],
        failFirst: true,
      );
      final remoteDuplicate = Book(
        title: '  远端已有书 ',
        filePath: '/tmp/remote.epub',
        format: 'epub',
      );
      final failed = Book(
        title: '失败书',
        filePath: '/tmp/fail.epub',
        format: 'epub',
      );
      final succeeds = Book(
        title: '成功书',
        filePath: '/tmp/succeed.epub',
        format: 'epub',
      );

      expect(
        controller.enqueueNewBookUploads([remoteDuplicate, failed, succeeds]),
        2,
      );
      controller.releaseFirstUpload();
      await controller.idle;

      expect(controller.uploaded, [succeeds]);
    },
  );
}

class _FakeWebDavSyncController extends WebDavSyncController {
  _FakeWebDavSyncController({this.remote = const [], this.failFirst = false});

  @override
  bool get isConfigured => true;

  @override
  WebDavSyncScope get scope => const WebDavSyncScope(bookFiles: true);

  @override
  List<RemoteBookDescriptor> get remoteBooks => remote;

  final List<RemoteBookDescriptor> remote;
  final bool failFirst;
  final List<Book> uploaded = <Book>[];
  final Completer<void> _firstUpload = Completer<void>();
  final Completer<void> _idle = Completer<void>();
  int _attempts = 0;

  Future<void> get idle => _idle.future;

  void releaseFirstUpload() {
    if (!_firstUpload.isCompleted) _firstUpload.complete();
  }

  @override
  Future<RemoteBookDescriptor> uploadBookFile(
    Book book, {
    void Function(BookFileTransferProgress progress)? onProgress,
  }) async {
    final attempt = _attempts++;
    if (attempt == 0) {
      await _firstUpload.future;
      if (failFirst) throw StateError('expected background failure');
    }
    uploaded.add(book);
    if (!_idle.isCompleted) _idle.complete();
    return RemoteBookDescriptor(
      bookUid: 'local-${book.title}',
      title: book.title,
      author: book.author,
      format: book.format,
      fileAvailable: true,
    );
  }
}
