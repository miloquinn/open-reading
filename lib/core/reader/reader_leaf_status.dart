import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

@immutable
class ReaderBatteryStatus {
  const ReaderBatteryStatus({required this.level, required this.charging});

  final int level;
  final bool charging;
}

abstract interface class ReaderBatteryStatusSource {
  Future<ReaderBatteryStatus?> read();
}

class MethodChannelReaderBatteryStatusSource
    implements ReaderBatteryStatusSource {
  const MethodChannelReaderBatteryStatusSource();

  static const MethodChannel _channel = MethodChannel(
    'com.niki.xxread/reader_status',
  );

  @override
  Future<ReaderBatteryStatus?> read() async {
    if (kIsWeb) return null;
    try {
      final value = await _channel.invokeMapMethod<String, Object?>(
        'getBatteryStatus',
      );
      final level = value?['level'];
      if (level is! num) return null;
      return ReaderBatteryStatus(
        level: level.round().clamp(0, 100),
        charging: value?['charging'] == true,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

@immutable
class ReaderLeafStatusData {
  const ReaderLeafStatusData({
    required this.time,
    required this.revision,
    this.battery,
  });

  final DateTime time;
  final ReaderBatteryStatus? battery;
  final int revision;
}

/// Minute-level clock and low-frequency battery snapshot for page chrome.
///
/// A reader owns one controller for its session. Each update increments
/// [ReaderLeafStatusData.revision], allowing page snapshot entries to be
/// replaced without putting dynamic clock data into the semantic cache key.
class ReaderLeafStatusController extends ChangeNotifier
    with WidgetsBindingObserver {
  ReaderLeafStatusController({
    ReaderBatteryStatusSource batterySource =
        const MethodChannelReaderBatteryStatusSource(),
    DateTime Function()? now,
  }) : _batterySource = batterySource,
       _now = now ?? DateTime.now,
       _value = ReaderLeafStatusData(
         time: _minute(now?.call() ?? DateTime.now()),
         revision: 0,
       );

  final ReaderBatteryStatusSource _batterySource;
  final DateTime Function() _now;
  Timer? _minuteTimer;
  bool _started = false;
  int _refreshGeneration = 0;
  ReaderLeafStatusData _value;

  ReaderLeafStatusData get value => _value;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
    _scheduleMinuteTick();
  }

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    final time = _minute(_now());
    final battery = await _batterySource.read();
    if (!_started || generation != _refreshGeneration) return;
    _publish(time: time, battery: battery ?? _value.battery);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh());
      _scheduleMinuteTick();
    }
  }

  void _scheduleMinuteTick() {
    _minuteTimer?.cancel();
    final now = _now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _minuteTimer = Timer(
      nextMinute.difference(now) + const Duration(milliseconds: 80),
      () {
        if (!_started) return;
        _publish(time: _minute(_now()), battery: _value.battery);
        unawaited(refresh());
        _scheduleMinuteTick();
      },
    );
  }

  void _publish({
    required DateTime time,
    required ReaderBatteryStatus? battery,
  }) {
    if (_value.time == time &&
        _value.battery?.level == battery?.level &&
        _value.battery?.charging == battery?.charging) {
      return;
    }
    _value = ReaderLeafStatusData(
      time: time,
      battery: battery,
      revision: _value.revision + 1,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _started = false;
    _refreshGeneration++;
    _minuteTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

DateTime _minute(DateTime value) =>
    DateTime(value.year, value.month, value.day, value.hour, value.minute);
