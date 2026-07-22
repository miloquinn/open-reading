import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/sync/sync_clock.dart';

void main() {
  test('HLC remains monotonic when wall clock moves backwards', () {
    var now = 1000;
    final clock =
        HybridLogicalClock(deviceId: 'device-a', nowMillis: () => now);

    expect(clock.tick().toString(), '1000-0000-device-a');
    now = 900;
    expect(clock.tick().toString(), '1000-0001-device-a');
  });

  test('HLC observes remote values and uses device id as final tie breaker',
      () {
    final clock =
        HybridLogicalClock(deviceId: 'device-b', nowMillis: () => 1000);
    clock.observe(const HybridLogicalTimestamp(1200, 3, 'device-a'));

    expect(clock.tick().toString(), '1200-0005-device-b');
    expect(
      const HybridLogicalTimestamp(1200, 3, 'device-b').compareTo(
        const HybridLogicalTimestamp(1200, 3, 'device-a'),
      ),
      greaterThan(0),
    );
  });
}
