import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/models/bookmark.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/open_reading_icons.dart';
import 'package:xxread/widgets/reader_navigation_sheet.dart';

void main() {
  testWidgets('Open Reading current-position icon assets are bundled',
      (tester) async {
    final svg = await rootBundle.load(OpenReadingIconAssets.currentReadingSvg);
    final png = await rootBundle.load(OpenReadingIconAssets.currentReadingPng);

    expect(svg.lengthInBytes, greaterThan(0));
    expect(png.lengthInBytes, greaterThan(0));
  });

  testWidgets('navigation sheet follows the supplied reader palette',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        theme: ThemeData.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 720,
            child: ReaderNavigationSheet(
              palette: ReaderThemes.green,
              chapters: const [
                ReaderNavigationChapter(title: '第一章', index: 0),
              ],
              currentChapterIndex: 0,
              bookmarks: const [],
              onChapterSelected: (_) {},
              onBookmarkSelected: (_) {},
              onBookmarkDeleted: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final themed = tester.widgetList<Theme>(find.byType(Theme)).any(
          (theme) =>
              theme.data.colorScheme.primary == ReaderThemes.green.accent &&
              theme.data.colorScheme.surface == ReaderThemes.green.surface,
        );
    final handle = tester.widget<Container>(
      find.byKey(const ValueKey('reader-navigation-drag-handle')),
    );
    final handleDecoration = handle.decoration! as BoxDecoration;
    final navigationTitle = tester.widget<Text>(find.text('阅读导航'));

    expect(themed, isTrue);
    expect(navigationTitle.style?.color, ReaderThemes.green.text);
    expect(
      handleDecoration.color,
      ReaderThemes.green.secondaryText.withValues(alpha: 0.32),
    );

    await tester.tap(find.text('书签'));
    await tester.pumpAndSettle();
    final emptyBookmarksTitle = tester.widget<Text>(find.text('还没有书签'));
    expect(emptyBookmarksTitle.style?.color, ReaderThemes.green.text);
  });

  testWidgets('navigation sheet catalog marks the current chapter',
      (tester) async {
    // Pixel goldens differ across OS font rasterizers; assert structure instead.
    final fontLoader = FontLoader('SourceHanSansCN')
      ..addFont(rootBundle.load(
        'assets/fonts/app/SourceHanSansCN-Regular.otf',
      ))
      ..addFont(rootBundle.load(
        'assets/fonts/app/SourceHanSansCN-Bold.otf',
      ));
    await fontLoader.load();
    await tester.binding.setSurfaceSize(const Size(430, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        theme: ThemeData(fontFamily: 'SourceHanSansCN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReaderNavigationSheet(
            palette: ReaderThemes.day,
            chapters: List.generate(
              12,
              (index) => ReaderNavigationChapter(
                title: [
                  '序章 远方的灯火',
                  '第一章 清晨的来信',
                  '第二章 穿过旧城区',
                  '第三章 雨夜重逢',
                ][index % 4],
                index: index,
                depth: index == 5 ? 1 : 0,
              ),
            ),
            currentChapterIndex: 3,
            currentAnchorKey: 'chapter-4:96',
            bookmarks: [
              Bookmark(
                id: 1,
                bookId: 1,
                pageNumber: 3,
                anchorKey: 'chapter-4:96',
                chapterIndex: 3,
                chapterTitle: '第三章 雨夜重逢',
                excerpt: '雨水沿着旧屋檐落下，街灯在水面上摇晃。',
              ),
            ],
            onChapterSelected: (_) {},
            onBookmarkSelected: (_) {},
            onBookmarkDeleted: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OpenReadingCurrentIcon), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
    expect(find.text('01'), findsNothing);
    expect(find.text('04'), findsNothing);
    expect(find.text('第三章 雨夜重逢'), findsWidgets);
    expect(find.text('序章 远方的灯火'), findsWidgets);
  });

  testWidgets('navigation sheet collapses nested chapter branches',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReaderNavigationSheet(
            palette: ReaderThemes.day,
            chapters: const [
              ReaderNavigationChapter(title: '第一部', index: 0),
              ReaderNavigationChapter(
                title: '第一章',
                index: 1,
                depth: 1,
              ),
              ReaderNavigationChapter(
                title: '深层小节',
                index: 2,
                depth: 2,
              ),
              ReaderNavigationChapter(
                title: '同级章节',
                index: 3,
                depth: 1,
              ),
              ReaderNavigationChapter(title: '第二部', index: 4),
            ],
            currentChapterIndex: 2,
            bookmarks: const [],
            onChapterSelected: (_) {},
            onBookmarkSelected: (_) {},
            onBookmarkDeleted: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('深层小节'), findsOneWidget);
    expect(find.text('同级章节'), findsOneWidget);
    expect(find.text('01'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('reader-navigation-toggle-0')),
    );
    await tester.pumpAndSettle();

    expect(find.text('第一部'), findsOneWidget);
    expect(find.text('深层小节'), findsNothing);
    expect(find.text('同级章节'), findsNothing);
    expect(find.text('第二部'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('reader-navigation-current-chapter-button'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('深层小节'), findsOneWidget);
    expect(find.text('同级章节'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('reader-navigation-toggle-0')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '深层');
    await tester.pumpAndSettle();

    expect(find.text('第一部'), findsOneWidget);
    expect(find.text('第一章'), findsOneWidget);
    expect(find.text('深层小节'), findsOneWidget);
    expect(find.text('同级章节'), findsNothing);
    expect(find.text('第二部'), findsNothing);
  });

  testWidgets('navigation sheet exposes catalog search and bookmarks',
      (tester) async {
    int? selectedChapter;
    Bookmark? selectedBookmark;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 720,
            child: ReaderNavigationSheet(
              palette: ReaderThemes.day,
              chapters: const [
                ReaderNavigationChapter(title: '第一章 开端', index: 0),
                ReaderNavigationChapter(title: '第二章 远行', index: 1),
                ReaderNavigationChapter(title: '第三章 重逢', index: 2),
              ],
              currentChapterIndex: 1,
              currentAnchorKey: 'chapter-2:64',
              bookmarks: [
                Bookmark(
                  id: 9,
                  bookId: 1,
                  pageNumber: 1,
                  anchorKey: 'chapter-2:64',
                  chapterIndex: 1,
                  chapterTitle: '第二章 远行',
                  excerpt: '山路在晨雾里慢慢显露出来。',
                ),
              ],
              onChapterSelected: (value) => selectedChapter = value,
              onBookmarkSelected: (value) => selectedBookmark = value,
              onBookmarkDeleted: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('阅读导航'), findsOneWidget);
    expect(find.text('当前'), findsNWidgets(2));
    expect(find.text('搜索章节'), findsOneWidget);

    await tester.tap(find.text('第三章 重逢'));
    expect(selectedChapter, 2);

    await tester.tap(find.text('书签'));
    await tester.pumpAndSettle();
    expect(find.text('山路在晨雾里慢慢显露出来。'), findsOneWidget);
    expect(find.text('当前位置'), findsOneWidget);

    await tester.tap(find.text('第二章 远行').last);
    expect(selectedBookmark?.id, 9);
  });
}
