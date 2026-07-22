import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:xxread/book_sources/services/source_cover_cache.dart';

void main() {
  test('bounds concurrent cover requests', () async {
    final directory = await Directory.systemTemp.createTemp('source-covers-');
    addTearDown(() => directory.delete(recursive: true));
    var active = 0;
    var maxActive = 0;
    final cache = SourceCoverCache(
      cacheDirectory: directory,
      maxConcurrent: 3,
      loader: (uri) async {
        active++;
        if (active > maxActive) maxActive = active;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        active--;
        return Uint8List.fromList([1, 2, 3, uri.path.length]);
      },
    );

    await Future.wait(
      List.generate(
        12,
        (index) => cache.load(Uri.parse('https://example.org/$index.jpg')),
      ),
    );

    expect(maxActive, 3);
  });

  test('deduplicates requests and retries one transient failure', () async {
    final directory = await Directory.systemTemp.createTemp('source-retry-');
    addTearDown(() => directory.delete(recursive: true));
    var calls = 0;
    final cache = SourceCoverCache(
      cacheDirectory: directory,
      retryDelay: Duration.zero,
      loader: (_) async {
        calls++;
        if (calls == 1) {
          throw const SourceCoverLoadException(
            'temporary failure',
            transient: true,
          );
        }
        return Uint8List.fromList([4, 5, 6]);
      },
    );
    final uri = Uri.parse('https://example.org/shared.jpg');

    final results = await Future.wait([
      cache.load(uri),
      cache.load(uri),
      cache.load(uri),
    ]);

    expect(calls, 2);
    expect(results, everyElement([4, 5, 6]));
  });

  test('reuses disk bytes after memory is cleared', () async {
    final directory = await Directory.systemTemp.createTemp('source-disk-');
    addTearDown(() => directory.delete(recursive: true));
    var calls = 0;
    final cache = SourceCoverCache(
      cacheDirectory: directory,
      loader: (_) async {
        calls++;
        return Uint8List.fromList([7, 8, 9]);
      },
    );
    final uri = Uri.parse('https://example.org/cached.jpg');

    await cache.load(uri);
    cache.clearMemory();
    final bytes = await cache.load(uri);

    expect(bytes, [7, 8, 9]);
    expect(calls, 1);
    expect(await cache.diskSizeBytes(), 3);
  });

  test('evict removes memory and disk so the next load refetches', () async {
    final directory = await Directory.systemTemp.createTemp('source-evict-');
    addTearDown(() => directory.delete(recursive: true));
    var calls = 0;
    final cache = SourceCoverCache(
      cacheDirectory: directory,
      loader: (_) async => Uint8List.fromList([++calls]),
    );
    final uri = Uri.parse('https://example.org/invalid-then-fixed.jpg');

    expect(await cache.load(uri), [1]);
    expect(cache.memorySizeBytes, 1);
    await cache.evict(uri);
    expect(cache.memorySizeBytes, 0);
    expect(await cache.diskSizeBytes(), 0);
    expect(await cache.load(uri), [2]);
    expect(calls, 2);
  });

  test('evict starts a fresh load without old cleanup removing its dedupe',
      () async {
    final directory = await Directory.systemTemp.createTemp('source-race-');
    addTearDown(() => directory.delete(recursive: true));
    final first = Completer<Uint8List>();
    final second = Completer<Uint8List>();
    var calls = 0;
    final cache = SourceCoverCache(
      cacheDirectory: directory,
      loader: (_) {
        calls++;
        return calls == 1 ? first.future : second.future;
      },
    );
    final uri = Uri.parse('https://example.org/racing-cover.jpg');

    final oldLoad = cache.load(uri);
    for (var index = 0; index < 20 && calls < 1; index++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(calls, 1);
    await cache.evict(uri);
    final freshLoad = cache.load(uri);
    for (var index = 0; index < 20 && calls < 2; index++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(calls, 2);

    first.complete(Uint8List.fromList([1]));
    expect(await oldLoad, [1]);
    final deduplicatedFreshLoad = cache.load(uri);
    expect(calls, 2);

    second.complete(Uint8List.fromList([2]));
    expect(await freshLoad, [2]);
    expect(await deduplicatedFreshLoad, [2]);
    expect(calls, 2);
  });
}
