import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/utils/layout_helper.dart';

void main() {
  test('library grid covers always crop to the shared 2:3 frame', () {
    expect(LayoutHelper.coverOnlyGridFit, BoxFit.cover);
  });
}
