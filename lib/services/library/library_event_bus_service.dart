// 文件说明：书库事件总线，用于在不同页面之间广播书库刷新事件。
// 技术要点：服务层。

import 'dart:async';

class LibraryEventBus {
  static final LibraryEventBus _instance = LibraryEventBus._internal();
  factory LibraryEventBus() => _instance;
  LibraryEventBus._internal();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notifyLibraryChanged() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
