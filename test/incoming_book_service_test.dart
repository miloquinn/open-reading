import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_import_models.dart';
import 'package:xxread/services/books/incoming_book_bridge.dart';
import 'package:xxread/services/books/incoming_book_materializer.dart';
import 'package:xxread/services/books/incoming_book_models.dart';
import 'package:xxread/services/books/incoming_book_service.dart';

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('incoming-book-test-');
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('queues cold and hot requests until ready and consumes them FIFO',
      () async {
    final first = await _request(sandbox, 'first', 'first.txt', 'first');
    final second = await _request(sandbox, 'second', 'second.txt', 'second');
    final bridge = _FakeBridge(initial: [first]);
    final opened = <String>[];
    final service = IncomingBookService(
      bridge: bridge,
      materializer: IncomingBookMaterializer(),
      importer: _FakeImporter(),
      openBook: (book) async => opened.add(book.title),
      openImportQueue: (_) async {},
    );

    await service.start();
    bridge.add(second);
    await Future<void>.delayed(Duration.zero);
    expect(opened, isEmpty);

    await service.setReady(true);
    await service.idle;
    expect(opened, ['first', 'second']);

    bridge.add(first);
    await service.idle;
    expect(opened, ['first', 'second']);
    await service.dispose();
  });

  test('single file imports then opens returned book; multiple opens queue',
      () async {
    final single = await _request(sandbox, 'one', 'one.txt', 'one');
    final first = await _item(sandbox, 'a.txt', 'a');
    final second = await _item(sandbox, 'b.txt', 'b');
    final multi = IncomingBookRequest(
      requestId: 'multi',
      action: IncomingBookAction.share,
      items: [first, second],
    );
    final bridge = _FakeBridge(initial: [single, multi]);
    final opened = <String>[];
    List<BookImportSource>? queued;
    final service = IncomingBookService(
      bridge: bridge,
      materializer: IncomingBookMaterializer(),
      importer: _FakeImporter(),
      openBook: (book) async => opened.add(book.title),
      openImportQueue: (sources) async => queued = sources,
    );

    await service.start();
    await service.setReady(true);
    await service.idle;

    expect(opened, ['one']);
    expect(queued?.map((source) => source.displayName), ['a.txt', 'b.txt']);
    expect(
        queued?.every(
            (source) => source.kind == BookImportSourceKind.systemShare),
        isTrue);
    await service.dispose();
  });

  test('does not advance FIFO until single-book route insertion succeeds',
      () async {
    final first = await _request(sandbox, 'first-route', 'first.txt', 'first');
    final second =
        await _request(sandbox, 'second-route', 'second.txt', 'second');
    final routeInserted = Completer<void>();
    final firstRouteStarted = Completer<void>();
    final opened = <String>[];
    final service = IncomingBookService(
      bridge: _FakeBridge(initial: [first, second]),
      materializer: IncomingBookMaterializer(),
      importer: _FakeImporter(),
      openBook: (book) async {
        opened.add(book.title);
        if (book.title == 'first') {
          firstRouteStarted.complete();
          await routeInserted.future;
        }
      },
      openImportQueue: (_) async {},
    );

    await service.start();
    final ready = service.setReady(true);
    await firstRouteStarted.future;
    expect(opened, ['first']);

    routeInserted.complete();
    await ready;
    expect(opened, ['first', 'second']);
    await service.dispose();
  });

  test('rejects unsupported and content-mismatched files with stable codes',
      () async {
    final badExtension = await _request(sandbox, 'bad', 'bad.exe', 'data');
    final fakeEpub =
        await _request(sandbox, 'epub', 'fake.epub', 'not an epub');
    final failures = <String>[];
    final service = IncomingBookService(
      bridge: _FakeBridge(initial: [badExtension, fakeEpub]),
      materializer: IncomingBookMaterializer(),
      importer: _FakeImporter(),
      openBook: (_) async {},
      openImportQueue: (_) async {},
      onFailure: (failure) => failures.add(failure.code),
    );

    await service.start();
    await service.setReady(true);
    await service.idle;

    expect(failures, ['unsupported_format', 'content_mismatch']);
    await service.dispose();
  });

  test('reports partial native failures while importing valid shared files',
      () async {
    final valid = await _item(sandbox, 'valid.txt', 'content');
    final request = IncomingBookRequest(
      requestId: 'partial',
      action: IncomingBookAction.share,
      items: [valid],
      failureCount: 1,
    );
    final failures = <String>[];
    final opened = <String>[];
    final service = IncomingBookService(
      bridge: _FakeBridge(initial: [request]),
      materializer: IncomingBookMaterializer(),
      importer: _FakeImporter(),
      openBook: (book) async => opened.add(book.title),
      openImportQueue: (_) async {},
      onFailure: (failure) => failures.add(failure.code),
    );

    await service.start();
    await service.setReady(true);
    await service.idle;

    expect(failures, ['partial_failure']);
    expect(opened, ['valid']);
    await service.dispose();
  });

  test('keeps valid files when another shared item fails Dart validation',
      () async {
    final valid = await _item(sandbox, 'valid.txt', 'content');
    final unsupported = await _item(sandbox, 'unsupported.pdf', 'not a pdf');
    final request = IncomingBookRequest(
      requestId: 'mixed-validation',
      action: IncomingBookAction.share,
      items: [valid, unsupported],
    );
    final failures = <String>[];
    final opened = <String>[];
    final service = IncomingBookService(
      bridge: _FakeBridge(initial: [request]),
      materializer: IncomingBookMaterializer(),
      importer: _FakeImporter(),
      openBook: (book) async => opened.add(book.title),
      openImportQueue: (_) async {},
      onFailure: (failure) => failures.add(failure.code),
    );

    await service.start();
    await service.setReady(true);
    await service.idle;

    expect(failures, ['partial_failure']);
    expect(opened, ['valid']);
    await service.dispose();
  });

  test('maps native intake limits to actionable failure codes', () async {
    final bridge = _FakeBridge(
      initial: const [
        IncomingBookRequest(
          requestId: 'too-many',
          action: IncomingBookAction.share,
          items: [],
          errorCode: 'too_many_files',
        ),
        IncomingBookRequest(
          requestId: 'aggregate',
          action: IncomingBookAction.share,
          items: [],
          errorCode: 'aggregate_too_large',
        ),
      ],
    );
    final failures = <String>[];
    final service = IncomingBookService(
      bridge: bridge,
      materializer: IncomingBookMaterializer(),
      importer: _FakeImporter(),
      openBook: (_) async {},
      openImportQueue: (_) async {},
      onFailure: (failure) => failures.add(failure.code),
    );

    await service.start();
    await service.setReady(true);
    await service.idle;

    expect(failures, ['too_many_files', 'file_too_large']);
    await service.dispose();
  });

  test('enforces request item limit for desktop argument intake', () async {
    final items = <IncomingBookItem>[];
    for (var index = 0;
        index <= IncomingBookMaterializer.maximumRequestItems;
        index++) {
      items.add(await _item(sandbox, 'book-$index.txt', 'content'));
    }
    final failures = <String>[];
    final service = IncomingBookService(
      bridge: _FakeBridge(
        initial: [
          IncomingBookRequest(
            requestId: 'desktop-too-many',
            action: IncomingBookAction.open,
            items: items,
          ),
        ],
      ),
      materializer: IncomingBookMaterializer(),
      importer: _FakeImporter(),
      openBook: (_) async {},
      openImportQueue: (_) async {},
      onFailure: (failure) => failures.add(failure.code),
    );

    await service.start();
    await service.setReady(true);
    expect(failures, ['too_many_files']);
    await service.dispose();
  });

  test('enforces aggregate byte limit for desktop argument intake', () async {
    final items = <IncomingBookItem>[];
    for (var index = 0; index < 6; index++) {
      final file = File('${sandbox.path}/large-$index.txt');
      final handle = await file.open(mode: FileMode.write);
      await handle.truncate(90 * 1024 * 1024);
      await handle.close();
      items.add(
        IncomingBookItem(
          id: 'large-$index',
          displayName: 'large-$index.txt',
          localPath: file.path,
        ),
      );
    }
    final failures = <String>[];
    final service = IncomingBookService(
      bridge: _FakeBridge(
        initial: [
          IncomingBookRequest(
            requestId: 'desktop-aggregate',
            action: IncomingBookAction.open,
            items: items,
          ),
        ],
      ),
      materializer: IncomingBookMaterializer(),
      importer: _FakeImporter(),
      openBook: (_) async {},
      openImportQueue: (_) async {},
      onFailure: (failure) => failures.add(failure.code),
    );

    await service.start();
    await service.setReady(true);
    expect(failures, ['file_too_large']);
    await service.dispose();
  });
}

Future<IncomingBookRequest> _request(
  Directory directory,
  String id,
  String name,
  String content,
) async {
  return IncomingBookRequest(
    requestId: id,
    action: IncomingBookAction.open,
    items: [await _item(directory, name, content)],
  );
}

Future<IncomingBookItem> _item(
  Directory directory,
  String name,
  String content,
) async {
  final file = File('${directory.path}/$name');
  await file.writeAsString(content);
  return IncomingBookItem(
    id: name,
    displayName: name,
    localPath: file.path,
    sizeBytes: await file.length(),
  );
}

class _FakeBridge implements IncomingBookRequestSource {
  _FakeBridge({this.initial = const []});

  final List<IncomingBookRequest> initial;
  final StreamController<IncomingBookRequest> controller =
      StreamController<IncomingBookRequest>.broadcast();

  @override
  Stream<IncomingBookRequest> get requests => controller.stream;

  @override
  Future<List<IncomingBookRequest>> getInitialRequests() async => initial;

  void add(IncomingBookRequest request) => controller.add(request);

  @override
  Future<void> completeRequest(
    String requestId, {
    required bool deleteFiles,
  }) async {}

  @override
  Future<void> dispose() => controller.close();
}

class _FakeImporter implements BookFileImporter {
  @override
  Future<BookImportResult> importFile(
    BookImportSource source, {
    BookImportProgress? onProgress,
  }) async {
    return BookImportResult(
      source: source,
      outcome: BookImportOutcome.imported,
      book: Book(
        id: source.displayName.hashCode,
        title: source.displayName.replaceAll(RegExp(r'\.[^.]+$'), ''),
        filePath: source.localPath!,
        format: source.extension,
      ),
    );
  }
}
