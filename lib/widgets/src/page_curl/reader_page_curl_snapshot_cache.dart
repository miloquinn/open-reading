part of '../../reader_shader_page_curl.dart';

bool _sameSnapshot(ReaderPageSnapshot left, ReaderPageSnapshot right) =>
    left.key == right.key && left.contentRevision == right.contentRevision;

bool _sameOptionalSnapshot(
  ReaderPageSnapshot? left,
  ReaderPageSnapshot? right,
) {
  if (left == null || right == null) return left == right;
  return _sameSnapshot(left, right);
}

class _ReaderSnapshotCache {
  _ReaderSnapshotCache({required this.maxBytes, required this.maxEntries});

  final int maxBytes;
  final int maxEntries;
  final LinkedHashMap<ReaderPageSnapshotKey, _ReaderSnapshotEntry> _entries =
      LinkedHashMap();
  int _bytes = 0;

  ui.Image? lookup(
    ReaderPageSnapshotKey key, {
    required int contentRevision,
    required Size logicalSize,
    required double pixelRatio,
  }) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    if (entry.contentRevision != contentRevision ||
        entry.logicalSize != logicalSize ||
        entry.pixelRatio != pixelRatio) {
      _bytes -= entry.byteSize;
      entry.image.dispose();
      return null;
    }
    _entries[key] = entry;
    return entry.image;
  }

  ui.Image? store(
    ReaderPageSnapshotKey key, {
    required ui.Image image,
    required int contentRevision,
    required Size logicalSize,
    required double pixelRatio,
    required Set<ReaderPageSnapshotKey> protectedKeys,
    bool retainPrevious = false,
  }) {
    final previous = _entries.remove(key);
    ui.Image? retainedImage;
    if (previous != null) {
      _bytes -= previous.byteSize;
      if (retainPrevious) {
        retainedImage = previous.image;
      } else {
        previous.image.dispose();
      }
    }
    final entry = _ReaderSnapshotEntry(
      image: image,
      contentRevision: contentRevision,
      logicalSize: logicalSize,
      pixelRatio: pixelRatio,
    );
    _entries[key] = entry;
    _bytes += entry.byteSize;
    _trim(protectedKeys);
    return retainedImage;
  }

  void _trim(Set<ReaderPageSnapshotKey> protectedKeys) {
    while (_entries.length > maxEntries || _bytes > maxBytes) {
      ReaderPageSnapshotKey? candidate;
      for (final key in _entries.keys) {
        if (!protectedKeys.contains(key)) {
          candidate = key;
          break;
        }
      }
      if (candidate == null) return;
      final entry = _entries.remove(candidate)!;
      _bytes -= entry.byteSize;
      entry.image.dispose();
    }
  }

  void clearExcept(Set<ReaderPageSnapshotKey> protectedKeys) {
    final keys = _entries.keys
        .where((key) => !protectedKeys.contains(key))
        .toList(growable: false);
    for (final key in keys) {
      final entry = _entries.remove(key)!;
      _bytes -= entry.byteSize;
      entry.image.dispose();
    }
  }

  void remove(ReaderPageSnapshotKey key) {
    final entry = _entries.remove(key);
    if (entry == null) return;
    _bytes -= entry.byteSize;
    entry.image.dispose();
  }

  void dispose() {
    for (final entry in _entries.values) {
      entry.image.dispose();
    }
    _entries.clear();
    _bytes = 0;
  }
}

class _ReaderSnapshotEntry {
  const _ReaderSnapshotEntry({
    required this.image,
    required this.contentRevision,
    required this.logicalSize,
    required this.pixelRatio,
  });

  final ui.Image image;
  final int contentRevision;
  final Size logicalSize;
  final double pixelRatio;

  int get byteSize => image.width * image.height * 4;
}

@immutable
class _SnapshotRequestKey {
  const _SnapshotRequestKey({
    required this.pageKey,
    required this.contentRevision,
    required this.logicalSize,
    required this.pixelRatio,
    required this.generation,
  });

  final ReaderPageSnapshotKey pageKey;
  final int contentRevision;
  final Size logicalSize;
  final double pixelRatio;
  final int generation;

  @override
  bool operator ==(Object other) =>
      other is _SnapshotRequestKey &&
      other.pageKey == pageKey &&
      other.contentRevision == contentRevision &&
      other.logicalSize == logicalSize &&
      other.pixelRatio == pixelRatio &&
      other.generation == generation;

  @override
  int get hashCode => Object.hash(
        pageKey,
        contentRevision,
        logicalSize,
        pixelRatio,
        generation,
      );
}
