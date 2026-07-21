import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/services/books/cover_generator_service.dart';
import 'package:xxread/widgets/generated_book_cover.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('same title and author produce the same cover across formats',
      (tester) async {
    await tester.runAsync(() async {
      final txt = await CoverGenerator.generateTextCover(
        title: '远方的灯',
        author: '林舟',
        format: 'TXT',
      );
      final source = await CoverGenerator.generateTextCover(
        title: '远方的灯',
        author: '林舟',
        format: 'SOURCE',
      );
      final differentAuthor = await CoverGenerator.generateTextCover(
        title: '远方的灯',
        author: '另一位作者',
        format: 'TXT',
      );

      expect(source, orderedEquals(txt));
      expect(differentAuthor, isNot(orderedEquals(txt)));
    });
  });

  test('palette selection is deterministic', () {
    final first = GeneratedBookCoverPalette.resolve('远方的灯', '林舟');
    final repeated = GeneratedBookCoverPalette.resolve('远方的灯', '林舟');

    expect(identical(first, repeated), isTrue);
  });

  testWidgets('generated cover exposes book metadata and uses shared painter',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SizedBox(
          width: 200,
          height: 300,
          child: GeneratedBookCover(title: '远方的灯', author: '林舟'),
        ),
      ),
    );

    expect(find.byType(GeneratedBookCover), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(
      tester.getSemantics(find.byType(GeneratedBookCover)),
      matchesSemantics(label: '远方的灯，林舟', isImage: true),
    );
  });
}
