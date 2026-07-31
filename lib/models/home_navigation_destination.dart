// 文件说明：首页导航目的地稳定标识与排序规范化。
// 技术要点：持久化只保存稳定 ID，不依赖本地化标题或页面索引。

enum HomeNavigationDestination {
  home('home'),
  library('library'),
  discover('discover'),
  ai('ai'),
  settings('settings');

  const HomeNavigationDestination(this.storageId);

  final String storageId;

  static HomeNavigationDestination? fromStorageId(String id) {
    for (final destination in values) {
      if (destination.storageId == id) return destination;
    }
    return null;
  }
}

const List<HomeNavigationDestination> defaultHomeNavigationOrder = [
  HomeNavigationDestination.home,
  HomeNavigationDestination.library,
  HomeNavigationDestination.discover,
  HomeNavigationDestination.ai,
  HomeNavigationDestination.settings,
];

List<HomeNavigationDestination> normalizeHomeNavigationOrder(
  Iterable<String>? storedIds,
) {
  final normalized = <HomeNavigationDestination>[];
  final seen = <HomeNavigationDestination>{};

  for (final id in storedIds ?? const <String>[]) {
    final destination = HomeNavigationDestination.fromStorageId(id);
    if (destination != null && seen.add(destination)) {
      normalized.add(destination);
    }
  }

  for (final destination in defaultHomeNavigationOrder) {
    if (seen.add(destination)) normalized.add(destination);
  }

  return List<HomeNavigationDestination>.unmodifiable(normalized);
}

/// 规范化隐藏目的地集合：忽略未知 ID，设置页永远不可隐藏，
/// 全部隐藏的非法状态回退为全部显示。
Set<HomeNavigationDestination> normalizeHiddenHomeNavigationDestinations(
  Iterable<String>? storedIds,
) {
  final hidden = <HomeNavigationDestination>{};
  for (final id in storedIds ?? const <String>[]) {
    final destination = HomeNavigationDestination.fromStorageId(id);
    if (destination != null &&
        destination != HomeNavigationDestination.settings) {
      hidden.add(destination);
    }
  }
  if (hidden.length >= HomeNavigationDestination.values.length) {
    return const <HomeNavigationDestination>{};
  }
  return Set<HomeNavigationDestination>.unmodifiable(hidden);
}
