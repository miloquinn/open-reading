import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/sync/sync_protocol.dart';

void main() {
  test('batch checksum is deterministic and rejects modified payloads', () {
    final batch = SyncBatch.create(
      deviceId: 'device-a',
      sequence: 1,
      createdHlc: '1000-0000-device-a',
      operations: const [
        SyncOperation(
          dataset: 'progress',
          recordId: 'book-1',
          entityKey: 'book-1',
          hlc: '1000-0000-device-a',
          deleted: false,
          payload: {
            'canonical_locator': {'progression': 0.25},
          },
        ),
      ],
    );

    expect(SyncBatch.decode(batch.encode()).sha256, batch.sha256);

    final modified = jsonDecode(batch.encode()) as Map<String, dynamic>;
    final operations = modified['operations'] as List<dynamic>;
    final operation = operations.single as Map<String, dynamic>;
    operation['payload'] = {
      'canonical_locator': {'progression': 0.75},
    };
    expect(
      () => SyncBatch.decode(jsonEncode(modified)),
      throwsA(isA<FormatException>()),
    );
  });

  test('canonical checksum ignores map insertion order', () {
    expect(
      sha256OfCanonicalJson({'b': 2, 'a': 1}),
      sha256OfCanonicalJson({'a': 1, 'b': 2}),
    );
  });
}
