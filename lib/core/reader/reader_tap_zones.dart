import 'dart:ui';

import 'package:flutter/foundation.dart';

/// 阅读页 3×3 点击区域可分配的动作。
enum ReaderTapZoneAction {
  previousPage,
  nextPage,
  previousChapter,
  nextChapter,
  menu,
  none;

  static ReaderTapZoneAction? fromName(String? name) {
    for (final action in values) {
      if (action.name == name) return action;
    }
    return null;
  }
}

/// 阅读页的九宫格点击布局，按行优先从左上角开始存储。
///
/// 任何实例都保证至少有一个区域是菜单：若输入没有菜单，则中间区域
/// 自动恢复为菜单，控制栏永远有入口可以呼出。
@immutable
class ReaderTapZones {
  static const int columns = 3;
  static const int rows = 3;
  static const int zoneCount = columns * rows;
  static const int centerZoneIndex = 4;

  const ReaderTapZones._(this._actions);

  /// 与旧的三分布局一致：左列上一页、中列菜单、右列下一页。
  static const ReaderTapZones defaults = ReaderTapZones._([
    ReaderTapZoneAction.previousPage,
    ReaderTapZoneAction.menu,
    ReaderTapZoneAction.nextPage,
    ReaderTapZoneAction.previousPage,
    ReaderTapZoneAction.menu,
    ReaderTapZoneAction.nextPage,
    ReaderTapZoneAction.previousPage,
    ReaderTapZoneAction.menu,
    ReaderTapZoneAction.nextPage,
  ]);

  factory ReaderTapZones.of(List<ReaderTapZoneAction> actions) {
    final normalized = List<ReaderTapZoneAction>.generate(
      zoneCount,
      (index) =>
          index < actions.length ? actions[index] : defaults._actions[index],
      growable: false,
    );
    if (!normalized.contains(ReaderTapZoneAction.menu)) {
      normalized[centerZoneIndex] = ReaderTapZoneAction.menu;
    }
    return ReaderTapZones._(List.unmodifiable(normalized));
  }

  final List<ReaderTapZoneAction> _actions;

  ReaderTapZoneAction operator [](int zoneIndex) => _actions[zoneIndex];

  ReaderTapZoneAction actionAt(Offset position, Size size) {
    if (size.width <= 0 || size.height <= 0) return ReaderTapZoneAction.none;
    final column = ((position.dx / size.width) * columns).floor().clamp(
      0,
      columns - 1,
    );
    final row = ((position.dy / size.height) * rows).floor().clamp(0, rows - 1);
    return _actions[row * columns + column];
  }

  ReaderTapZones withAction(int zoneIndex, ReaderTapZoneAction action) {
    final next = List<ReaderTapZoneAction>.of(_actions);
    next[zoneIndex] = action;
    return ReaderTapZones.of(next);
  }

  String encode() => _actions.map((action) => action.name).join(',');

  static ReaderTapZones decode(String? stored) {
    if (stored == null || stored.isEmpty) return defaults;
    final actions = <ReaderTapZoneAction>[];
    for (final name in stored.split(',')) {
      final action = ReaderTapZoneAction.fromName(name.trim());
      if (action == null) return defaults;
      actions.add(action);
    }
    if (actions.length != zoneCount) return defaults;
    return ReaderTapZones.of(actions);
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderTapZones && listEquals(other._actions, _actions);

  @override
  int get hashCode => Object.hashAll(_actions);
}
