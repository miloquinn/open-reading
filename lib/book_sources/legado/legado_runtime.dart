import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/registered_book_source.dart';
import '../protocol/book_source_protocol.dart';
import 'legado_book_source.dart';
import 'legado_request.dart';
import 'legado_rule_engine.dart';

class LegadoRuntime {
  LegadoRuntime({LegadoTransport? transport})
    : _transport = transport ?? LegadoHttpTransport();

  static const int _maxSearchItems = 100;
  static const int _maxChapters = 30000;
  static const int _maxPageHops = 20;

  final LegadoTransport _transport;
  final LegadoRuleEngine _rules = const LegadoRuleEngine();

  void close({bool force = true}) {
    final transport = _transport;
    if (transport is LegadoHttpTransport) transport.close(force: force);
  }

  Future<BookSourceSearchPage> search(
    RegisteredBookSource registered,
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final source = _source(registered);
    _ensureRunnable(source);
    final response = await _request(
      source,
      source.searchUrl,
      variables: {'key': query.trim(), 'page': '$page'},
    );
    final document = LegadoRuleDocument.parse(response.body, response.finalUri);
    final rule = source.rule('ruleSearch');
    final contexts = _rules.evaluateList(
      document,
      null,
      _requiredRule(rule, 'bookList'),
    );
    final books = <BookSourceBook>[];
    for (final context in contexts.take(_maxSearchItems)) {
      final book = _bookFromRules(document, context, rule);
      if (book != null) books.add(book);
    }
    return BookSourceSearchPage(
      items: books.take(pageSize).toList(growable: false),
      page: page,
      pageSize: pageSize,
      hasMore: books.length > pageSize,
    );
  }

  Future<BookSourceBook> getBook(
    RegisteredBookSource registered,
    String bookId,
  ) async {
    final source = _source(registered);
    _ensureRunnable(source);
    final response = await _request(source, bookId);
    final document = LegadoRuleDocument.parse(response.body, response.finalUri);
    final rule = source.rule('ruleBookInfo');
    final init = _optionalRule(rule, 'init');
    final context = init.isEmpty
        ? null
        : _rules.evaluateList(document, null, init).firstOrNull;
    final title = _value(document, context, rule, 'name');
    if (title.isEmpty) {
      throw const BookSourceProtocolException(
        'Compatible source did not return a book title.',
      );
    }
    return BookSourceBook(
      id: response.finalUri.toString(),
      title: title,
      author: _value(document, context, rule, 'author'),
      description: _value(document, context, rule, 'intro'),
      coverUrl: _uriValue(document, context, rule, 'coverUrl'),
      categories: _splitCategories(_value(document, context, rule, 'kind')),
      status: _nullable(_value(document, context, rule, 'status')),
      latestChapter: _nullable(_value(document, context, rule, 'lastChapter')),
    );
  }

  Future<List<BookSourceChapter>> getChapters(
    RegisteredBookSource registered,
    String bookId,
  ) async {
    final source = _source(registered);
    _ensureRunnable(source);
    final tocUrl = await _tocUrl(source, bookId);
    final rule = source.rule('ruleToc');
    final chapters = <BookSourceChapter>[];
    final seenPages = <String>{};
    final seenChapters = <String>{};
    var nextUrl = tocUrl;
    for (var hop = 0; hop < _maxPageHops && nextUrl.isNotEmpty; hop++) {
      if (!seenPages.add(nextUrl)) break;
      final response = await _request(source, nextUrl);
      final document = LegadoRuleDocument.parse(
        response.body,
        response.finalUri,
      );
      final contexts = _rules.evaluateList(
        document,
        null,
        _requiredRule(rule, 'chapterList'),
      );
      for (final context in contexts) {
        final title = _value(document, context, rule, 'chapterName');
        final url = _url(document, context, rule, 'chapterUrl');
        if (title.isEmpty || url.isEmpty || !seenChapters.add(url)) continue;
        if (chapters.length >= _maxChapters) {
          throw const BookSourceProtocolException(
            'Compatible source chapter catalog exceeds the supported limit.',
          );
        }
        chapters.add(
          BookSourceChapter(id: url, title: title, order: chapters.length),
        );
      }
      nextUrl = _url(document, null, rule, 'nextTocUrl');
    }
    if (chapters.isEmpty) {
      throw const BookSourceProtocolException(
        'Compatible source did not return any chapters.',
      );
    }
    return chapters;
  }

  Future<BookSourceChapterContent> getChapterContent(
    RegisteredBookSource registered, {
    required String bookId,
    required String chapterId,
  }) async {
    final source = _source(registered);
    _ensureRunnable(source);
    final rule = source.rule('ruleContent');
    final parts = <String>[];
    final seenPages = <String>{};
    var nextUrl = chapterId;
    for (var hop = 0; hop < _maxPageHops && nextUrl.isNotEmpty; hop++) {
      if (!seenPages.add(nextUrl)) break;
      final response = await _request(source, nextUrl);
      final document = LegadoRuleDocument.parse(
        response.body,
        response.finalUri,
      );
      var content = _value(document, null, rule, 'content', required: true);
      content = _rules.applyReplaceRule(
        content,
        _optionalRule(rule, 'replaceRegex'),
      );
      if (content.trim().isNotEmpty) parts.add(content.trim());
      nextUrl = _url(document, null, rule, 'nextContentUrl');
    }
    if (parts.isEmpty) {
      throw const BookSourceProtocolException(
        'Compatible source did not return chapter content.',
      );
    }
    return BookSourceChapterContent(
      bookId: bookId,
      chapterId: chapterId,
      title: '',
      content: parts.join('\n\n'),
      contentType: 'text/html',
    );
  }

  Future<String> _tocUrl(LegadoBookSource source, String bookId) async {
    final rule = source.rule('ruleBookInfo');
    final tocRule = _optionalRule(rule, 'tocUrl');
    if (tocRule.isEmpty) return bookId;
    final response = await _request(source, bookId);
    final document = LegadoRuleDocument.parse(response.body, response.finalUri);
    final init = _optionalRule(rule, 'init');
    final context = init.isEmpty
        ? null
        : _rules.evaluateList(document, null, init).firstOrNull;
    return _rules.evaluateString(document, context, tocRule, resolveUrl: true);
  }

  BookSourceBook? _bookFromRules(
    LegadoRuleDocument document,
    Object? context,
    Map<String, dynamic> rule,
  ) {
    final title = _value(document, context, rule, 'name');
    final url = _url(document, context, rule, 'bookUrl');
    if (title.isEmpty || url.isEmpty) return null;
    return BookSourceBook(
      id: url,
      title: title,
      author: _value(document, context, rule, 'author'),
      description: _value(document, context, rule, 'intro'),
      coverUrl: _uriValue(document, context, rule, 'coverUrl'),
      categories: _splitCategories(_value(document, context, rule, 'kind')),
      latestChapter: _nullable(_value(document, context, rule, 'lastChapter')),
    );
  }

  Future<LegadoResponse> _request(
    LegadoBookSource source,
    String template, {
    Map<String, String> variables = const {},
  }) {
    return _transport.send(
      LegadoRequestTemplate.parse(
        template,
        baseUri: source.baseUri,
        variables: variables,
        sourceHeaders: _sourceHeaders(source),
      ),
    );
  }

  Map<String, String> _sourceHeaders(LegadoBookSource source) {
    final raw = source.raw['header'];
    if (raw == null || '$raw'.trim().isEmpty) return const {};
    Object? decoded = raw;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        throw const BookSourceProtocolException(
          'Compatible source headers must be valid JSON.',
        );
      }
    }
    if (decoded is! Map) {
      throw const BookSourceProtocolException(
        'Compatible source headers must be an object.',
      );
    }
    final headers = <String, String>{};
    for (final entry in decoded.entries) {
      final name = '${entry.key}'.trim();
      if (name.toLowerCase() == 'cookie') {
        throw const BookSourceProtocolException(
          'Compatible source cookie headers are not supported.',
        );
      }
      if (name.isEmpty || entry.value is! String) {
        throw const BookSourceProtocolException(
          'Compatible source headers must contain text values.',
        );
      }
      headers[name] = entry.value as String;
    }
    return headers;
  }

  LegadoBookSource _source(RegisteredBookSource registered) {
    if (registered.sourceProtocol != BookSourceProtocolKind.legado ||
        registered.sourceConfig == null) {
      throw const BookSourceProtocolException(
        'This is not a compatible source configuration.',
      );
    }
    return LegadoBookSource.fromJson(registered.sourceConfig!);
  }

  void _ensureRunnable(LegadoBookSource source) {
    final report = const LegadoCompatibilityScanner().scan(source);
    final blockedIssues = report.issues.where(
      (issue) => issue != LegadoCompatibilityIssue.complexJsonPath,
    );
    if (blockedIssues.isNotEmpty) {
      throw const BookSourceProtocolException(
        'This compatible source uses features that are not supported yet.',
      );
    }
    final headers = _sourceHeaders(source);
    LegadoRequestTemplate.parse(
      source.searchUrl,
      baseUri: source.baseUri,
      variables: const {'key': 'preflight', 'page': '1'},
      sourceHeaders: headers,
    );
    for (final groupName in const [
      'ruleSearch',
      'ruleBookInfo',
      'ruleToc',
      'ruleContent',
    ]) {
      for (final entry in source.rule(groupName).entries) {
        if (entry.value is String) {
          LegadoRuleEngine.ensureSupported(
            entry.value as String,
            field: '$groupName.${entry.key}',
          );
        }
      }
    }
  }

  String _value(
    LegadoRuleDocument document,
    Object? context,
    Map<String, dynamic> rules,
    String key, {
    bool required = false,
  }) {
    final rule = required
        ? _requiredRule(rules, key)
        : _optionalRule(rules, key);
    if (rule.isEmpty) return '';
    return _rules.evaluateString(document, context, rule);
  }

  String _url(
    LegadoRuleDocument document,
    Object? context,
    Map<String, dynamic> rules,
    String key,
  ) {
    final rule = _optionalRule(rules, key);
    if (rule.isEmpty) return '';
    return _rules.evaluateString(document, context, rule, resolveUrl: true);
  }

  Uri? _uriValue(
    LegadoRuleDocument document,
    Object? context,
    Map<String, dynamic> rules,
    String key,
  ) {
    final value = _url(document, context, rules, key);
    return value.isEmpty ? null : Uri.tryParse(value);
  }
}

String _requiredRule(Map<String, dynamic> rules, String key) {
  final rule = _optionalRule(rules, key);
  if (rule.isEmpty) {
    throw BookSourceProtocolException(
      'Compatible source is missing the $key rule.',
    );
  }
  return rule;
}

String _optionalRule(Map<String, dynamic> rules, String key) {
  final value = rules[key];
  return value is String ? value.trim() : '';
}

String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

List<String> _splitCategories(String value) => value
    .split(RegExp(r'[,/|\s]+'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toSet()
    .toList(growable: false);

String stableLegadoResourceId(String value) =>
    sha256.convert(utf8.encode(value)).toString().substring(0, 24);
