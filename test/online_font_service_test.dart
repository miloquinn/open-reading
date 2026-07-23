import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/core/online_font_service.dart';

class _ChunkedHttpClientAdapter implements HttpClientAdapter {
  _ChunkedHttpClientAdapter(this.bytes);

  final Uint8List bytes;
  static const int _chunkSize = 1024;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final chunks = <Uint8List>[];
    for (var offset = 0; offset < bytes.length; offset += _chunkSize) {
      final end = (offset + _chunkSize).clamp(0, bytes.length);
      chunks.add(Uint8List.sublistView(bytes, offset, end));
    }
    return ResponseBody(
      Stream<Uint8List>.fromIterable(chunks),
      HttpStatus.ok,
      headers: <String, List<String>>{
        Headers.contentLengthHeader: <String>['${bytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'downloads, hashes and registers a font without changing results',
    () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'online-font-service-test-',
      );
      addTearDown(() => sandbox.delete(recursive: true));
      final fontBytes = Uint8List(128 * 1024)
        ..setAll(0, const <int>[0, 1, 0, 0]);
      final dio = Dio()
        ..httpClientAdapter = _ChunkedHttpClientAdapter(fontBytes);
      Uint8List? registeredBytes;
      final service = OnlineFontService(
        supportDirectory: () async => sandbox,
        dio: dio,
        registrar: (family, bytes, style) async {
          registeredBytes = bytes;
        },
      );
      await service.initialize();

      final record = await service.download(
        fontId: 'test_font',
        family: 'TestFont',
        files: <OnlineFontFile>[
          OnlineFontFile(
            url: 'https://cdn.jsdelivr.net/test-font.ttf',
            fileName: 'test_font.ttf',
            size: fontBytes.length,
          ),
        ],
      );

      expect(registeredBytes, fontBytes);
      expect(record.files.single.sha256, sha256.convert(fontBytes).toString());
      expect(record.files.single.size, fontBytes.length);
      expect(service.isDownloaded('test_font'), isTrue);
    },
  );
}
