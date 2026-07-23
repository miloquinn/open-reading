import 'dart:convert';
import 'dart:io';

String readIndexedUtf8RangeSync({
  required String path,
  required int startOffset,
  required int endOffset,
}) {
  final handle = File(path).openSync();
  try {
    handle.setPositionSync(startOffset);
    return utf8.decode(handle.readSync(endOffset - startOffset));
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
    return utf8.decode(await handle.read(endOffset - startOffset));
  } finally {
    await handle.close();
  }
}
