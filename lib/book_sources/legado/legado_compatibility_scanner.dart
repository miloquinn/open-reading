import 'legado_book_source.dart';

enum LegadoCompatibilityLevel { lite, adapterRequired, unsupported }

enum LegadoCapabilityRisk {
  javascript,
  webView,
  login,
  cookies,
  fileAccess,
  captcha,
  customCrypto,
  audioSource,
  missingSearch,
  missingReadingRules,
}

class LegadoCompatibilityReport {
  final LegadoCompatibilityLevel level;
  final Set<LegadoCapabilityRisk> risks;

  const LegadoCompatibilityReport({
    required this.level,
    required this.risks,
  });

  bool get canRunInLite => level == LegadoCompatibilityLevel.lite;
}

class LegadoCompatibilityScanner {
  const LegadoCompatibilityScanner();

  LegadoCompatibilityReport scan(LegadoBookSource source) {
    final risks = <LegadoCapabilityRisk>{};
    if (source.type != 0) risks.add(LegadoCapabilityRisk.audioSource);
    if (source.searchUrl.isEmpty) risks.add(LegadoCapabilityRisk.missingSearch);
    if (!_hasReadingRules(source.raw)) {
      risks.add(LegadoCapabilityRisk.missingReadingRules);
    }
    if (source.enabledCookieJar) risks.add(LegadoCapabilityRisk.cookies);

    _walk(source.raw, (key, value) {
      final normalizedKey = key.toLowerCase();
      final text = value is String ? value : '';
      final normalizedText = text.toLowerCase();

      if (_isNonEmpty(value) &&
          (normalizedKey == 'jslib' ||
              normalizedKey.endsWith('js') ||
              normalizedText.contains('<js>') ||
              normalizedText.contains('@js:') ||
              normalizedText.contains('{{'))) {
        risks.add(LegadoCapabilityRisk.javascript);
      }
      if (_isNonEmpty(value) &&
          (normalizedKey.contains('webview') ||
              normalizedKey == 'webjs' ||
              normalizedText.contains('<webjs>') ||
              normalizedText.contains('java.webview'))) {
        risks.add(LegadoCapabilityRisk.webView);
      }
      if (_isNonEmpty(value) &&
          (normalizedKey == 'loginurl' ||
              normalizedKey == 'loginui' ||
              normalizedKey == 'logincheckjs')) {
        risks.add(LegadoCapabilityRisk.login);
      }
      if (normalizedText.contains('java.getcookie') ||
          normalizedText.contains('java.setcookie') ||
          normalizedText.contains('java.replacecookie')) {
        risks.add(LegadoCapabilityRisk.cookies);
      }
      if (_containsAny(normalizedText, const [
        'java.getfile',
        'java.readfile',
        'java.readtxtfile',
        'java.deletefile',
        'java.downloadfile',
        'java.unzipfile',
        'java.unrarfile',
        'java.un7zfile',
      ])) {
        risks.add(LegadoCapabilityRisk.fileAccess);
      }
      if (normalizedText.contains('getverificationcode')) {
        risks.add(LegadoCapabilityRisk.captcha);
      }
      if (_containsAny(normalizedText, const [
        'createsymmetriccrypto',
        'aesdecode',
        'aesencode',
        'desdecode',
        'desencode',
      ])) {
        risks.add(LegadoCapabilityRisk.customCrypto);
      }
    });

    final level = risks.contains(LegadoCapabilityRisk.audioSource) ||
            risks.contains(LegadoCapabilityRisk.missingReadingRules)
        ? LegadoCompatibilityLevel.unsupported
        : risks.any(_requiresAdapter)
            ? LegadoCompatibilityLevel.adapterRequired
            : LegadoCompatibilityLevel.lite;
    return LegadoCompatibilityReport(
      level: level,
      risks: Set.unmodifiable(risks),
    );
  }
}

bool _hasReadingRules(Map<String, dynamic> raw) {
  return raw['ruleBookInfo'] is Map &&
      raw['ruleToc'] is Map &&
      raw['ruleContent'] is Map;
}

bool _requiresAdapter(LegadoCapabilityRisk risk) {
  return switch (risk) {
    LegadoCapabilityRisk.javascript ||
    LegadoCapabilityRisk.webView ||
    LegadoCapabilityRisk.login ||
    LegadoCapabilityRisk.cookies ||
    LegadoCapabilityRisk.fileAccess ||
    LegadoCapabilityRisk.captcha ||
    LegadoCapabilityRisk.customCrypto =>
      true,
    LegadoCapabilityRisk.audioSource ||
    LegadoCapabilityRisk.missingSearch ||
    LegadoCapabilityRisk.missingReadingRules =>
      false,
  };
}

void _walk(Object? value, void Function(String key, Object? value) visitor,
    [String key = '']) {
  visitor(key, value);
  if (value is Map) {
    for (final entry in value.entries) {
      _walk(entry.value, visitor, '${entry.key}');
    }
  } else if (value is List) {
    for (final item in value) {
      _walk(item, visitor, key);
    }
  }
}

bool _isNonEmpty(Object? value) {
  if (value is String) return value.trim().isNotEmpty;
  if (value is Map || value is List) return true;
  return value != null;
}

bool _containsAny(String input, List<String> needles) =>
    needles.any(input.contains);
