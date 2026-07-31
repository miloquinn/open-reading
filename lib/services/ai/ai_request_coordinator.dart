// 文件说明：全局 AI 请求协调器，交互式对话优先、后台预处理礼让。
// 技术要点：单例、在途计数、Completer 等待队列、协作式让行。

import 'dart:async';

import 'package:flutter/foundation.dart';

/// 协调交互式 AI 请求（阅读器问 AI、AI 页对话）与后台批量请求
/// （书籍预处理）的并发关系：
///
/// - 交互式请求直接放行，仅登记在途数量；
/// - 后台请求在每次调用前等待所有交互式请求结束再继续。
///
/// 多数 AI 服务商按 API Key 限制并发，预处理连续占用接口时对话
/// 请求会被排队或限流；这里让预处理在两次分块请求之间主动让行，
/// 保证预处理进行中对话依然随问随答。
class AiRequestCoordinator {
  factory AiRequestCoordinator() => _instance;

  AiRequestCoordinator._();

  /// 测试专用构造：隔离单例状态。
  @visibleForTesting
  AiRequestCoordinator.forTesting();

  static final AiRequestCoordinator _instance = AiRequestCoordinator._();

  int _interactiveInFlight = 0;
  final List<Completer<void>> _idleWaiters = <Completer<void>>[];

  bool get hasInteractiveRequests => _interactiveInFlight > 0;

  /// 执行一次交互式请求；异常原样上抛，结束后唤醒等待的后台任务。
  Future<T> runInteractive<T>(Future<T> Function() action) async {
    _interactiveInFlight += 1;
    try {
      return await action();
    } finally {
      _interactiveInFlight -= 1;
      if (_interactiveInFlight == 0 && _idleWaiters.isNotEmpty) {
        final waiters = List<Completer<void>>.of(_idleWaiters);
        _idleWaiters.clear();
        for (final waiter in waiters) {
          waiter.complete();
        }
      }
    }
  }

  /// 等到没有任何交互式请求在途；被唤醒后若又有新对话进来则继续等。
  Future<void> waitUntilInteractiveIdle() async {
    while (_interactiveInFlight > 0) {
      final completer = Completer<void>();
      _idleWaiters.add(completer);
      await completer.future;
    }
  }
}
