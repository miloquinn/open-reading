import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

String readIndexedUtf8RangeSync({
  required String path,
  required int startOffset,
  required int endOffset,
}) {
  final handle = File(path).openSync();
  try {
    handle.setPositionSync(startOffset);
    final bytes = handle.readSync(endOffset - startOffset);
    return developer.Timeline.timeSync(
      'chapterUtf8DecodeSync',
      arguments: {'bytes': bytes.length},
      () => utf8.decode(bytes),
    );
  } finally {
    handle.closeSync();
  }
}

Future<String> readIndexedUtf8Range({
  required String path,
  required int startOffset,
  required int endOffset,
}) async {
  final handle = await File(path).open();
  try {
    await handle.setPosition(startOffset);
    final bytes = await handle.read(endOffset - startOffset);
    // 文件 IO 是异步的，但 UTF-8 解码仍在调用方 isolate 同步执行；
    // 大章节可达数十毫秒，打点以便在时间线中定位。
    return developer.Timeline.timeSync(
      'chapterUtf8Decode',
      arguments: {'bytes': bytes.length},
      () => utf8.decode(bytes),
    );
  } finally {
    await handle.close();
  }
}
