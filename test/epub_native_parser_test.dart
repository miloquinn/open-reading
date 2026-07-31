import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:path/path.dart' as path;
import 'package:xxread/services/books/epub_native_parser.dart';

void main() {
  late Directory sandbox;
  late File epubFile;
  late Directory cacheDirectory;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('epub-native-parser-');
    epubFile = File(path.join(sandbox.path, 'fixture.epub'))
      ..writeAsBytesSync(_epubFixture());
    cacheDirectory = Directory(path.join(sandbox.path, 'cache'));
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  test('indexes every spine document and preserves navigation depth', () {
    final index = buildEpubNativeIndex(<String, dynamic>{
      'epubPath': epubFile.path,
      'cacheDirectory': cacheDirectory.path,
      'familyPrefix': 'fixture',
    });

    final chapters = (index['chapters'] as List).cast<Map>();
    expect(chapters, hasLength(2));
    expect(chapters[0]['title'], 'Styled chapter');
    expect(chapters[0]['depth'], 1);
    expect(chapters[0]['archivePath'], 'OEBPS/text/chapter-1.xhtml');
    expect(chapters[1]['title'], 'Part');
    expect(chapters[1]['archivePath'], 'OEBPS/text/chapter-2.xhtml');
    final navigation = (index['navigation'] as List).cast<Map>();
    expect(navigation, <Map>[
      <String, dynamic>{'title': 'Part', 'depth': 0, 'chapterIndex': 1},
      <String, dynamic>{
        'title': 'Styled chapter',
        'depth': 1,
        'chapterIndex': 0,
      },
    ]);

    final cached = readEpubNativeIndex(<String, dynamic>{
      'indexPath': path.join(cacheDirectory.path, 'index.json'),
      'sourceSize': epubFile.lengthSync(),
      'sourceModifiedMillis': epubFile
          .lastModifiedSync()
          .millisecondsSinceEpoch,
    });
    expect(cached?['chapters'], hasLength(2));
    expect(cached?['navigation'], navigation);
  });

  test('keeps text, headings, inline styles, fonts, and exact image paths', () {
    final index = buildEpubNativeIndex(<String, dynamic>{
      'epubPath': epubFile.path,
      'cacheDirectory': cacheDirectory.path,
      'familyPrefix': 'fixture',
    });
    final parsed = loadEpubNativeChapters(<String, dynamic>{
      'epubPath': epubFile.path,
      'cacheDirectory': cacheDirectory.path,
      'familyPrefix': 'fixture',
      'cssPaths': index['cssPaths'],
      'chapters': index['chapters'],
    });
    final chapters = (parsed['chapters'] as List).cast<Map>();
    final first = chapters.first;
    final second = chapters.last;
    final firstBlocks = (first['blocks'] as List).cast<Map>();
    final secondBlocks = (second['blocks'] as List).cast<Map>();

    expect(
      first['plainText'],
      'Major Heading\n\nAlpha italic and bold special.\n\nAfter image.',
    );
    expect(
      second['plainText'],
      'Spine-only tail.\n\nBefore\n\nNested\n\nAfter',
    );
    expect(
      firstBlocks.where((block) => block['type'] == 'text'),
      everyElement(
        predicate<Map>((block) {
          final start = block['startOffset'] as int;
          final end = block['endOffset'] as int;
          return start >= 0 &&
              end >= start &&
              end <= (first['plainText'] as String).length;
        }),
      ),
    );

    final heading = firstBlocks.firstWhere(
      (block) => block['content'] == 'Major Heading',
    );
    final italic = firstBlocks.firstWhere(
      (block) => (block['content'] as String?)?.trim() == 'italic',
      orElse: () => fail('italic run missing: $firstBlocks'),
    );
    final bold = firstBlocks.firstWhere(
      (block) => (block['content'] as String?)?.trim() == 'bold',
      orElse: () => fail('bold run missing: $firstBlocks'),
    );
    final special = firstBlocks.firstWhere(
      (block) => (block['content'] as String?)?.trim() == 'special',
      orElse: () => fail('special run missing: $firstBlocks'),
    );
    expect(heading['fontScale'], greaterThan(1));
    expect(heading['bold'], isTrue);
    expect(italic['italic'], isTrue);
    expect(bold['bold'], isTrue);
    expect(special['fontFamily'], 'epub_fixture_fixture_face');

    final fonts = Map<String, dynamic>.from(parsed['fonts'] as Map);
    expect(fonts.keys, contains('epub_fixture_fixture_face'));
    expect(
      File(fonts['epub_fixture_fixture_face'] as String).readAsBytesSync(),
      <int>[0, 1, 2, 3],
    );

    final firstImage = firstBlocks.firstWhere(
      (block) => block['type'] == 'image',
    );
    final secondImage = secondBlocks.firstWhere(
      (block) => block['type'] == 'image',
    );
    expect(firstImage['resourcePath'], 'OEBPS/images/shared.png');
    expect(secondImage['resourcePath'], 'OEBPS/other/shared.png');
    expect(firstImage['imagePath'], isNot(secondImage['imagePath']));
    expect(File(firstImage['imagePath'] as String).readAsBytesSync(), <int>[
      1,
      2,
      3,
    ]);
    expect(File(secondImage['imagePath'] as String).readAsBytesSync(), <int>[
      4,
      5,
      6,
    ]);
    final percentImage = secondBlocks.firstWhere(
      (block) => block['resourcePath'] == 'OEBPS/images/100%real.png',
    );
    expect(File(percentImage['imagePath'] as String).readAsBytesSync(), <int>[
      7,
      8,
      9,
    ]);
    final invalidUtf8Image = secondBlocks.firstWhere(
      (block) => block['resourcePath'] == 'OEBPS/images/%FF.png',
    );
    expect(
      File(invalidUtf8Image['imagePath'] as String).readAsBytesSync(),
      <int>[10, 11, 12],
    );
  });

  test('reopens parsed chapters from cache without reading the EPUB again', () {
    final index = buildEpubNativeIndex(<String, dynamic>{
      'epubPath': epubFile.path,
      'cacheDirectory': cacheDirectory.path,
      'familyPrefix': 'fixture',
    });
    final arguments = <String, dynamic>{
      'epubPath': epubFile.path,
      'cacheDirectory': cacheDirectory.path,
      'familyPrefix': 'fixture',
      'cssPaths': index['cssPaths'],
      'chapters': index['chapters'],
    };
    final cold = loadEpubNativeChapters(arguments);
    final unavailable = File('${epubFile.path}.unavailable');
    epubFile.renameSync(unavailable.path);

    final warm = loadEpubNativeChapters(arguments);
    expect(warm['chapters'], cold['chapters']);
    expect(warm['fonts'], cold['fonts']);
  });

  test('relocates cached paths after an iOS application container change', () {
    final oldCache = Directory(
      path.join(sandbox.path, 'old-container', 'epub'),
    );
    final index = buildEpubNativeIndex(<String, dynamic>{
      'epubPath': epubFile.path,
      'cacheDirectory': oldCache.path,
      'familyPrefix': 'fixture',
    });
    loadEpubNativeChapters(<String, dynamic>{
      'epubPath': epubFile.path,
      'cacheDirectory': oldCache.path,
      'familyPrefix': 'fixture',
      'cssPaths': index['cssPaths'],
      'chapters': index['chapters'],
    });

    final newCache = Directory(
      path.join(sandbox.path, 'new-container', 'epub'),
    );
    newCache.parent.createSync(recursive: true);
    oldCache.renameSync(newCache.path);
    final unavailable = File('${epubFile.path}.unavailable');
    epubFile.renameSync(unavailable.path);

    final relocated = readEpubNativeIndex(<String, dynamic>{
      'indexPath': path.join(newCache.path, 'index.json'),
      'cacheDirectory': newCache.path,
      'sourceSize': unavailable.lengthSync(),
      'sourceModifiedMillis': unavailable
          .lastModifiedSync()
          .millisecondsSinceEpoch,
    });
    expect(relocated, isNotNull);
    final warm = loadEpubNativeChapters(<String, dynamic>{
      'epubPath': epubFile.path,
      'cacheDirectory': newCache.path,
      'familyPrefix': 'fixture',
      'cssPaths': relocated!['cssPaths'],
      'chapters': relocated['chapters'],
    });

    final cachedChapter = (warm['chapters'] as List).first as Map;
    final imagePath =
        ((cachedChapter['blocks'] as List).cast<Map>()).firstWhere(
              (block) => block['type'] == 'image',
            )['imagePath']
            as String;
    expect(path.isWithin(newCache.path, imagePath), isTrue);
    expect(imagePath, isNot(contains('old-container')));
    final fontPath = (warm['fonts'] as Map).values.first as String;
    expect(path.isWithin(newCache.path, fontPath), isTrue);
    expect(fontPath, isNot(contains('old-container')));
  });

  test('rejects an index after the source fingerprint changes', () {
    buildEpubNativeIndex(<String, dynamic>{
      'epubPath': epubFile.path,
      'cacheDirectory': cacheDirectory.path,
      'familyPrefix': 'fixture',
    });

    final stale = readEpubNativeIndex(<String, dynamic>{
      'indexPath': path.join(cacheDirectory.path, 'index.json'),
      'sourceSize': epubFile.lengthSync() + 1,
      'sourceModifiedMillis': epubFile
          .lastModifiedSync()
          .millisecondsSinceEpoch,
    });

    expect(stale, isNull);
  });

  test('extracts metadata without materializing every EPUB resource', () async {
    final metadata = extractEpubNativeMetadata(<String, dynamic>{
      'epubPath': epubFile.path,
    });

    expect(metadata['title'], 'Native parser fixture');
    expect(metadata['author'], 'Fixture Author');
    expect(metadata['description'], 'Fixture description');
    expect(metadata['language'], 'en');
    expect(metadata['publisher'], 'Fixture Publisher');
    expect(metadata['isbn'], '9780000000001');
    expect((metadata['additionalInfo'] as Map)['chapterCount'], 2);
    expect(metadata['coverImage'], Uint8List.fromList(<int>[1, 2, 3]));
    expect(metadata['estimatedPages'], greaterThan(0));
  });

  test('supports EPUB 3 navigation and manifest fallback without a spine', () {
    epubFile.writeAsBytesSync(_epub3FixtureWithoutSpine());

    final index = buildEpubNativeIndex(<String, dynamic>{
      'epubPath': epubFile.path,
      'cacheDirectory': cacheDirectory.path,
      'familyPrefix': 'epub3',
    });
    final descriptors = (index['chapters'] as List).cast<Map>();
    expect(descriptors, hasLength(2));
    expect(descriptors[0]['title'], 'Top level');
    expect(descriptors[0]['depth'], 0);
    expect(descriptors[1]['title'], 'Nested chapter');
    expect(descriptors[1]['depth'], 1);
    expect(index['navigation'], <Map>[
      <String, dynamic>{'title': 'Top level', 'depth': 0, 'chapterIndex': 0},
      <String, dynamic>{
        'title': 'Nested chapter',
        'depth': 1,
        'chapterIndex': 1,
      },
    ]);

    final parsed = loadEpubNativeChapters(<String, dynamic>{
      'epubPath': epubFile.path,
      'cacheDirectory': cacheDirectory.path,
      'familyPrefix': 'epub3',
      'cssPaths': index['cssPaths'],
      'chapters': descriptors,
    });
    final chapters = (parsed['chapters'] as List).cast<Map>();
    expect(chapters[0]['plainText'], 'UTF-16 内容完整。');
    expect(chapters[1]['plainText'], 'GBK 章节不应丢字。');
  });
}

List<int> _epub3FixtureWithoutSpine() {
  final archive = Archive();
  void addText(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  void addBytes(String name, List<int> bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  List<int> utf16Le(String value) {
    final result = <int>[0xff, 0xfe];
    for (final codeUnit in value.codeUnits) {
      result
        ..add(codeUnit & 0xff)
        ..add(codeUnit >> 8);
    }
    return result;
  }

  addText('mimetype', 'application/epub+zip');
  addText('META-INF/container.xml', '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="EPUB/package.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');
  addText('EPUB/package.opf', '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>EPUB 3 fixture</dc:title></metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="one" href="text/one.xhtml" media-type="application/xhtml+xml"/>
    <item id="two" href="text/two.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
</package>''');
  addText(
    'EPUB/nav.xhtml',
    '''<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<body><nav epub:type="toc"><ol>
  <li><a href="text/one.xhtml">Top level</a><ol>
    <li><a href="text/two.xhtml#start">Nested chapter</a></li>
  </ol></li>
</ol></nav></body></html>''',
  );
  addBytes(
    'EPUB/text/one.xhtml',
    utf16Le('<html><body><p>UTF-16 内容完整。</p></body></html>'),
  );
  addBytes(
    'EPUB/text/two.xhtml',
    gbk_bytes.encode(
      '<html><head><meta charset="gbk"></head>'
      '<body><p>GBK 章节不应丢字。</p></body></html>',
    ),
  );
  return ZipEncoder().encode(archive)!;
}

List<int> _epubFixture() {
  final archive = Archive();
  void addText(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  void addBytes(String name, List<int> bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  addText('mimetype', 'application/epub+zip');
  addText('META-INF/container.xml', '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');
  addText('OEBPS/content.opf', '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" xmlns:opf="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="book-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">native-parser-fixture</dc:identifier>
    <dc:identifier opf:scheme="ISBN">9780000000001</dc:identifier>
    <dc:title>Native parser fixture</dc:title>
    <dc:creator>Fixture Author</dc:creator>
    <dc:description>Fixture description</dc:description>
    <dc:publisher>Fixture Publisher</dc:publisher>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="css" href="styles/book.css" media-type="text/css"/>
    <item id="font" href="fonts/fixture.ttf" media-type="font/truetype"/>
    <item id="image-a" href="images/shared.png" media-type="image/png" properties="cover-image"/>
    <item id="image-b" href="other/shared.png" media-type="image/png"/>
    <item id="image-percent" href="images/100%real.png" media-type="image/png"/>
    <item id="image-invalid" href="images/%FF.png" media-type="image/png"/>
    <item id="c1" href="text/chapter-1.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2" href="text/chapter-2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx"><itemref idref="c1"/><itemref idref="c2"/></spine>
</package>''');
  addText('OEBPS/toc.ncx', '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="native-parser-fixture"/></head>
  <docTitle><text>Native parser fixture</text></docTitle>
  <navMap><navPoint id="n1"><navLabel><text>Part</text></navLabel><content src="text/chapter-2.xhtml"/>
    <navPoint id="n2"><navLabel><text>Styled chapter</text></navLabel><content src="text/chapter-1.xhtml"/></navPoint>
  </navPoint></navMap>
</ncx>''');
  addText('OEBPS/styles/book.css', '''
@font-face { font-family: "Fixture Face"; src: url("../fonts/fixture.ttf"); }
body { font-family: serif; }
.special { font-family: "Fixture Face"; }
em { font-style: italic; }
strong { font-weight: 700; }
''');
  addText(
    'OEBPS/text/chapter-1.xhtml',
    '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>One</title></head><body>
<h2>Major <span>Heading</span></h2>
<p>Alpha <em>italic</em> and <strong>bold</strong> <span class="special">special</span>.</p>
<img src="../images/shared.png"/><p>After image.</p>
</body></html>''',
  );
  addText(
    'OEBPS/text/chapter-2.xhtml',
    '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><body>
<p>Spine-only tail.</p><img src="../other/shared.png"/>
<img src="../images/100%real.png"/>
<img src="../images/%FF.png"/>
<div>Before<p>Nested</p>After</div>
</body></html>''',
  );
  addBytes('OEBPS/fonts/fixture.ttf', <int>[0, 1, 2, 3]);
  addBytes('OEBPS/images/shared.png', <int>[1, 2, 3]);
  addBytes('OEBPS/other/shared.png', <int>[4, 5, 6]);
  addBytes('OEBPS/images/100%real.png', <int>[7, 8, 9]);
  addBytes('OEBPS/images/%FF.png', <int>[10, 11, 12]);
  return ZipEncoder().encode(archive)!;
}
