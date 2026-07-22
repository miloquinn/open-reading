class HybridLogicalTimestamp implements Comparable<HybridLogicalTimestamp> {
  const HybridLogicalTimestamp(
    this.physicalMillis,
    this.logical,
    this.deviceId,
  );

  final int physicalMillis;
  final int logical;
  final String deviceId;

  factory HybridLogicalTimestamp.parse(String value) {
    final first = value.indexOf('-');
    final second = value.indexOf('-', first + 1);
    if (first <= 0 || second <= first + 1 || second == value.length - 1) {
      throw FormatException('Invalid HLC');
    }
    return HybridLogicalTimestamp(
      int.parse(value.substring(0, first)),
      int.parse(value.substring(first + 1, second)),
      value.substring(second + 1),
    );
  }

  @override
  int compareTo(HybridLogicalTimestamp other) {
    final physical = physicalMillis.compareTo(other.physicalMillis);
    if (physical != 0) return physical;
    final counter = logical.compareTo(other.logical);
    if (counter != 0) return counter;
    return deviceId.compareTo(other.deviceId);
  }

  @override
  String toString() =>
      '$physicalMillis-${logical.toString().padLeft(4, '0')}-$deviceId';
}

class HybridLogicalClock {
  HybridLogicalClock({required this.deviceId, int Function()? nowMillis})
    : _nowMillis = nowMillis ?? (() => DateTime.now().millisecondsSinceEpoch);

  final String deviceId;
  final int Function() _nowMillis;
  int _physical = 0;
  int _logical = 0;

  HybridLogicalTimestamp tick() {
    final now = _nowMillis();
    if (now > _physical) {
      _physical = now;
      _logical = 0;
    } else {
      _logical++;
    }
    return HybridLogicalTimestamp(_physical, _logical, deviceId);
  }

  void observe(HybridLogicalTimestamp remote) {
    final now = _nowMillis();
    final maxPhysical = [
      now,
      _physical,
      remote.physicalMillis,
    ].reduce((a, b) => a > b ? a : b);
    if (maxPhysical == _physical && maxPhysical == remote.physicalMillis) {
      _logical = (_logical > remote.logical ? _logical : remote.logical) + 1;
    } else if (maxPhysical == _physical) {
      _logical++;
    } else if (maxPhysical == remote.physicalMillis) {
      _logical = remote.logical + 1;
    } else {
      _logical = 0;
    }
    _physical = maxPhysical;
  }
}
