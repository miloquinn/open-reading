// 文件说明：阅读恢复服务的单元测试，覆盖会话记录、关闭清除与启动消费语义。
// 技术要点：SharedPreferences mock。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/services/reading/reading_resume_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('markReading records the session and markClosed clears it', () async {
    SharedPreferences.setMockInitialValues({'autoResumeReadingOnLaunch': true});
    await ReadingResumeService.markReading(42);
    expect(await ReadingResumeService.takePendingResumeBookId(), 42);

    await ReadingResumeService.markReading(42);
    await ReadingResumeService.markClosed(42);
    expect(await ReadingResumeService.takePendingResumeBookId(), isNull);
  });

  test('markReading ignores books without a library id', () async {
    SharedPreferences.setMockInitialValues({'autoResumeReadingOnLaunch': true});
    await ReadingResumeService.markReading(null);
    expect(await ReadingResumeService.takePendingResumeBookId(), isNull);
  });

  test('markClosed keeps a session recorded by another reader', () async {
    SharedPreferences.setMockInitialValues({'autoResumeReadingOnLaunch': true});
    await ReadingResumeService.markReading(7);
    await ReadingResumeService.markClosed(8);
    expect(await ReadingResumeService.takePendingResumeBookId(), 7);
  });

  test('take returns null when the switch is off but still consumes', () async {
    SharedPreferences.setMockInitialValues({'activeReadingSessionBookId': 7});
    expect(await ReadingResumeService.takePendingResumeBookId(), isNull);

    // 记录已被消费：即使随后打开开关，也不会用陈旧会话触发恢复。
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(ReadingResumeService.enabledPreferenceKey, true);
    expect(await ReadingResumeService.takePendingResumeBookId(), isNull);
  });

  test('take consumes the session exactly once when enabled', () async {
    SharedPreferences.setMockInitialValues({
      'autoResumeReadingOnLaunch': true,
      'activeReadingSessionBookId': 9,
    });
    expect(await ReadingResumeService.takePendingResumeBookId(), 9);
    expect(await ReadingResumeService.takePendingResumeBookId(), isNull);
  });
}
