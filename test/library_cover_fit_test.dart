import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/utils/layout_helper.dart';

void main() {
  test('fixed book cover frames always crop their images to fill', () {
    expect(LayoutHelper.bookCoverFit, BoxFit.cover);
    expect(LayoutHelper.coverOnlyGridFit, BoxFit.cover);
  });
}
