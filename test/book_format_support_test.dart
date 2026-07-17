import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/books/book_format_support.dart';

void main() {
  test('picker 扩展名包含主路径与元数据导入格式，不含 planned 容器', () {
    final picker = BookFormatRegistry.pickerExtensions;

    expect(picker, containsAll(<String>['txt', 'epub', 'pdf', 'mobi', 'azw3']));
    expect(picker, containsAll(<String>['fb2', 'rtf', 'doc', 'docx', 'cbz', 'cbr']));
    expect(picker.contains('zip'), isFalse);
    expect(picker.contains('rar'), isFalse);
  });

  test('扩展名大小写与点号规范化', () {
    expect(BookFormatRegistry.normalizeExtension('.EPUB'), 'epub');
    expect(BookFormatRegistry.isAcceptedByPicker('TXT'), isTrue);
    expect(BookFormatRegistry.specForExtension('azw3')?.id, 'kindle');
  });

  test('文字书目标统一文本分页；PDF/漫画为专用渲染', () {
    expect(BookFormatRegistry.targetsUnifiedTextLayout('txt'), isTrue);
    expect(BookFormatRegistry.targetsUnifiedTextLayout('epub'), isTrue);
    expect(BookFormatRegistry.targetsUnifiedTextLayout('mobi'), isTrue);
    expect(BookFormatRegistry.targetsUnifiedTextLayout('pdf'), isFalse);
    expect(BookFormatRegistry.targetsUnifiedTextLayout('cbz'), isFalse);
  });

  test('当前已具备正文阅读管线的格式', () {
    expect(BookFormatRegistry.hasReadableTextPipeline('txt'), isTrue);
    expect(BookFormatRegistry.hasReadableTextPipeline('epub'), isTrue);
    expect(BookFormatRegistry.hasReadableTextPipeline('mobi'), isFalse);
    expect(BookFormatRegistry.hasReadableTextPipeline('zip'), isFalse);
  });

  test('ZIP/RAR 标记为容器计划项', () {
    final zip = BookFormatRegistry.specForExtension('zip');
    final rar = BookFormatRegistry.specForExtension('rar');
    expect(zip?.capability, BookFormatCapability.planned);
    expect(zip?.pipeline, BookReaderPipeline.extractThenReroute);
    expect(rar?.capability, BookFormatCapability.planned);
    expect(rar?.lightinkNote, contains('unrar'));
  });

  test('Lightink 对照说明已写入关键格式', () {
    expect(
      BookFormatRegistry.specForExtension('txt')?.lightinkNote,
      contains('TxtImporter'),
    );
    expect(
      BookFormatRegistry.specForExtension('epub')?.lightinkNote,
      contains('EpubParser'),
    );
  });
}
