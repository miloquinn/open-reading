// 文件说明：WebDAV 路径辅助工具，统一管理云端目录和文件命名规则。
// 技术要点：服务层。

/// WebDAV 远端路径规范。
///
/// 目标：
/// 1) 所有路径集中管理，避免字符串散落。
/// 2) 未来扩展（笔记/高亮/批注）只改这一处。
/// 3) 让新手一眼能看懂 WebDAV 的目录结构。
class WebDavSyncPathHelper {
  static const String rootDir = 'xxread/';

  static const String metaDir = '${rootDir}meta/';
  static const String booksDir = '${rootDir}books/';
  static const String bookmarksDir = '${rootDir}bookmarks/';
  static const String notesDir = '${rootDir}notes/';
  static const String highlightsDir = '${rootDir}highlights/';
  static const String annotationsDir = '${rootDir}annotations/';
  static const String progressDir = '${rootDir}progress/';
  static const String statsDir = '${rootDir}stats/';
  static const String settingsDir = '${rootDir}settings/';
  static const String filesDir = '${rootDir}files/';
  static const String coversDir = '${rootDir}covers/';

  static const String deviceMetaFile = '${metaDir}device_id.json';
  static const String syncManifestFile = '${metaDir}sync_manifest.json';

  static const String booksFile = '${booksDir}books.json';
  static const String bookmarksFile = '${bookmarksDir}bookmarks.json';
  static const String notesFile = '${notesDir}notes.json';
  static const String highlightsFile = '${highlightsDir}highlights.json';
  static const String annotationsFile = '${annotationsDir}annotations.json';
  static const String progressFile = '${progressDir}progress.json';
  static const String statsFile = '${statsDir}reading_stats.json';

  static const List<String> allDirectories = [
    rootDir,
    metaDir,
    booksDir,
    bookmarksDir,
    notesDir,
    highlightsDir,
    annotationsDir,
    progressDir,
    statsDir,
    settingsDir,
    filesDir,
    coversDir,
  ];

  static String buildBookFilePath(String fileName) {
    return '$filesDir$fileName';
  }

  static String buildCoverFilePath(String fileName) {
    return '$coversDir$fileName';
  }
}
