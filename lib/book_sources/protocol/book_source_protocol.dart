import 'dart:convert';

const String openReadingSourceProtocol = 'open-reading-source';
const String openReadingSourceProtocolVersion = '1.3';
const String openReadingSourceProtocolRepositoryUrl =
    'https://github.com/miloquinn/open-reading-source-protocol';
const String openReadingRightsReportUrl =
    'https://github.com/miloquinn/open-reading/issues/new?template=rights_report.yml';
const String openReadingSourceDiscoveryPath =
    '.well-known/open-reading-source.json';

class BookSourceProtocolException implements Exception {
  final String message;

  /// The source-supplied `error.code`, when the failure carried one.
  final String? code;

  const BookSourceProtocolException(this.message, {this.code});

  @override
  String toString() => message;
}

class BookSourceManifest {
  final String protocol;
  final String protocolVersion;
  final String id;
  final String name;
  final String description;
  final Uri apiBaseUrl;
  final Uri? iconUrl;
  final Uri? websiteUrl;
  final String operatorName;
  final Uri? contactUrl;
  final String contentLicense;
  final String rightsStatement;
  final List<String> languages;
  final Set<String> capabilities;

  /// Largest `pageSize` this source accepts on the chapter-catalog endpoint.
  /// Absent means the protocol default of 100 applies.
  final int? maxCatalogPageSize;

  const BookSourceManifest({
    required this.protocol,
    required this.protocolVersion,
    required this.id,
    required this.name,
    required this.description,
    required this.apiBaseUrl,
    required this.languages,
    required this.capabilities,
    this.iconUrl,
    this.websiteUrl,
    this.operatorName = '',
    this.contactUrl,
    this.contentLicense = '',
    this.rightsStatement = '',
    this.maxCatalogPageSize,
  });

  bool supports(String capability) => capabilities.contains(capability);

  factory BookSourceManifest.fromJson(Map<String, dynamic> json) {
    final protocol = _requiredString(json, 'protocol');
    final protocolVersion = _requiredString(json, 'protocolVersion');
    if (protocol != openReadingSourceProtocol) {
      throw BookSourceProtocolException('Unsupported protocol: $protocol');
    }
    if (protocolVersion.split('.').first !=
        openReadingSourceProtocolVersion.split('.').first) {
      throw BookSourceProtocolException(
        'Unsupported protocol version: $protocolVersion',
      );
    }

    final apiBaseUrl = _httpUri(_requiredString(json, 'apiBaseUrl'));
    final capabilities = _stringList(json['capabilities']).toSet();
    if (!capabilities.contains('search')) {
      throw const BookSourceProtocolException(
        'A v1 source must declare the search capability.',
      );
    }

    return BookSourceManifest(
      protocol: protocol,
      protocolVersion: protocolVersion,
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      description: (json['description'] as String?)?.trim() ?? '',
      apiBaseUrl: apiBaseUrl,
      iconUrl: _optionalHttpUri(json['iconUrl']),
      websiteUrl: _optionalHttpUri(json['websiteUrl']),
      operatorName: (json['operatorName'] as String?)?.trim() ?? '',
      contactUrl: _optionalHttpUri(json['contactUrl']),
      contentLicense: (json['contentLicense'] as String?)?.trim() ?? '',
      rightsStatement: (json['rightsStatement'] as String?)?.trim() ?? '',
      languages: _stringList(json['languages']),
      capabilities: capabilities,
      maxCatalogPageSize: _catalogPageSizeFromJson(json['maxCatalogPageSize']),
    );
  }

  Map<String, dynamic> toJson() => {
        'protocol': protocol,
        'protocolVersion': protocolVersion,
        'id': id,
        'name': name,
        'description': description,
        'apiBaseUrl': apiBaseUrl.toString(),
        if (iconUrl != null) 'iconUrl': iconUrl.toString(),
        if (websiteUrl != null) 'websiteUrl': websiteUrl.toString(),
        if (operatorName.isNotEmpty) 'operatorName': operatorName,
        if (contactUrl != null) 'contactUrl': contactUrl.toString(),
        if (contentLicense.isNotEmpty) 'contentLicense': contentLicense,
        if (rightsStatement.isNotEmpty) 'rightsStatement': rightsStatement,
        'languages': languages,
        'capabilities': capabilities.toList()..sort(),
        if (maxCatalogPageSize != null)
          'maxCatalogPageSize': maxCatalogPageSize,
      };
}

class BookSourceSearchPage {
  final List<BookSourceBook> items;
  final int page;
  final int pageSize;
  final int? total;
  final bool hasMore;

  const BookSourceSearchPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    this.total,
  });

  factory BookSourceSearchPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const BookSourceProtocolException(
        'Search response must contain an items array.',
      );
    }
    return BookSourceSearchPage(
      items: rawItems
          .map((item) => BookSourceBook.fromJson(_jsonMap(item)))
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? rawItems.length,
      total: (json['total'] as num?)?.toInt(),
      hasMore: json['hasMore'] == true,
    );
  }
}

/// A curated shelf returned by an optional discovery-capable source.
class BookSourceDiscoverySection {
  final String id;
  final String title;
  final List<BookSourceBook> items;

  const BookSourceDiscoverySection({
    required this.id,
    required this.title,
    required this.items,
  });

  factory BookSourceDiscoverySection.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const BookSourceProtocolException(
        'Discovery section must contain an items array.',
      );
    }
    return BookSourceDiscoverySection(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      items: rawItems
          .map((item) => BookSourceBook.fromJson(_jsonMap(item)))
          .toList(growable: false),
    );
  }
}

class BookSourceDiscoveryPage {
  final List<BookSourceDiscoverySection> sections;

  const BookSourceDiscoveryPage({required this.sections});

  factory BookSourceDiscoveryPage.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    if (rawSections is! List) {
      throw const BookSourceProtocolException(
        'Discovery response must contain a sections array.',
      );
    }
    return BookSourceDiscoveryPage(
      sections: rawSections
          .map((section) =>
              BookSourceDiscoverySection.fromJson(_jsonMap(section)))
          .toList(growable: false),
    );
  }
}

class BookSourceCategory {
  final String id;
  final String name;

  const BookSourceCategory({required this.id, required this.name});

  factory BookSourceCategory.fromJson(Map<String, dynamic> json) {
    return BookSourceCategory(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
    );
  }
}

class BookSourceBook {
  final String id;
  final String title;
  final String author;
  final String description;
  final Uri? coverUrl;
  final List<String> categories;
  final String? status;
  final String? latestChapter;
  final DateTime? updatedAt;

  const BookSourceBook({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.categories,
    this.coverUrl,
    this.status,
    this.latestChapter,
    this.updatedAt,
  });

  factory BookSourceBook.fromJson(Map<String, dynamic> json) {
    final updatedAtValue = json['updatedAt'] as String?;
    return BookSourceBook(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      author: (json['author'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim() ?? '',
      coverUrl: _optionalHttpUri(json['coverUrl']),
      categories: _stringList(json['categories']),
      status: (json['status'] as String?)?.trim(),
      latestChapter: (json['latestChapter'] as String?)?.trim(),
      updatedAt:
          updatedAtValue == null ? null : DateTime.tryParse(updatedAtValue),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'description': description,
        if (coverUrl != null) 'coverUrl': coverUrl.toString(),
        'categories': categories,
        if (status != null) 'status': status,
        if (latestChapter != null) 'latestChapter': latestChapter,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}

class BookSourceChapter {
  final String id;
  final String title;
  final int order;
  final DateTime? updatedAt;

  const BookSourceChapter({
    required this.id,
    required this.title,
    required this.order,
    this.updatedAt,
  });

  factory BookSourceChapter.fromJson(Map<String, dynamic> json) {
    final updatedAtValue = json['updatedAt'] as String?;
    return BookSourceChapter(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      order: (json['order'] as num?)?.toInt() ?? 0,
      updatedAt:
          updatedAtValue == null ? null : DateTime.tryParse(updatedAtValue),
    );
  }
}

/// One page of a book's chapter catalog.
///
/// Sources that do not implement pagination may omit `page`/`pageSize`/
/// `hasMore` and return every chapter in `items`; that response parses as a
/// single, complete page (`hasMore: false`), matching protocol 1.2 behavior.
class BookSourceChapterPage {
  final List<BookSourceChapter> items;
  final int page;
  final int pageSize;
  final int? total;
  final bool hasMore;

  const BookSourceChapterPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    this.total,
  });

  factory BookSourceChapterPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const BookSourceProtocolException(
        'Chapter response must contain an items array.',
      );
    }
    return BookSourceChapterPage(
      items: rawItems
          .map((item) => BookSourceChapter.fromJson(_jsonMap(item)))
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? rawItems.length,
      total: (json['total'] as num?)?.toInt(),
      hasMore: json['hasMore'] == true,
    );
  }
}

class BookSourceChapterContent {
  final String bookId;
  final String chapterId;
  final String title;
  final String content;
  final String contentType;

  const BookSourceChapterContent({
    required this.bookId,
    required this.chapterId,
    required this.title,
    required this.content,
    required this.contentType,
  });

  factory BookSourceChapterContent.fromJson(Map<String, dynamic> json) {
    final contentType =
        (json['contentType'] as String?)?.trim() ?? 'text/plain';
    const allowedContentTypes = {
      'text/plain',
      'text/markdown',
      'text/html',
    };
    if (!allowedContentTypes.contains(contentType)) {
      throw BookSourceProtocolException(
        'Unsupported chapter content type: $contentType',
      );
    }
    return BookSourceChapterContent(
      bookId: _requiredString(json, 'bookId'),
      chapterId: _requiredString(json, 'chapterId'),
      // Some otherwise compatible sources omit the duplicated chapter title
      // from the content response. The reader can safely fall back to the
      // title already returned by the chapter catalog.
      title: (json['title'] as String?)?.trim() ?? '',
      content: _requiredString(json, 'content'),
      contentType: contentType,
    );
  }
}

Map<String, dynamic> decodeBookSourceJson(Object? data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return data.map((key, value) => MapEntry('$key', value));
  if (data is String) {
    final decoded = jsonDecode(data);
    return _jsonMap(decoded);
  }
  throw const BookSourceProtocolException('Expected a JSON object.');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw BookSourceProtocolException('Missing required field: $key');
  }
  return value.trim();
}

List<String> _stringList(Object? value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const BookSourceProtocolException('Expected an array of strings.');
  }
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

Uri _httpUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    throw BookSourceProtocolException('Invalid HTTP URL: $value');
  }
  return uri;
}

/// Parses the discovery document's `maxCatalogPageSize`. The spec's 100-1000
/// range is a requirement on what a *source* may declare, not something the
/// client should force a value into: a source declaring an out-of-range
/// number is still telling the client the largest page it will accept, and
/// requesting more than that gets rejected regardless of what the spec says
/// sources are supposed to declare. Only reject non-positive/malformed input.
int? _catalogPageSizeFromJson(Object? value) {
  if (value is! num) return null;
  final parsed = value.toInt();
  return parsed > 0 ? parsed : null;
}

Uri? _optionalHttpUri(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) return null;
  return _httpUri(value.trim());
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  throw const BookSourceProtocolException('Expected a JSON object.');
}
