import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_leaf_status.dart';

void main() {
  testWidgets('status revision changes only when leaf status pixels change',
      (tester) async {
    var now = DateTime(2026, 7, 18, 9, 5, 45);
    final source = _FakeBatterySource([
      const ReaderBatteryStatus(level: 73, charging: false),
      const ReaderBatteryStatus(level: 73, charging: false),
      const ReaderBatteryStatus(level: 73, charging: false),
      const ReaderBatteryStatus(level: 74, charging: true),
    ]);
    final controller = ReaderLeafStatusController(
      batterySource: source,
      now: () => now,
    );

    controller.start();
    await tester.pump();
    expect(controller.value.time, DateTime(2026, 7, 18, 9, 5));
    expect(controller.value.battery?.level, 73);
    expect(controller.value.revision, 1);

    await controller.refresh();
    expect(controller.value.revision, 1);

    now = DateTime(2026, 7, 18, 9, 6, 2);
    await controller.refresh();
    expect(controller.value.time, DateTime(2026, 7, 18, 9, 6));
    expect(controller.value.revision, 2);

    await controller.refresh();
    expect(controller.value.battery?.level, 74);
    expect(controller.value.battery?.charging, isTrue);
    expect(controller.value.revision, 3);
    controller.dispose();
  });
}

class _FakeBatterySource implements ReaderBatteryStatusSource {
  _FakeBatterySource(this.values);

  final List<ReaderBatteryStatus?> values;
  int _index = 0;

  @override
  Future<ReaderBatteryStatus?> read() async {
    final index = _index.clamp(0, values.length - 1);
    _index++;
    return values[index];
  }
}
