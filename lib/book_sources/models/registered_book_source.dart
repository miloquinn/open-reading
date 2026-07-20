import '../protocol/book_source_protocol.dart';

class RegisteredBookSource {
  final String id;
  final String name;
  final String description;
  final Uri manifestUrl;
  final Uri apiBaseUrl;
  final Uri? iconUrl;
  final Uri? websiteUrl;
  final String operatorName;
  final Uri? contactUrl;
  final String contentLicense;
  final String rightsStatement;
  final String protocolVersion;
  final List<String> languages;
  final Set<String> capabilities;
  final bool enabled;
  final DateTime addedAt;

  /// Largest `pageSize` this source accepts on the chapter-catalog endpoint.
  /// Absent means the protocol default of 100 applies.
  final int? maxCatalogPageSize;

  const RegisteredBookSource({
    required this.id,
    required this.name,
    required this.description,
    required this.manifestUrl,
    required this.apiBaseUrl,
    required this.protocolVersion,
    required this.languages,
    required this.capabilities,
    required this.enabled,
    required this.addedAt,
    this.iconUrl,
    this.websiteUrl,
    this.operatorName = '',
    this.contactUrl,
    this.contentLicense = '',
    this.rightsStatement = '',
    this.maxCatalogPageSize,
  });

  factory RegisteredBookSource.fromManifest({
    required BookSourceManifest manifest,
    required Uri manifestUrl,
  }) {
    return RegisteredBookSource(
      id: manifest.id,
      name: manifest.name,
      description: manifest.description,
      manifestUrl: manifestUrl,
      apiBaseUrl: manifest.apiBaseUrl,
      iconUrl: manifest.iconUrl,
      websiteUrl: manifest.websiteUrl,
      operatorName: manifest.operatorName,
      contactUrl: manifest.contactUrl,
      contentLicense: manifest.contentLicense,
      rightsStatement: manifest.rightsStatement,
      protocolVersion: manifest.protocolVersion,
      languages: manifest.languages,
      capabilities: manifest.capabilities,
      maxCatalogPageSize: manifest.maxCatalogPageSize,
      enabled: true,
      addedAt: DateTime.now(),
    );
  }

  factory RegisteredBookSource.fromJson(Map<String, dynamic> json) {
    return RegisteredBookSource(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      manifestUrl: Uri.parse(json['manifestUrl'] as String),
      apiBaseUrl: Uri.parse(json['apiBaseUrl'] as String),
      iconUrl: _optionalUri(json['iconUrl']),
      websiteUrl: _optionalUri(json['websiteUrl']),
      operatorName: json['operatorName'] as String? ?? '',
      contactUrl: _optionalUri(json['contactUrl']),
      contentLicense: json['contentLicense'] as String? ?? '',
      rightsStatement: json['rightsStatement'] as String? ?? '',
      protocolVersion: json['protocolVersion'] as String,
      languages: (json['languages'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      capabilities: (json['capabilities'] as List? ?? const [])
          .whereType<String>()
          .toSet(),
      maxCatalogPageSize: (json['maxCatalogPageSize'] as num?)?.toInt(),
      enabled: json['enabled'] as bool? ?? true,
      addedAt:
          DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'manifestUrl': manifestUrl.toString(),
        'apiBaseUrl': apiBaseUrl.toString(),
        if (iconUrl != null) 'iconUrl': iconUrl.toString(),
        if (websiteUrl != null) 'websiteUrl': websiteUrl.toString(),
        if (operatorName.isNotEmpty) 'operatorName': operatorName,
        if (contactUrl != null) 'contactUrl': contactUrl.toString(),
        if (contentLicense.isNotEmpty) 'contentLicense': contentLicense,
        if (rightsStatement.isNotEmpty) 'rightsStatement': rightsStatement,
        'protocolVersion': protocolVersion,
        'languages': languages,
        'capabilities': capabilities.toList()..sort(),
        if (maxCatalogPageSize != null)
          'maxCatalogPageSize': maxCatalogPageSize,
        'enabled': enabled,
        'addedAt': addedAt.toIso8601String(),
      };

  RegisteredBookSource copyWith({bool? enabled}) {
    return RegisteredBookSource(
      id: id,
      name: name,
      description: description,
      manifestUrl: manifestUrl,
      apiBaseUrl: apiBaseUrl,
      iconUrl: iconUrl,
      websiteUrl: websiteUrl,
      operatorName: operatorName,
      contactUrl: contactUrl,
      contentLicense: contentLicense,
      rightsStatement: rightsStatement,
      protocolVersion: protocolVersion,
      languages: languages,
      capabilities: capabilities,
      maxCatalogPageSize: maxCatalogPageSize,
      enabled: enabled ?? this.enabled,
      addedAt: addedAt,
    );
  }
}

Uri? _optionalUri(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final parsed = Uri.tryParse(value);
  // 本地存储可能被篡改，只接受 http/https，防止注入其他 scheme。
  if (parsed == null || (parsed.scheme != 'http' && parsed.scheme != 'https')) {
    return null;
  }
  return parsed;
}
