import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_network_policy.dart';

void main() {
  test('rejects hostnames resolving to non-public targets', () async {
    for (final address in [
      '127.0.0.1',
      '10.0.0.1',
      '172.16.0.1',
      '192.168.0.1',
      '169.254.169.254',
      '::1',
      'fd00::1',
      'fe80::1',
      '::ffff:127.0.0.1',
    ]) {
      final policy = BookSourceNetworkPolicy(
        lookup: (_) async => [InternetAddress(address)],
      );

      await expectLater(
        policy.validate(Uri.parse('https://source.example/api')),
        throwsA(isA<BookSourceProtocolException>()),
        reason: address,
      );
    }
  });

  test('rejects private IP literals without DNS resolution', () async {
    const policy = BookSourceNetworkPolicy();

    await expectLater(
      policy.validate(Uri.parse('http://192.168.1.10/api')),
      throwsA(isA<BookSourceProtocolException>()),
    );
  });

  test('allows a private target only when explicitly enabled', () async {
    const policy = BookSourceNetworkPolicy(allowPrivateNetwork: true);

    await expectLater(
      policy.validate(Uri.parse('http://127.0.0.1/api')),
      completes,
    );
  });

  test('synthetic DNS range is separately opt-in', () {
    final address = InternetAddress('198.18.0.7');

    expect(BookSourceNetworkPolicy.isBlockedAddress(address), isTrue);
    expect(
      BookSourceNetworkPolicy.isBlockedAddress(
        address,
        allowSyntheticDns: true,
      ),
      isFalse,
    );
  });

  test(
    'private mode still rejects unspecified and multicast targets',
    () async {
      const policy = BookSourceNetworkPolicy(allowPrivateNetwork: true);

      for (final target in ['0.0.0.0', '224.0.0.1', '::', 'ff02::1']) {
        final host = target.contains(':') ? '[$target]' : target;
        await expectLater(
          policy.validate(Uri.parse('http://$host/api')),
          throwsA(isA<BookSourceProtocolException>()),
          reason: target,
        );
      }
    },
  );

  test('rejects unsafe redirects and HTTPS downgrades', () {
    expect(
      () => BookSourceNetworkPolicy.redirectTarget(
        Uri.parse('https://source.example/api'),
        'file:///tmp/source',
      ),
      throwsA(isA<BookSourceProtocolException>()),
    );
    expect(
      () => BookSourceNetworkPolicy.redirectTarget(
        Uri.parse('https://source.example/api'),
        'http://source.example/api',
      ),
      throwsA(isA<BookSourceProtocolException>()),
    );
  });
}
