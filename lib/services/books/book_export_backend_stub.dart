import 'package:xxread/services/books/book_export_models.dart';

BookExportBackend createDefaultBookExportBackend() =>
    const _UnsupportedBookExportBackend();

class _UnsupportedBookExportBackend implements BookExportBackend {
  const _UnsupportedBookExportBackend();

  @override
  Future<BookExportBackendResult> export(BookExportRequest request) async =>
      const BookExportBackendResult.unsupported();
}
