import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/sync/adapters/metadata_sync_adapters.dart';

void main() {
  test(
    'legacy annotation identities are deterministic and domain separated',
    () {
      final first = stableRecordId('bookmark', 'book|anchor|1000');
      expect(stableRecordId('bookmark', 'book|anchor|1000'), first);
      expect(stableRecordId('note', 'book|anchor|1000'), isNot(first));
      expect(
        first,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-a[0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    },
  );
}
