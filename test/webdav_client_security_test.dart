import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/sync/secure_sync_config.dart';
import 'package:xxread/services/sync/sync_models.dart';
import 'package:xxread/services/sync/webdav_client.dart';

void main() {
  test('cross-origin redirects never receive Authorization', () async {
    final adapter = _RedirectAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final client = WebDavClient(
      dio: dio,
      credentials: const StoredSyncCredentials(
        WebDavSyncConfiguration(
          serverUrl: 'https://dav.example.com',
          username: 'reader',
        ),
        'secret',
      ),
    );

    await expectLater(
      client.getText(Uri.parse('https://dav.example.com/private')),
      throwsA(
        isA<WebDavSyncFailure>().having(
          (error) => error.code,
          'code',
          WebDavSyncErrorCode.serverIncompatible,
        ),
      ),
    );

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.uri.host, 'dav.example.com');
    expect(adapter.requests.single.headers['Authorization'], isNotNull);
  });

  test('HTTP Date headers update the server clock reference', () async {
    final dio = Dio()..httpClientAdapter = _DateAdapter();
    final client = WebDavClient(
      dio: dio,
      credentials: const StoredSyncCredentials(
        WebDavSyncConfiguration(
          serverUrl: 'https://dav.example.com',
          username: 'reader',
        ),
        'secret',
      ),
    );

    await client.getText(Uri.parse('https://dav.example.com/clock'));

    expect(client.lastServerDate, DateTime.utc(2015, 10, 21, 7, 28));
  });

  test(
    'immutable writes accept a server 409 when stored content matches',
    () async {
      final dio = Dio()..httpClientAdapter = _ImmutableConflictAdapter();
      final client = WebDavClient(
        dio: dio,
        credentials: const StoredSyncCredentials(
          WebDavSyncConfiguration(
            serverUrl: 'https://dav.example.com',
            username: 'reader',
          ),
          'secret',
        ),
      );

      await client.putText(
        Uri.parse('https://dav.example.com/existing.json'),
        '{"same":true}',
        immutable: true,
      );
    },
  );
}

class _RedirectAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '',
      302,
      headers: {
        'location': ['https://evil.example/steal'],
      },
    );
  }
}

class _DateAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      'ok',
      200,
      headers: {
        'date': ['Wed, 21 Oct 2015 07:28:00 GMT'],
      },
    );
  }
}

class _ImmutableConflictAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PUT') {
      return ResponseBody.fromString('', 409);
    }
    return ResponseBody.fromString('{"same":true}', 200);
  }
}
