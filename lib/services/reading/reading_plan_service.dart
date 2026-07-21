// 文件说明：阅读计划服务，计算今日计划、推荐书籍和进度快照。
// 技术要点：服务层、SharedPreferences。

import 'package:shared_preferences/shared_preferences.dart';

import '../books/book_dao.dart';
import 'reading_stats_dao.dart';

class ReadingPlanTask {
  final String title;
  final String detail;
  final Map<String, dynamic>? detailParams;
  final bool completed;

  const ReadingPlanTask({
    required this.title,
    required this.detail,
    this.detailParams,
    required this.completed,
  });
}

class ReadingPlanSnapshot {
  final int dailyGoalMinutes;
  final int todayReadMinutes;
  final int weekReadMinutes;
  final int remainingMinutes;
  final double completionRate;
  final bool isGoalCompleted;
  final int streakDays;
  final int weekAchievedDays;
  final int focusSessionsToday;
  final int suggestedSessionsToFinish;
  final int completedTasks;
  final int totalTasks;
  final int? recommendedBookId;
  final List<ReadingPlanTask> tasks;

  const ReadingPlanSnapshot({
    required this.dailyGoalMinutes,
    required this.todayReadMinutes,
    required this.weekReadMinutes,
    required this.remainingMinutes,
    required this.completionRate,
    required this.isGoalCompleted,
    required this.streakDays,
    required this.weekAchievedDays,
    required this.focusSessionsToday,
    required this.suggestedSessionsToFinish,
    required this.completedTasks,
    required this.totalTasks,
    required this.recommendedBookId,
    required this.tasks,
  });
}

/// 阅读计划服务
///
/// 目标：
/// 1) 把“阅读计划”从静态文案升级为真实数据驱动。
/// 2) 提供每日目标、连击天数、周达标、专注会话等计划指标。
class ReadingPlanService {
  static final ReadingPlanService _instance = ReadingPlanService._internal();
  factory ReadingPlanService() => _instance;
  ReadingPlanService._internal();

  static const String _dailyGoalKey = 'reading_plan_daily_goal_minutes';
  static const int _defaultDailyGoalMinutes = 30;
  static const int _minDailyGoalMinutes = 10;
  static const int _maxDailyGoalMinutes = 240;
  static const int _focusSessionMinutes = 25;

  final ReadingStatsDao _statsDao = ReadingStatsDao();
  final BookDao _bookDao = BookDao();

  Future<int> getDailyGoalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_dailyGoalKey) ?? _defaultDailyGoalMinutes;
    return raw.clamp(_minDailyGoalMinutes, _maxDailyGoalMinutes);
  }

  Future<void> setDailyGoalMinutes(int minutes) async {
    final value = minutes.clamp(_minDailyGoalMinutes, _maxDailyGoalMinutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyGoalKey, value);
  }

  Future<ReadingPlanSnapshot> loadSnapshot({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final summary = await _statsDao.getSummaryStats();
    final dailyGoalMinutes = await getDailyGoalMinutes();

    final todayReadMinutes = ((summary['today'] ?? 0) / 60).floor();
    final weekReadMinutes = ((summary['week'] ?? 0) / 60).floor();
    final remainingMinutes = (dailyGoalMinutes - todayReadMinutes).clamp(
      0,
      dailyGoalMinutes,
    );
    final completionRate =
        (todayReadMinutes / dailyGoalMinutes).clamp(0.0, 1.0);
    final isGoalCompleted = todayReadMinutes >= dailyGoalMinutes;

    final focusSessionsToday = await _statsDao.getSessionCountForDay(
      current,
      minDurationSeconds: _focusSessionMinutes * 60,
    );
    final avgSessionMinutes =
        await _statsDao.getAverageSessionMinutes(days: 21);
    final suggestedSessionsToFinish = remainingMinutes <= 0
        ? 0
        : ((remainingMinutes /
                    (avgSessionMinutes <= 0
                        ? _focusSessionMinutes
                        : avgSessionMinutes))
                .ceil())
            .clamp(1, 8);

    final streakDays = await _calculateStreakDays(
      now: current,
      goalMinutes: dailyGoalMinutes,
    );
    final weekAchievedDays = await _calculateWeekAchievedDays(
      now: current,
      goalMinutes: dailyGoalMinutes,
    );
    final recommendedBookId = await _resolveRecommendedBookId();

    final tasks = <ReadingPlanTask>[
      ReadingPlanTask(
        title: 'complete_daily_goal',
        detail: 'read_minutes',
        detailParams: {'minutes': dailyGoalMinutes},
        completed: isGoalCompleted,
      ),
      ReadingPlanTask(
        title: 'complete_focus_reading',
        detail: 'focus_session',
        detailParams: {'minutes': _focusSessionMinutes},
        completed: focusSessionsToday > 0,
      ),
      ReadingPlanTask(
        title: 'keep_rhythm',
        detail: 'week_achieved_days',
        completed: weekAchievedDays >= 5,
      ),
    ];
    final completedTasks = tasks.where((task) => task.completed).length;

    return ReadingPlanSnapshot(
      dailyGoalMinutes: dailyGoalMinutes,
      todayReadMinutes: todayReadMinutes,
      weekReadMinutes: weekReadMinutes,
      remainingMinutes: remainingMinutes,
      completionRate: completionRate,
      isGoalCompleted: isGoalCompleted,
      streakDays: streakDays,
      weekAchievedDays: weekAchievedDays,
      focusSessionsToday: focusSessionsToday,
      suggestedSessionsToFinish: suggestedSessionsToFinish,
      completedTasks: completedTasks,
      totalTasks: tasks.length,
      recommendedBookId: recommendedBookId,
      tasks: tasks,
    );
  }

  Future<int> _calculateStreakDays({
    required DateTime now,
    required int goalMinutes,
  }) async {
    final normalizedToday = DateTime(now.year, now.month, now.day);
    final start = normalizedToday.subtract(const Duration(days: 59));
    final rows = await _statsDao.getDailyStatsRange(start, normalizedToday);
    final dailyMinutes = <String, int>{};
    for (final item in rows) {
      final date = item['date']?.toString();
      if (date == null || date.isEmpty) continue;
      final durationSeconds = (item['duration'] as int?) ?? 0;
      dailyMinutes[date] = (durationSeconds / 60).floor();
    }

    var streak = 0;
    for (var i = 0; i < 60; i++) {
      final date = normalizedToday.subtract(Duration(days: i));
      final key = _dateKey(date);
      final minutes = dailyMinutes[key] ?? 0;
      if (minutes >= goalMinutes) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  Future<int> _calculateWeekAchievedDays({
    required DateTime now,
    required int goalMinutes,
  }) async {
    final normalizedToday = DateTime(now.year, now.month, now.day);
    final weekStart =
        normalizedToday.subtract(Duration(days: normalizedToday.weekday - 1));
    final rows = await _statsDao.getDailyStatsRange(weekStart, normalizedToday);

    var achievedDays = 0;
    for (final item in rows) {
      final durationSeconds = (item['duration'] as int?) ?? 0;
      final minutes = (durationSeconds / 60).floor();
      if (minutes >= goalMinutes) {
        achievedDays++;
      }
    }
    return achievedDays;
  }

  Future<int?> _resolveRecommendedBookId() async {
    final recentIds = await _statsDao.getRecentBookIds(limit: 5);
    for (final id in recentIds) {
      final book = await _bookDao.getBookById(id);
      if (book != null) {
        return id;
      }
    }

    final books = await _bookDao.getAllBooks();
    if (books.isEmpty) {
      return null;
    }

    // 优先推荐仍在读的书籍；若没有则使用最近导入的一本。
    final inProgress = books
        .where(
            (book) => book.totalPages > 0 && book.currentPage < book.totalPages)
        .toList();
    if (inProgress.isNotEmpty) {
      inProgress.sort((a, b) => b.importDate.compareTo(a.importDate));
      return inProgress.first.id;
    }

    books.sort((a, b) => b.importDate.compareTo(a.importDate));
    return books.first.id;
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String().split('T').first;
  }
}
