// Platform facade for the file-backed EPUB parser.

export 'epub_native_parser_stub.dart'
    if (dart.library.io) 'epub_native_parser_io.dart';
