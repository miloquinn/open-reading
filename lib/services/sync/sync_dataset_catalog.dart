import 'sync_models.dart';

/// Stable protocol datasets and the capabilities exposed by this release.
///
/// Unsupported datasets remain reserved in the protocol. Remote records can
/// stay in `sync_records` without being scanned from or materialized into the
/// app's business tables. A future release can enable the capability and
/// materialize those retained records without changing remote identities.
enum SyncDataset {
  books('books'),
  progress('progress'),
  bookmarks('bookmarks'),
  notes('notes'),
  readingSessions('reading_sessions');

  const SyncDataset(this.remoteName);

  final String remoteName;

  static SyncDataset? fromRemoteName(String value) {
    for (final dataset in values) {
      if (dataset.remoteName == value) return dataset;
    }
    return null;
  }
}

class SyncDatasetCatalog {
  const SyncDatasetCatalog._();

  static bool isSupported(SyncDataset dataset) => switch (dataset) {
        SyncDataset.books ||
        SyncDataset.progress ||
        SyncDataset.bookmarks ||
        SyncDataset.readingSessions =>
          true,
        // Notes and highlights do not yet have a complete product surface.
        SyncDataset.notes => false,
      };

  static bool isEnabled(SyncDataset dataset, WebDavSyncScope scope) {
    if (!isSupported(dataset)) return false;
    return switch (dataset) {
      SyncDataset.books => scope.books,
      SyncDataset.progress => scope.progress,
      SyncDataset.bookmarks => scope.bookmarks,
      SyncDataset.notes => scope.notes,
      SyncDataset.readingSessions => scope.readingSessions,
    };
  }

  static WebDavSyncScope normalizeScope(WebDavSyncScope scope) =>
      scope.copyWith(
        notes: isSupported(SyncDataset.notes) ? scope.notes : false,
      );
}
