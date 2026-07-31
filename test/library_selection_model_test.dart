import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/pages/library/library_selection_model.dart';

void main() {
  group('LibrarySelectionModel', () {
    test('enters selection mode with the initiating book selected', () {
      final selection = LibrarySelectionModel();

      selection.enter(7);

      expect(selection.isActive, isTrue);
      expect(selection.selectedIds, {7});
    });

    test('toggles books and exits when selection is cancelled', () {
      final selection = LibrarySelectionModel()..enter(7);

      selection.toggle(9);
      selection.toggle(7);

      expect(selection.selectedIds, {9});

      selection.exit();

      expect(selection.isActive, isFalse);
      expect(selection.selectedIds, isEmpty);
    });

    test('select all replaces selection with current visible book ids', () {
      final selection = LibrarySelectionModel()..enter(1);

      selection.selectAllVisible([2, 4, 6]);

      expect(selection.selectedIds, {2, 4, 6});
      expect(selection.areAllVisibleSelected([2, 4, 6]), isTrue);
      expect(selection.areAllVisibleSelected([2, 4]), isTrue);
      expect(selection.areAllVisibleSelected([2, 4, 8]), isFalse);
    });

    test('retains only failed or still existing book ids', () {
      final selection = LibrarySelectionModel()..selectAllVisible([2, 4, 6]);

      selection.retainOnly({4, 6, 8});

      expect(selection.selectedIds, {4, 6});
      expect(selection.isActive, isTrue);
    });
  });
}
