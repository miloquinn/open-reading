import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/home/home_shell_page.dart';
import 'package:xxread/pages/home/widgets/home_mobile_top_bar.dart';
import 'package:xxread/services/core/app_settings_service.dart';
import 'package:xxread/utils/book_open_transition.dart';
import 'package:xxread/utils/ui_style.dart';

void main() {
  testWidgets('mobile home shell leaves the status bar to its custom top bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettingsNotifier(),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6750A4),
            ),
            extensions: const [
              UiStyleThemeExtension(style: AppUiStyle.material3),
            ],
          ),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(412, 915),
              viewPadding: EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: HomeShellPage(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    final topBar = find.byType(HomeMobileTopBar);
    expect(topBar, findsOneWidget);
    expect(tester.getTopLeft(topBar), Offset.zero);
    expect(tester.getSize(topBar).height, 84);
  });

  testWidgets('book route hides and restores the floating navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettingsNotifier(),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6750A4),
            ),
            extensions: const [
              UiStyleThemeExtension(style: AppUiStyle.material3),
            ],
          ),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(412, 915),
              viewPadding: EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: HomeShellPage(),
          ),
        ),
      ),
    );
    await tester.pump();

    const motionKey = ValueKey('home-floating-navigation-motion');
    final motionFinder = find.byKey(motionKey, skipOffstage: false);
    expect(tester.widget<AnimatedSlide>(motionFinder).offset, Offset.zero);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final readerRoute = BookOpenTransition.createRoute<void>(
      const Scaffold(body: Text('reader')),
    );
    expect(BookOpenTransition.hasActiveReaderActivity, isTrue);
    expect(BookOpenTransition.navigationHiddenListenable.value, isTrue);
    navigator.push<void>(readerRoute);
    await tester.pump();

    expect(
      tester.widget<AnimatedSlide>(motionFinder).offset,
      const Offset(0, 1.15),
    );
    expect(
      tester.widget<AnimatedSlide>(motionFinder).curve,
      Curves.easeOutCubic,
    );
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const ValueKey('home-floating-navigation-pointer')),
          )
          .ignoring,
      isTrue,
    );

    await tester.pumpAndSettle();
    BookOpenTransition.beginExit();
    navigator.pop();
    await tester.pump();
    final returningMotion = tester.widget<AnimatedSlide>(motionFinder);
    expect(returningMotion.offset, Offset.zero);
    expect(returningMotion.curve, Curves.easeOutBack);
    expect(returningMotion.duration, const Duration(milliseconds: 360));
    expect(find.text('reader'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(tester.widget<AnimatedSlide>(motionFinder).offset, Offset.zero);
    expect(BookOpenTransition.hasActiveReaderActivity, isFalse);
  });

  testWidgets('reader back gesture inset changes do not move floating nav', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final mediaQuery = ValueNotifier(
      const MediaQueryData(
        size: Size(412, 915),
        viewPadding: EdgeInsets.only(top: 24, bottom: 24),
      ),
    );
    addTearDown(mediaQuery.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettingsNotifier(),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6750A4),
            ),
            extensions: const [
              UiStyleThemeExtension(style: AppUiStyle.material3),
            ],
          ),
          home: ValueListenableBuilder<MediaQueryData>(
            valueListenable: mediaQuery,
            builder: (context, data, child) =>
                MediaQuery(data: data, child: child!),
            child: const HomeShellPage(),
          ),
        ),
      ),
    );
    await tester.pump();

    const motionKey = ValueKey('home-floating-navigation-motion');
    final motionFinder = find.byKey(motionKey, skipOffstage: false);
    expect(tester.getSize(motionFinder).height, 90);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final readerRoute = BookOpenTransition.createRoute<void>(
      const Scaffold(body: Text('reader')),
    );
    navigator.push<void>(readerRoute);
    await tester.pumpAndSettle();
    BookOpenTransition.beginExit();

    mediaQuery.value = const MediaQueryData(
      size: Size(412, 915),
      viewPadding: EdgeInsets.only(bottom: 48),
    );
    await tester.pump();
    expect(tester.getSize(motionFinder).height, 90);

    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(BookOpenTransition.hasActiveReaderActivity, isFalse);

    mediaQuery.value = const MediaQueryData(
      size: Size(412, 915),
      viewPadding: EdgeInsets.only(top: 24, bottom: 32),
    );
    await tester.pump();
    expect(tester.getSize(motionFinder).height, 98);
  });
}
