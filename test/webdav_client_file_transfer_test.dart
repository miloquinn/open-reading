import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/sync/secure_sync_config.dart';
import 'package:xxread/services/sync/sync_models.dart';
import 'package:xxread/services/sync/webdav_client.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'open-reading-webdav-client-test-',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('putFile streams bytes and reports the completed upload', () async {
    final bytes = Uint8List.fromList(List<int>.generate(4096, (i) => i % 251));
    final source = File('${temporaryDirectory.path}/book.epub');
    await source.writeAsBytes(bytes);
    final adapter = _TransferAdapter(statusCode: 201);
    final client = _client(adapter);
    final progress = <(int, int)>[];

    await client.putFile(
      client.path(const ['blobs', 'book.epub']),
      source,
      onProgress: (sent, total) => progress.add((sent, total)),
    );

    expect(adapter.uploadedBytes, bytes);
    expect(progress, isNotEmpty);
    expect(progress.last, (bytes.length, bytes.length));
  });

  test('downloadFile streams into the target and reports byte progress',
      () async {
    final chunks = [
      Uint8List.fromList([1, 2, 3]),
      Uint8List.fromList([4, 5]),
    ];
    final adapter = _TransferAdapter(
      statusCode: 200,
      responseChunks: chunks,
      responseHeaders: {
        'content-length': ['5']
      },
    );
    final client = _client(adapter);
    final target = File('${temporaryDirectory.path}/download.part');
    final progress = <(int, int)>[];

    await client.downloadFile(
      client.path(const ['blobs', 'book.epub']),
      target,
      onProgress: (received, total) => progress.add((received, total)),
    );

    expect(await target.readAsBytes(), [1, 2, 3, 4, 5]);
    expect(progress, [(3, 5), (5, 5)]);
  });

  test('file upload maps WebDAV storage exhaustion to storageFull', () async {
    final source = File('${temporaryDirectory.path}/book.pdf');
    await source.writeAsBytes([1, 2, 3]);
    final client = _client(_TransferAdapter(statusCode: 507));

    await expectLater(
      client.putFile(client.path(const ['blobs', 'book.pdf']), source),
      throwsA(
        isA<WebDavSyncFailure>().having(
          (failure) => failure.code,
          'code',
          WebDavSyncErrorCode.storageFull,
        ),
      ),
    );
  });
}

WebDavClient _client(HttpClientAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return WebDavClient(
    dio: dio,
    credentials: const StoredSyncCredentials(
      WebDavSyncConfiguration(
        serverUrl: 'https://dav.example.com',
        username: 'reader',
      ),
      'secret',
    ),
  );
}

class _TransferAdapter implements HttpClientAdapter {
  _TransferAdapter({
    required this.statusCode,
    this.responseChunks = const [],
    this.responseHeaders = const {},
  });

  final int statusCode;
  final List<Uint8List> responseChunks;
  final Map<String, List<String>> responseHeaders;
  final uploadedBytes = <int>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        uploadedBytes.addAll(chunk);
      }
    }
    return ResponseBody(
      Stream<Uint8List>.fromIterable(responseChunks),
      statusCode,
      headers: responseHeaders,
    );
  }
}
