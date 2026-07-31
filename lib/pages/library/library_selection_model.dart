class LibrarySelectionModel {
  bool _isActive = false;
  final Set<int> _selectedIds = <int>{};

  bool get isActive => _isActive;
  Set<int> get selectedIds => Set<int>.unmodifiable(_selectedIds);

  void enter(int bookId) {
    _isActive = true;
    _selectedIds.add(bookId);
  }

  void toggle(int bookId) {
    _isActive = true;
    if (!_selectedIds.remove(bookId)) {
      _selectedIds.add(bookId);
    }
  }

  void selectAllVisible(Iterable<int> bookIds) {
    _isActive = true;
    _selectedIds
      ..clear()
      ..addAll(bookIds);
  }

  bool areAllVisibleSelected(Iterable<int> bookIds) {
    final ids = bookIds.toList(growable: false);
    return ids.isNotEmpty && ids.every(_selectedIds.contains);
  }

  void retainOnly(Set<int> bookIds) {
    _selectedIds.retainAll(bookIds);
  }

  void exit() {
    _isActive = false;
    _selectedIds.clear();
  }
}
