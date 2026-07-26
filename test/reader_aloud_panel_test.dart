import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_aloud_controller.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/services/reader_aloud_service.dart';
import 'package:xxread/services/tts_service.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_aloud_panel.dart';

void main() {
  testWidgets('audiobook sheet is bounded, draggable, and accepts any timer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final tts = _PanelTtsService();
    final aloud = ReaderAloudService(
      systemEngine: tts,
      settingsStore: _PanelSettingsStore(),
      cloudClient: _PanelCloudClient(),
      bytesPlayer: _PanelBytesPlayer(),
    );
    final controller = ReaderAloudController(
      engine: aloud,
      source: CallbackReaderAloudSource(
        bookTitle: '测试书籍',
        chapterCount: () => 1,
        currentPosition: () async =>
            const ReaderAloudPosition(chapterIndex: 0, offset: 0),
        loadChapter: (_) async => const ReaderAloudChapter(
          index: 0,
          id: 'chapter-1',
          title: '第一章',
          text: '第一句。',
        ),
        revealPosition: (_) async {},
        persistPosition: (_) async {},
      ),
    );
    addTearDown(() async {
      controller.dispose();
      aloud.dispose();
      tts.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showReaderAloudPanelSheet(
                  context: context,
                  controller: controller,
                  ttsService: tts,
                  aloudService: aloud,
                  palette: ReaderThemes.day,
                  themeData: Theme.of(context),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(bottomSheet.enableDrag, isTrue);
    expect(bottomSheet.showDragHandle, isTrue);
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      lessThanOrEqualTo(576),
    );
    expect(
      find.byKey(const ValueKey('reader-aloud-sleep-timer-card')),
      findsOneWidget,
    );
    expect(find.text('15分钟'), findsNothing);
    expect(find.text('30分钟'), findsNothing);
    expect(find.text('60分钟'), findsNothing);

    final speedSlider = tester.widgetList<Slider>(find.byType(Slider)).first;
    speedSlider.onChanged?.call(0.8);
    await tester.pump();
    expect(find.text('0.80×'), findsOneWidget);
    speedSlider.onChangeEnd?.call(0.8);
    await tester.pumpAndSettle();
    expect(tts.speechRate, 0.8);

    final timerCard = find.byKey(
      const ValueKey('reader-aloud-sleep-timer-card'),
    );
    await tester.ensureVisible(timerCard);
    await tester.pumpAndSettle();
    await tester.tap(timerCard);
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoTimerPicker>(
      find.byKey(const ValueKey('reader-aloud-sleep-timer-picker')),
    );
    picker.onTimerDurationChanged(const Duration(hours: 2, minutes: 7));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('reader-aloud-sleep-timer-confirm')),
    );
    await tester.pumpAndSettle();

    expect(controller.sleepDuration, const Duration(hours: 2, minutes: 7));
    expect(find.textContaining('2 小时 7 分钟'), findsOneWidget);
    controller.setSleepTimer(null);

    final sheetRect = tester.getRect(find.byType(BottomSheet));
    await tester.dragFrom(
      Offset(sheetRect.center.dx, sheetRect.top + 12),
      const Offset(0, 520),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });
}

class _PanelTtsService extends TtsService {
  @override
  Future<void> initialize({bool force = false}) async {}

  @override
  Future<void> ensureVoicesLoaded({bool force = false}) async {}

  @override
  bool get isPlaying => false;

  @override
  bool get isPaused => false;

  @override
  int get currentPosition => 0;

  @override
  Future<void> pause() async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

class _PanelSettingsStore implements ReaderAloudCloudSettingsStore {
  @override
  Future<void> clearApiKey() async {}

  @override
  Future<ReaderAloudEngineType> loadEngineType() async =>
      ReaderAloudEngineType.system;

  @override
  Future<ReaderAloudCloudSettings> loadSettings() async =>
      const ReaderAloudCloudSettings();

  @override
  Future<String?> readApiKey() async => null;

  @override
  Future<void> saveEngineType(ReaderAloudEngineType type) async {}

  @override
  Future<void> saveSettings(ReaderAloudCloudSettings settings) async {}

  @override
  Future<void> writeApiKey(String apiKey) async {}
}

class _PanelCloudClient implements ReaderAloudCloudClient {
  @override
  Future<Uint8List> synthesize({
    required ReaderAloudCloudSettings settings,
    required String apiKey,
    required String text,
    required double speed,
  }) async => Uint8List.fromList([1]);
}

class _PanelBytesPlayer extends ChangeNotifier
    implements ReaderAloudBytesPlayer {
  @override
  Duration get duration => Duration.zero;

  @override
  bool get isPaused => false;

  @override
  bool get isPlaying => false;

  @override
  Duration get position => Duration.zero;

  @override
  Future<void> pause() async {}

  @override
  Future<void> play(
    Uint8List bytes, {
    required String mimeType,
    required double volume,
  }) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}
