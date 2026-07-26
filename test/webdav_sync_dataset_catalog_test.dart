import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/sync/sync_dataset_catalog.dart';
import 'package:xxread/services/sync/sync_models.dart';

void main() {
  test('unsupported note records stay reserved but cannot become active', () {
    expect(SyncDataset.notes.remoteName, 'notes');
    expect(SyncDatasetCatalog.isSupported(SyncDataset.notes), isFalse);
    expect(
      SyncDatasetCatalog.isEnabled(
        SyncDataset.notes,
        const WebDavSyncScope(notes: true),
      ),
      isFalse,
    );
    expect(
      SyncDatasetCatalog.normalizeScope(
        const WebDavSyncScope(notes: true),
      ).notes,
      isFalse,
    );
  });

  test('supported datasets still follow the user scope', () {
    const scope = WebDavSyncScope(bookSources: false, bookmarks: false);
    expect(SyncDatasetCatalog.isEnabled(SyncDataset.books, scope), isTrue);
    expect(
      SyncDatasetCatalog.isEnabled(SyncDataset.bookSources, scope),
      isFalse,
    );
    expect(SyncDatasetCatalog.isEnabled(SyncDataset.bookmarks, scope), isFalse);
  });

  test('book source scope is enabled by default and survives JSON storage', () {
    const scope = WebDavSyncScope();
    expect(scope.bookSources, isTrue);
    expect(WebDavSyncScope.fromJson(scope.toJson()).bookSources, isTrue);
    expect(
      WebDavSyncScope.fromJson(const <String, dynamic>{}).bookSources,
      isTrue,
    );
  });
}
