// 文件说明：验证原生已物化的入站文件并转换为导入来源。
// 技术要点：扩展名/MIME/文件头联合校验、定长头读取、无敏感 URI 持久化。

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:xxread/services/books/book_format_support.dart';
import 'package:xxread/services/books/book_import_models.dart';
import 'package:xxread/services/books/incoming_book_models.dart';

class IncomingBookMaterializer {
  static const int maximumRequestItems = 10;
  static const int maximumBookBytes = 100 * 1024 * 1024;
  static const int maximumRequestBytes = 500 * 1024 * 1024;
  static const Set<String> supportedIncomingExtensions = {'txt', 'epub'};

  Future<BookImportSource> prepare(
    IncomingBookRequest request,
    IncomingBookItem item,
  ) async {
    if (item.localPath.isEmpty) {
      throw const IncomingBookFailure('permission_expired');
    }
    final file = File(item.localPath);
    if (!await file.exists()) {
      throw const IncomingBookFailure('permission_expired');
    }
    final stat = await file.stat();
    if (stat.size > maximumBookBytes) {
      throw const IncomingBookFailure('file_too_large');
    }

    final displayName = _safeDisplayName(item, file.path);
    final extension = BookFormatRegistry.normalizeExtension(
      path.extension(displayName),
    );
    if (!supportedIncomingExtensions.contains(extension)) {
      throw const IncomingBookFailure('unsupported_format');
    }
    if (!_mimeMatches(extension, item.mimeType)) {
      throw const IncomingBookFailure('content_mismatch');
    }
    await _validateHeader(file, extension);

    final kind = request.action == IncomingBookAction.share
        ? BookImportSourceKind.systemShare
        : BookImportSourceKind.systemOpen;
    return BookImportSource(
      id: '${kind.storageValue}:${request.requestId}:${item.id}',
      kind: kind,
      ownership: BookImportOwnership.externalCopy,
      displayName: displayName,
      extension: extension,
      locator: '${kind.storageValue}:${request.requestId}:${item.id}',
      localPath: file.path,
      sizeBytes: stat.size,
      modifiedTime: item.modifiedTime ?? stat.modified.millisecondsSinceEpoch,
    );
  }

  String _safeDisplayName(IncomingBookItem item, String localPath) {
    var name = path.basename(item.displayName.trim());
    if (name.isEmpty || path.extension(name).isEmpty) {
      name = path.basename(localPath);
    }
    name = name
        .replaceAll(RegExp(r'[\x00-\x1f<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (name.length > 180) {
      final extension = path.extension(name);
      name = '${name.substring(0, 180 - extension.length)}$extension';
    }
    return name;
  }

  bool _mimeMatches(String extension, String? rawMime) {
    final mime = rawMime?.toLowerCase().split(';').first.trim();
    if (mime == null ||
        mime.isEmpty ||
        mime == 'application/octet-stream' ||
        mime == '*/*') {
      return true;
    }
    return switch (extension) {
      'txt' || 'md' || 'markdown' => mime == 'text/plain',
      'epub' => mime == 'application/epub+zip',
      'pdf' => mime == 'application/pdf',
      'html' ||
      'htm' ||
      'xhtml' => mime == 'text/html' || mime == 'application/xhtml+xml',
      'fb2' => mime == 'application/x-fictionbook+xml' || mime == 'text/xml',
      _ => true,
    };
  }

  Future<void> _validateHeader(File file, String extension) async {
    final handle = await file.open();
    try {
      final header = await handle.read(64 * 1024);
      if (extension == 'pdf') {
        if (header.length < 5 ||
            ascii.decode(header.take(5).toList()) != '%PDF-') {
          throw const IncomingBookFailure('content_mismatch');
        }
        return;
      }
      if (extension == 'epub') {
        final hasZipMagic =
            header.length >= 4 &&
            header[0] == 0x50 &&
            header[1] == 0x4b &&
            (header[2] == 0x03 || header[2] == 0x05 || header[2] == 0x07) &&
            (header[3] == 0x04 || header[3] == 0x06 || header[3] == 0x08);
        final marker = utf8.encode('application/epub+zip');
        if (!hasZipMagic || !_containsBytes(header, marker)) {
          throw const IncomingBookFailure('content_mismatch');
        }
        return;
      }
      if (extension == 'txt' || extension == 'md' || extension == 'markdown') {
        final looksLikePdf =
            header.length >= 5 &&
            header[0] == 0x25 &&
            header[1] == 0x50 &&
            header[2] == 0x44 &&
            header[3] == 0x46 &&
            header[4] == 0x2d;
        final looksLikeZip =
            header.length >= 4 &&
            header[0] == 0x50 &&
            header[1] == 0x4b &&
            header[2] == 0x03 &&
            header[3] == 0x04;
        if (looksLikePdf || looksLikeZip) {
          throw const IncomingBookFailure('content_mismatch');
        }
      }
    } finally {
      await handle.close();
    }
  }

  bool _containsBytes(List<int> bytes, List<int> marker) {
    if (marker.isEmpty || bytes.length < marker.length) return false;
    for (var i = 0; i <= bytes.length - marker.length; i++) {
      var matches = true;
      for (var j = 0; j < marker.length; j++) {
        if (bytes[i + j] != marker[j]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }
}
