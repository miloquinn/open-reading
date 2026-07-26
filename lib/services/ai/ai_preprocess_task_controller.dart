// 文件说明：AI 预处理后台任务队列，书架与导入入口共用，下载任务页展示。
// 技术要点：ChangeNotifier 单例、FIFO 串行执行、可取消、错误对象延迟翻译。

import 'package:flutter/foundation.dart';

import '../../models/book.dart';
import 'book_preprocess_service.dart';

enum AiPreprocessTaskState { queued, running, completed, failed, cancelled }

class AiPreprocessTask {
  AiPreprocessTask({required this.book})
    : id = book.id?.toString() ?? '',
      state = AiPreprocessTaskState.queued,
      done = 0,
      total = 0;

  final String id;
  final Book book;
  final BookPreprocessCancelToken cancelToken = BookPreprocessCancelToken();

  AiPreprocessTaskState state;
  int done;
  int total;

  /// 原始错误对象；UI 层按类型翻译（AIServiceException / 抽取异常等）。
  Object? error;

  bool get isActive =>
      state == AiPreprocessTaskState.queued ||
      state == AiPreprocessTaskState.running;
}

/// 全局 AI 预处理队列：任务按加入顺序串行执行，避免并发打爆 AI 接口。
class AiPreprocessTaskController extends ChangeNotifier {
  AiPreprocessTaskController._();

  static final AiPreprocessTaskController _instance =
      AiPreprocessTaskController._();

  factory AiPreprocessTaskController() => _instance;

  final List<AiPreprocessTask> _tasks = [];
  bool _running = false;

  List<AiPreprocessTask> get tasks => List.unmodifiable(_tasks);

  bool get hasActiveTasks => _tasks.any((task) => task.isActive);

  /// 入队；同一本书已有排队/执行中的任务时返回 false。
  bool enqueue(Book book) {
    final id = book.id?.toString() ?? '';
    if (id.isEmpty) return false;
    final duplicated = _tasks.any((task) => task.id == id && task.isActive);
    if (duplicated) return false;
    _tasks.add(AiPreprocessTask(book: book));
    notifyListeners();
    _pump();
    return true;
  }

  void cancelTask(String id) {
    for (final task in _tasks) {
      if (task.id != id || !task.isActive) continue;
      task.cancelToken.cancel();
      if (task.state == AiPreprocessTaskState.queued) {
        task.state = AiPreprocessTaskState.cancelled;
      }
      notifyListeners();
      return;
    }
  }

  void clearFinished() {
    _tasks.removeWhere((task) => !task.isActive);
    notifyListeners();
  }

  void _pump() {
    if (_running) return;
    _running = true;
    Future<void>(() async {
      try {
        while (true) {
          AiPreprocessTask? next;
          for (final task in _tasks) {
            if (task.state == AiPreprocessTaskState.queued) {
              next = task;
              break;
            }
          }
          if (next == null) break;
          if (next.cancelToken.isCancelled) {
            next.state = AiPreprocessTaskState.cancelled;
            notifyListeners();
            continue;
          }
          next.state = AiPreprocessTaskState.running;
          notifyListeners();
          final task = next;
          try {
            await BookPreprocessService().preprocessBook(
              book: task.book,
              cancelToken: task.cancelToken,
              onProgress: (done, total) {
                task.done = done;
                task.total = total;
                notifyListeners();
              },
            );
            task.state = AiPreprocessTaskState.completed;
          } on BookPreprocessCancelled {
            task.state = AiPreprocessTaskState.cancelled;
          } catch (error) {
            task.state = AiPreprocessTaskState.failed;
            task.error = error;
            debugPrint('ai preprocess task failed: $error');
          }
          notifyListeners();
        }
      } finally {
        _running = false;
      }
    });
  }
}
