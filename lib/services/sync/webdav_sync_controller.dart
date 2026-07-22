import 'package:flutter/foundation.dart';

import '../../models/book.dart';

import 'secure_sync_config.dart';
import 'sync_change_store.dart';
import 'sync_dataset_catalog.dart';
import 'sync_engine.dart';
import 'sync_models.dart';
import 'webdav_book_file_service.dart';
import 'webdav_client.dart';

class WebDavSyncController extends ChangeNotifier {
  WebDavSyncController({
    SecureSyncConfigStore? configStore,
    SyncChangeStore? changeStore,
    SyncEngine? engine,
    WebDavClientFactory? clientFactory,
    WebDavBookFileService? bookFileService,
  }) : _configStore = configStore ?? SecureSyncConfigStore(),
       _changeStore = changeStore ?? SyncChangeStore(),
       _clientFactory = clientFactory ?? WebDavClient.standard,
       _engine = engine {
    _bookFileService =
        bookFileService ?? WebDavBookFileService(configStore: _configStore);
  }

  final SecureSyncConfigStore _configStore;
  final SyncChangeStore _changeStore;
  final WebDavClientFactory _clientFactory;
  SyncEngine? _engine;
  late final WebDavBookFileService _bookFileService;
  Future<WebDavSyncRunResult>? _running;
  WebDavSyncConfiguration? _configuration;
  WebDavSyncScope _scope = const WebDavSyncScope();
  WebDavSyncStatus _status = WebDavSyncStatus.unconfigured;
  WebDavSyncPhase _phase = WebDavSyncPhase.none;
  WebDavSyncPhase _lastFailedPhase = WebDavSyncPhase.none;
  DateTime? _lastSuccessfulSync;
  int _pendingChanges = 0;
  WebDavSyncErrorCode? _lastError;
  String? _lastErrorMessage;
  WebDavSyncRunResult? _lastResult;
  List<RemoteBookDescriptor> _remoteBooks = const [];
  WebDavNewBookUploadPolicy _newBookUploadPolicy =
      WebDavNewBookUploadPolicy.askEveryTime;

  bool get isConfigured => _configuration != null;
  WebDavSyncStatus get status => _status;
  WebDavSyncPhase get phase => _phase;
  WebDavSyncPhase get lastFailedPhase => _lastFailedPhase;
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;
  int get pendingChanges => _pendingChanges;
  WebDavSyncErrorCode? get lastError => _lastError;
  String? get lastErrorMessage => _lastErrorMessage;
  bool get autoSync => _configuration?.autoSync ?? false;
  WebDavSyncScope get scope => _scope;
  String? get serverUrl => _configuration?.serverUrl;
  String? get username => _configuration?.username;
  String? get rootPath => _configuration?.rootPath;
  WebDavSyncRunResult? get lastResult => _lastResult;
  List<RemoteBookDescriptor> get remoteBooks => _remoteBooks;
  WebDavNewBookUploadPolicy get newBookUploadPolicy => _newBookUploadPolicy;
  SyncFileCapabilities get fileCapabilities => const SyncFileCapabilities();

  Future<void> initialize() async {
    _configuration = await _configStore.readConfiguration();
    _scope = SyncDatasetCatalog.normalizeScope(await _configStore.readScope());
    _newBookUploadPolicy = await _configStore.readNewBookUploadPolicy();
    _pendingChanges = await _changeStore.pendingCount();
    final lastSuccess = await _changeStore.getState('last_successful_sync');
    _lastSuccessfulSync = lastSuccess == null
        ? null
        : DateTime.tryParse(lastSuccess)?.toLocal();
    _status = isConfigured
        ? WebDavSyncStatus.idle
        : WebDavSyncStatus.unconfigured;
    await _refreshRemoteBooks();
    notifyListeners();
  }

  Future<ConnectionTestResult> testConnection(
    WebDavSyncConfigDraft draft,
  ) async {
    _status = WebDavSyncStatus.testing;
    _phase = WebDavSyncPhase.connecting;
    _clearError();
    notifyListeners();
    try {
      final password = await _resolvePassword(draft.password);
      final configuration = draft.withoutPassword(
        autoSync: _configuration?.autoSync ?? true,
      );
      validateWebDavConfiguration(configuration, password: password);
      final result = await _clientFactory(
        StoredSyncCredentials(configuration, password),
      ).testConnection();
      if (!result.success) {
        _lastError = result.errorCode;
        _lastErrorMessage = result.message;
      }
      _status = isConfigured
          ? WebDavSyncStatus.idle
          : WebDavSyncStatus.unconfigured;
      _phase = WebDavSyncPhase.none;
      notifyListeners();
      return result;
    } on WebDavSyncFailure catch (error) {
      _setFailure(error);
      _status = isConfigured
          ? WebDavSyncStatus.idle
          : WebDavSyncStatus.unconfigured;
      _phase = WebDavSyncPhase.none;
      notifyListeners();
      return ConnectionTestResult(
        success: false,
        errorCode: error.code,
        message: error.message,
      );
    }
  }

  Future<void> configure(WebDavSyncConfigDraft draft) async {
    final password = await _resolvePassword(draft.password);
    final configuration = draft.withoutPassword(
      autoSync: _configuration?.autoSync ?? true,
    );
    await _configStore.save(configuration, password);
    _configuration = configuration;
    _status = WebDavSyncStatus.idle;
    _clearError();
    notifyListeners();
  }

  Future<WebDavSyncRunResult> syncNow() {
    final running = _running;
    if (running != null) return running;
    final future = _runSync();
    _running = future;
    future.then<void>((_) => _running = null, onError: (_) => _running = null);
    return future;
  }

  Future<WebDavSyncRunResult> _runSync() async {
    if (!isConfigured) {
      const failure = WebDavSyncFailure(
        WebDavSyncErrorCode.invalidConfiguration,
        'Configure WebDAV before starting sync.',
      );
      _setFailure(failure);
      notifyListeners();
      throw failure;
    }
    _status = WebDavSyncStatus.syncing;
    _phase = WebDavSyncPhase.connecting;
    _clearError();
    notifyListeners();
    try {
      final engine = _engine ??= SyncEngine(
        configStore: _configStore,
        changeStore: _changeStore,
        clientFactory: _clientFactory,
      );
      final result = await engine.run(
        onPhase: (phase) {
          _phase = phase;
          notifyListeners();
        },
      );
      _lastResult = result;
      _lastFailedPhase = WebDavSyncPhase.none;
      _lastSuccessfulSync = result.completedAt;
      await _changeStore.setState(
        'last_successful_sync',
        result.completedAt.toUtc().toIso8601String(),
      );
      _pendingChanges = await _changeStore.pendingCount();
      await _refreshRemoteBooks();
      _status = WebDavSyncStatus.success;
      _phase = WebDavSyncPhase.none;
      notifyListeners();
      return result;
    } on WebDavSyncFailure catch (error) {
      _lastFailedPhase = _phase;
      debugPrint(
        'WebDAV sync failed at ${_phase.name}: ${error.code.name}'
        '${error.statusCode == null ? '' : ' (HTTP ${error.statusCode})'}',
      );
      _setFailure(error);
      _pendingChanges = await _changeStore.pendingCount();
      _phase = WebDavSyncPhase.none;
      notifyListeners();
      rethrow;
    } catch (error, stackTrace) {
      _lastFailedPhase = _phase;
      debugPrint('WebDAV sync failed at ${_phase.name}: ${error.runtimeType}');
      debugPrintStack(stackTrace: stackTrace);
      const failure = WebDavSyncFailure(
        WebDavSyncErrorCode.unknown,
        'Metadata sync could not be completed.',
      );
      _setFailure(failure);
      _phase = WebDavSyncPhase.none;
      notifyListeners();
      throw failure;
    }
  }

  Future<void> setAutoSync(bool enabled) async {
    final current = _configuration;
    if (current == null) return;
    final credentials = await _configStore.readCredentials();
    if (credentials == null) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.secureStorage,
        'The secure WebDAV password is unavailable.',
      );
    }
    final updated = current.copyWith(autoSync: enabled);
    await _configStore.save(updated, credentials.password);
    _configuration = updated;
    notifyListeners();
  }

  Future<void> setScope(WebDavSyncScope scope) async {
    final normalized = SyncDatasetCatalog.normalizeScope(scope);
    await _configStore.saveScope(normalized);
    _scope = normalized;
    notifyListeners();
  }

  Future<void> setNewBookUploadPolicy(WebDavNewBookUploadPolicy policy) async {
    await _configStore.saveNewBookUploadPolicy(policy);
    _newBookUploadPolicy = policy;
    notifyListeners();
  }

  Future<void> clearConfiguration() async {
    await _configStore.clear();
    _configuration = null;
    _scope = const WebDavSyncScope();
    _status = WebDavSyncStatus.unconfigured;
    _phase = WebDavSyncPhase.none;
    _lastFailedPhase = WebDavSyncPhase.none;
    _newBookUploadPolicy = WebDavNewBookUploadPolicy.askEveryTime;
    _clearError();
    notifyListeners();
  }

  Future<void> refreshRemoteBooks() async {
    await _refreshRemoteBooks();
    notifyListeners();
  }

  Future<RemoteBookDescriptor> uploadBookFile(
    Book book, {
    void Function(BookFileTransferProgress progress)? onProgress,
  }) async {
    if (!_scope.bookFiles) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.invalidConfiguration,
        'Enable book-file uploads before selecting a book to upload.',
      );
    }
    final descriptor = await _bookFileService.upload(
      book,
      onProgress: onProgress,
    );
    await syncNow();
    return descriptor;
  }

  Future<Book> downloadBookFile(
    RemoteBookDescriptor descriptor, {
    void Function(BookFileTransferProgress progress)? onProgress,
  }) async {
    final book = await _bookFileService.download(
      descriptor,
      onProgress: onProgress,
    );
    await refreshRemoteBooks();
    return book;
  }

  Future<String> _resolvePassword(String draftPassword) async {
    if (draftPassword.isNotEmpty) return draftPassword;
    final stored = await _configStore.readCredentials();
    if (stored != null && stored.password.isNotEmpty) return stored.password;
    throw const WebDavSyncFailure(
      WebDavSyncErrorCode.authentication,
      'Enter the WebDAV app password.',
    );
  }

  Future<void> _refreshRemoteBooks() async {
    final records = await _changeStore.recordsForDataset('books');
    _remoteBooks = records
        .where((record) => !record.deleted && record.payload != null)
        .map((record) {
          final payload = record.payload!;
          return RemoteBookDescriptor(
            bookUid: record.entityKey,
            title: payload['title'] as String? ?? '',
            author: payload['author'] as String? ?? '',
            format: payload['format'] as String? ?? '',
            fileAvailable: payload['file_available'] as bool? ?? false,
            sizeBytes: (payload['file_size'] as num?)?.toInt(),
            blobSha256: payload['blob_sha256'] as String?,
            remotePath: payload['remote_path'] as String?,
            fileName: payload['file_name'] as String?,
            sourceId: payload['source_id'] as String?,
            sourceBookId: payload['source_book_id'] as String?,
            coverAvailable: payload['cover_available'] as bool? ?? false,
            coverSizeBytes: (payload['cover_file_size'] as num?)?.toInt(),
            coverBlobSha256: payload['cover_blob_sha256'] as String?,
            coverRemotePath: payload['cover_remote_path'] as String?,
            coverFileName: payload['cover_file_name'] as String?,
          );
        })
        .toList(growable: false);
  }

  void _setFailure(WebDavSyncFailure failure) {
    _status = WebDavSyncStatus.failed;
    _lastError = failure.code;
    _lastErrorMessage = failure.message;
  }

  void _clearError() {
    _lastError = null;
    _lastErrorMessage = null;
  }
}
