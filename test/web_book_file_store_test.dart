import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/books/web_book_file_store.dart';

void main() {
  const md5Hash = '0123456789abcdef0123456789abcdef';
  const sha256Hash =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  test('生成并解析 MD5 或 SHA-256 虚拟路径', () {
    expect(WebBookFileStore.pathForHash(md5Hash), 'web-book://$md5Hash');
    expect(WebBookFileStore.pathForHash(sha256Hash), 'web-book://$sha256Hash');
    expect(WebBookFileStore.hashFromPath('web-book://$sha256Hash'), sha256Hash);
    expect(WebBookFileStore.isWebBookPath('web-book://$md5Hash'), isTrue);
    expect(WebBookFileStore.isWebBookPath('/tmp/book.epub'), isFalse);
  });

  test('拒绝不安全或格式错误的虚拟路径', () {
    for (final path in <String>[
      'web-book://',
      'web-book://../book',
      'web-book://ABCDEF0123456789ABCDEF0123456789',
      'web-book://${md5Hash}extra',
      '/tmp/$md5Hash',
    ]) {
      expect(() => WebBookFileStore.hashFromPath(path), throwsFormatException);
    }
    expect(
      () => WebBookFileStore.pathForHash('../book'),
      throwsFormatException,
    );
  });
}
