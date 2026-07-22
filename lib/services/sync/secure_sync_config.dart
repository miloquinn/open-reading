import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_models.dart';

abstract interface class SyncSecretStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSyncSecretStorage implements SyncSecretStorage {
  FlutterSyncSecretStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

abstract interface class SyncPreferences {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SharedSyncPreferences implements SyncPreferences {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async {
    await (await SharedPreferences.getInstance()).setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await (await SharedPreferences.getInstance()).remove(key);
  }
}

class StoredSyncCredentials {
  const StoredSyncCredentials(this.configuration, this.password);

  final WebDavSyncConfiguration configuration;
  final String password;
}

class SecureSyncConfigStore {
  SecureSyncConfigStore({
    SyncSecretStorage? secretStorage,
    SyncPreferences? preferences,
  })  : _secretStorage = secretStorage ?? FlutterSyncSecretStorage(),
        _preferences = preferences ?? SharedSyncPreferences();

  static const _configurationKey = 'webdav_sync_configuration_v1';
  static const _scopeKey = 'webdav_sync_scope_v1';
  static const _passwordKey = 'open_reading.webdav.password';

  final SyncSecretStorage _secretStorage;
  final SyncPreferences _preferences;

  Future<WebDavSyncConfiguration?> readConfiguration() async {
    final raw = await _preferences.read(_configurationKey);
    if (raw == null) return null;
    return WebDavSyncConfiguration.fromJson(
      (jsonDecode(raw) as Map).cast<String, dynamic>(),
    );
  }

  Future<StoredSyncCredentials?> readCredentials() async {
    final configuration = await readConfiguration();
    if (configuration == null) return null;
    try {
      final password = await _secretStorage.read(_passwordKey);
      if (password == null || password.isEmpty) return null;
      return StoredSyncCredentials(configuration, password);
    } catch (_) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.secureStorage,
        'The WebDAV password could not be read from secure storage.',
      );
    }
  }

  Future<void> save(
    WebDavSyncConfiguration configuration,
    String password,
  ) async {
    validateWebDavConfiguration(configuration, password: password);
    // Write the secret first. A secure-storage failure must never cause a
    // configuration to be persisted without usable credentials.
    try {
      await _secretStorage.write(_passwordKey, password);
    } catch (_) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.secureStorage,
        'The WebDAV password could not be saved securely.',
      );
    }
    await _preferences.write(_configurationKey, jsonEncode(configuration));
  }

  Future<WebDavSyncScope> readScope() async {
    final raw = await _preferences.read(_scopeKey);
    if (raw == null) return const WebDavSyncScope();
    return WebDavSyncScope.fromJson(
      (jsonDecode(raw) as Map).cast<String, dynamic>(),
    );
  }

  Future<void> saveScope(WebDavSyncScope scope) =>
      _preferences.write(_scopeKey, jsonEncode(scope));

  Future<void> clear() async {
    try {
      await _secretStorage.delete(_passwordKey);
    } catch (_) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.secureStorage,
        'The WebDAV password could not be removed from secure storage.',
      );
    }
    await _preferences.delete(_configurationKey);
    await _preferences.delete(_scopeKey);
  }
}

Uri validateWebDavConfiguration(
  WebDavSyncConfiguration configuration, {
  String? password,
}) {
  final uri = Uri.tryParse(configuration.serverUrl.trim());
  if (uri == null ||
      !uri.hasScheme ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const WebDavSyncFailure(
      WebDavSyncErrorCode.invalidConfiguration,
      'Enter a valid WebDAV server address without embedded credentials.',
    );
  }
  if (configuration.username.trim().isEmpty ||
      (password != null && password.isEmpty) ||
      configuration.rootPath.trim().isEmpty) {
    throw const WebDavSyncFailure(
      WebDavSyncErrorCode.invalidConfiguration,
      'Server, username, password, and remote folder are required.',
    );
  }
  if (uri.scheme != 'https') {
    final privateHost = _isPrivateHost(uri.host);
    if (uri.scheme != 'http' ||
        !privateHost ||
        !configuration.allowInsecurePrivateHttp) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.insecureConnection,
        'HTTPS is required. HTTP can only be explicitly enabled for a private or localhost address.',
      );
    }
  }
  return uri;
}

bool _isPrivateHost(String host) {
  final normalized = host.toLowerCase();
  if (normalized == 'localhost' || normalized.endsWith('.local')) return true;
  final parts = normalized.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.any((part) => part == null)) return false;
  final a = parts[0]!;
  final b = parts[1]!;
  return a == 10 ||
      a == 127 ||
      (a == 192 && b == 168) ||
      (a == 172 && b >= 16 && b <= 31);
}
