import 'dart:async';

class BookDownloadCancelledException implements Exception {
  const BookDownloadCancelledException();
}

class BookDownloadCancellation {
  final Completer<void> _cancelled = Completer<void>();
  final Set<void Function()> _listeners = <void Function()>{};

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  bool cancel() {
    if (isCancelled) return false;
    _cancelled.complete();
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
    _listeners.clear();
    return true;
  }

  void throwIfCancelled() {
    if (isCancelled) throw const BookDownloadCancelledException();
  }

  void addListener(void Function() listener) {
    if (isCancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  Future<void> delay(Duration duration) async {
    throwIfCancelled();
    await Future.any<void>([
      Future<void>.delayed(duration),
      whenCancelled,
    ]);
    throwIfCancelled();
  }
}
