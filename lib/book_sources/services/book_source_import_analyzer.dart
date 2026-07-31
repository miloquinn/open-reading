import 'dart:convert';
import 'dart:typed_data';

import '../legado/legado_source_import_service.dart';
import '../models/registered_book_source.dart';
import '../protocol/book_source_protocol.dart';
import 'book_source_client.dart';

enum BookSourceImportKind { orsp, additional }

class BookSourceImportAnalysis {
  const BookSourceImportAnalysis._({
    required this.kind,
    required this.sources,
    this.additionalPreview,
  });

  factory BookSourceImportAnalysis.orsp(RegisteredBookSource source) {
    return BookSourceImportAnalysis._(
      kind: BookSourceImportKind.orsp,
      sources: [source],
    );
  }

  factory BookSourceImportAnalysis.additional(LegadoImportPreview preview) {
    return BookSourceImportAnalysis._(
      kind: BookSourceImportKind.additional,
      sources: const [],
      additionalPreview: preview,
    );
  }

  final BookSourceImportKind kind;
  final List<RegisteredBookSource> sources;
  final LegadoImportPreview? additionalPreview;
}

class BookSourceImportAnalyzer {
  BookSourceImportAnalyzer({LegadoSourceImportService? additionalImporter})
    : _additionalImporter = additionalImporter ?? LegadoSourceImportService();

  final LegadoSourceImportService _additionalImporter;

  Future<BookSourceImportAnalysis> analyzeUrl(String input) async {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('Source URL must use HTTP or HTTPS.');
    }
    Object? directError;
    try {
      final bytes = await _additionalImporter.downloadBytes(input);
      final result = analyzeBytes(bytes, documentUri: uri);
      if (result.kind == BookSourceImportKind.additional &&
          result.sources.isEmpty) {
        final nested = await _additionalImporter.loadUrl(input);
        if (nested.sources.isEmpty) {
          throw const FormatException(
            'No recognized book sources were found at this URL.',
          );
        }
        return BookSourceImportAnalysis.additional(nested);
      }
      return result;
    } catch (error) {
      directError = error;
    }
    // A bare ORSP service URL usually has no JSON body at its root. Keep
    // discovery as the fallback only after direct JSON analysis fails.
    final client = BookSourceClient();
    try {
      final discovered = await client.discover(input);
      return BookSourceImportAnalysis.orsp(
        RegisteredBookSource.fromManifest(
          manifest: discovered.manifest,
          manifestUrl: discovered.manifestUrl,
        ),
      );
    } catch (_) {
      Error.throwWithStackTrace(directError, StackTrace.current);
    } finally {
      client.close();
    }
  }

  BookSourceImportAnalysis analyzeBytes(Uint8List bytes, {Uri? documentUri}) {
    if (bytes.length > LegadoSourceImportService.maxImportBytes) {
      throw const FormatException('Source file exceeds the 64 MiB limit.');
    }
    late final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    } on FormatException catch (error) {
      throw FormatException('Source JSON is invalid: ${error.message}');
    }

    if (decoded is Map && decoded['protocol'] == openReadingSourceProtocol) {
      final manifest = BookSourceManifest.fromJson(
        decoded.map((key, value) => MapEntry('$key', value)),
      );
      final manifestUrl =
          documentUri ??
          manifest.apiBaseUrl.resolve('/$openReadingSourceDiscoveryPath');
      return BookSourceImportAnalysis.orsp(
        RegisteredBookSource.fromManifest(
          manifest: manifest,
          manifestUrl: manifestUrl,
        ),
      );
    }

    return BookSourceImportAnalysis.additional(
      _additionalImporter.parseBytes(bytes),
    );
  }
}
