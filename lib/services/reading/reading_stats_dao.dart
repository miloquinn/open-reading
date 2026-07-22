// 文件说明：阅读统计 DAO，负责阅读时长、页数和趋势数据的统计落库。
// 技术要点：服务层。

import 'dart:math' as math;

import 'package:xxread/services/core/database_service.dart';

class ReadingStatsDao {
  final dbService = DatabaseService();

  Future<void> insertReadingTime(DateTime date, int durationInSeconds) async {
    if (durationInSeconds <= 0) return;
    final db = await dbService.database;
    final dateString = _dateKey(date);
    await _upsertReadingDuration(
      db: db,
      dateString: dateString,
      deltaSeconds: durationInSeconds,
    );
  }

  /// 记录一次真实阅读会话（会自动按跨天拆分并汇总到 daily stats）。
  Future<void> recordReadingSession({
    required DateTime startTime,
    required DateTime endTime,
    int? bookId,
    int pagesRead = 0,
  }) async {
    if (!endTime.isAfter(startTime)) {
      return;
    }
    final durationSeconds = endTime.difference(startTime).inSeconds;
    if (durationSeconds <= 0) {
      return;
    }

    final db = await dbService.database;
    final chunks = _splitSessionByDate(startTime: startTime, endTime: endTime);
    if (chunks.isEmpty) {
      return;
    }

    final totalChunkSeconds = chunks.fold<int>(
      0,
      (sum, chunk) => sum + chunk.durationSeconds,
    );

    var remainingPages = math.max(0, pagesRead);
    var remainingSeconds = totalChunkSeconds;

    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final chunkSeconds = chunk.durationSeconds;
      if (chunkSeconds <= 0) {
        continue;
      }

      var chunkPages = 0;
      if (remainingPages > 0) {
        if (i == chunks.length - 1 || remainingSeconds <= 0) {
          chunkPages = remainingPages;
        } else {
          final ratio = chunkSeconds / totalChunkSeconds;
          chunkPages = (pagesRead * ratio).round().clamp(0, remainingPages);
        }
      }

      await db.insert('reading_sessions', {
        'date': chunk.dateString,
        'bookId': bookId,
        'startTimeMs': chunk.startTime.millisecondsSinceEpoch,
        'endTimeMs': chunk.endTime.millisecondsSinceEpoch,
        'durationInSeconds': chunkSeconds,
        'pagesRead': chunkPages,
      });

      await _upsertReadingDuration(
        db: db,
        dateString: chunk.dateString,
        deltaSeconds: chunkSeconds,
      );

      remainingPages = math.max(0, remainingPages - chunkPages);
      remainingSeconds = math.max(0, remainingSeconds - chunkSeconds);
    }
  }

  Future<Map<String, int>> getSummaryStats() async {
    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekStartKey = _dateKey(weekStart);
    final todayKey = _dateKey(today);
    final durationByDate = await _loadMergedDurationByDate();

    final totalDuration = durationByDate.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final todayDuration = durationByDate[todayKey] ?? 0;
    final weekDuration = durationByDate.entries.fold<int>(0, (sum, entry) {
      if (entry.key.compareTo(weekStartKey) >= 0 &&
          entry.key.compareTo(todayKey) <= 0) {
        return sum + entry.value;
      }
      return sum;
    });

    return {
      'total': totalDuration,
      'today': todayDuration,
      'week': weekDuration,
    };
  }

  Future<List<Map<String, dynamic>>> getWeeklyChartData() async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 6));
    final durationByDate = await _loadMergedDurationByDate(
      startDate: _dateKey(startDate),
      endDate: _dateKey(endDate),
    );
    final chartData = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateString = _dateKey(date);
      final duration = durationByDate[dateString] ?? 0;
      chartData.add({'day': date.weekday, 'duration': duration});
    }
    return chartData;
  }

  Future<Map<String, dynamic>> getAchievementStats() async {
    final db = await dbService.database;
    final today = DateTime.now();
    final durationByDate = await _loadMergedDurationByDate(
      startDate: _dateKey(today.subtract(const Duration(days: 365))),
      endDate: _dateKey(today),
    );

    int consecutiveDays = 0;
    for (int i = 0; i < 365; i++) {
      final date = today.subtract(Duration(days: i));
      if ((durationByDate[_dateKey(date)] ?? 0) > 0) {
        consecutiveDays++;
      } else {
        break;
      }
    }

    final maxSessionResult = await db.rawQuery(
      'SELECT MAX(durationInSeconds) as maxDuration FROM reading_sessions',
    );
    final maxDuration = (maxSessionResult.first['maxDuration'] as int?) ?? 0;

    return {
      'consecutiveDays': consecutiveDays,
      'maxSessionMinutes': (maxDuration / 60).round(),
    };
  }

  /// 最近阅读书籍（真实）：基于 reading_sessions 的最近结束时间排序。
  Future<List<int>> getRecentBookIds({int limit = 5}) async {
    final db = await dbService.database;
    final safeLimit = limit.clamp(1, 50);
    final rows = await db.rawQuery('''
      SELECT bookId, MAX(endTimeMs) AS lastEnd
      FROM reading_sessions
      WHERE bookId IS NOT NULL AND bookId > 0
      GROUP BY bookId
      ORDER BY lastEnd DESC
      LIMIT $safeLimit
      ''');

    final ids = <int>[];
    for (final row in rows) {
      final id = row['bookId'] as int?;
      if (id != null && id > 0) {
        ids.add(id);
      }
    }
    return ids;
  }

  /// 每日统计（真实）：时长来自 reading_stats；页数/当日阅读书籍数来自 reading_sessions。
  Future<List<Map<String, dynamic>>> getDailyStatsRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await dbService.database;
    final startDateStr = _dateKey(startDate);
    final endDateStr = _dateKey(endDate);
    final durationByDate = await _loadMergedDurationByDate(
      startDate: startDateStr,
      endDate: endDateStr,
    );

    final pagesRows = await db.rawQuery(
      '''
      SELECT date, SUM(pagesRead) as totalPages
      FROM reading_sessions
      WHERE date >= ? AND date <= ?
      GROUP BY date
      ''',
      [startDateStr, endDateStr],
    );
    final pagesByDate = <String, int>{
      for (final row in pagesRows)
        row['date'] as String: (row['totalPages'] as int?) ?? 0,
    };

    final booksRows = await db.rawQuery(
      '''
      SELECT date, COUNT(DISTINCT bookId) as booksRead
      FROM reading_sessions
      WHERE date >= ? AND date <= ? AND bookId IS NOT NULL AND bookId > 0
      GROUP BY date
      ''',
      [startDateStr, endDateStr],
    );
    final booksByDate = <String, int>{
      for (final row in booksRows)
        row['date'] as String: (row['booksRead'] as int?) ?? 0,
    };

    final rows = <Map<String, dynamic>>[];
    final totalDays =
        endDate
            .difference(
              DateTime(startDate.year, startDate.month, startDate.day),
            )
            .inDays +
        1;
    for (var i = 0; i < totalDays; i++) {
      final date = DateTime(startDate.year, startDate.month, startDate.day + i);
      final key = _dateKey(date);
      rows.add({
        'date': key,
        'duration': durationByDate[key] ?? 0,
        'pages': pagesByDate[key] ?? 0,
        'books_read': booksByDate[key] ?? 0,
      });
    }
    return rows;
  }

  /// 读取小时分布（真实）：根据会话时间窗口切分到每个小时。
  Future<Map<int, int>> getHourlyReadingDistribution({int days = 30}) async {
    final db = await dbService.database;
    final now = DateTime.now();
    final startWindow = now.subtract(Duration(days: days));
    final startMs = startWindow.millisecondsSinceEpoch;
    final endMs = now.millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      '''
      SELECT startTimeMs, endTimeMs
      FROM reading_sessions
      WHERE endTimeMs > ? AND startTimeMs < ?
      ''',
      [startMs, endMs],
    );

    final hourlyMinutes = <int, double>{for (var h = 0; h < 24; h++) h: 0};

    for (final row in rows) {
      final rawStart = row['startTimeMs'] as int? ?? 0;
      final rawEnd = row['endTimeMs'] as int? ?? 0;
      if (rawEnd <= rawStart) continue;

      var current = DateTime.fromMillisecondsSinceEpoch(rawStart);
      final end = DateTime.fromMillisecondsSinceEpoch(rawEnd);

      if (current.isBefore(startWindow)) {
        current = startWindow;
      }
      var actualEnd = end;
      if (actualEnd.isAfter(now)) {
        actualEnd = now;
      }
      if (!actualEnd.isAfter(current)) {
        continue;
      }

      while (current.isBefore(actualEnd)) {
        final hourBoundary = DateTime(
          current.year,
          current.month,
          current.day,
          current.hour + 1,
        );
        final segmentEnd = hourBoundary.isBefore(actualEnd)
            ? hourBoundary
            : actualEnd;
        final segmentMinutes =
            segmentEnd.difference(current).inSeconds.toDouble() / 60.0;
        hourlyMinutes[current.hour] =
            (hourlyMinutes[current.hour] ?? 0) + segmentMinutes;
        current = segmentEnd;
      }
    }

    return {for (var h = 0; h < 24; h++) h: (hourlyMinutes[h] ?? 0).round()};
  }

  /// 阅读强度热力图（最近91天）- 基于真实 daily duration。
  Future<Map<String, double>> getReadingIntensityHeatmap() async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 91));
    final durationByDate = await _loadMergedDurationByDate(
      startDate: _dateKey(startDate),
      endDate: _dateKey(endDate),
    );
    final dateToMinutes = <String, int>{
      for (final entry in durationByDate.entries) entry.key: entry.value ~/ 60,
    };

    final maxMinutes = dateToMinutes.values.isEmpty
        ? 1
        : dateToMinutes.values.reduce((a, b) => a > b ? a : b);

    final intensityMap = <String, double>{};
    for (int i = 90; i >= 0; i--) {
      final date = endDate.subtract(Duration(days: i));
      final dateStr = _dateKey(date);
      final minutes = dateToMinutes[dateStr] ?? 0;
      intensityMap[dateStr] = maxMinutes > 0 ? minutes / maxMinutes : 0.0;
    }

    return intensityMap;
  }

  /// 每本书的真实阅读统计（来自 reading_sessions）。
  Future<Map<int, Map<String, dynamic>>> getBookReadingStats() async {
    final db = await dbService.database;
    final rows = await db.rawQuery('''
      SELECT
        bookId,
        SUM(durationInSeconds) as totalDurationSeconds,
        SUM(pagesRead) as totalPagesRead,
        COUNT(*) as sessionCount,
        MAX(endTimeMs) as lastReadMs
      FROM reading_sessions
      WHERE bookId IS NOT NULL AND bookId > 0
      GROUP BY bookId
      ''');

    final result = <int, Map<String, dynamic>>{};
    for (final row in rows) {
      final bookId = row['bookId'] as int?;
      if (bookId == null || bookId <= 0) continue;
      final durationSeconds = (row['totalDurationSeconds'] as int?) ?? 0;
      result[bookId] = {
        'durationSeconds': durationSeconds,
        'durationMinutes': (durationSeconds / 60).round(),
        'pagesRead': (row['totalPagesRead'] as int?) ?? 0,
        'sessionCount': (row['sessionCount'] as int?) ?? 0,
        'lastReadMs': (row['lastReadMs'] as int?) ?? 0,
      };
    }
    return result;
  }

  /// 阅读会话概览（真实）。
  Future<Map<String, int>> getSessionSummary({int recentDays = 90}) async {
    final db = await dbService.database;
    final startDate = _dateKey(
      DateTime.now().subtract(Duration(days: recentDays)),
    );
    final rows = await db.rawQuery(
      '''
      SELECT
        COUNT(*) as totalSessions,
        SUM(durationInSeconds) as totalDurationSeconds,
        MAX(durationInSeconds) as maxDurationSeconds
      FROM reading_sessions
      WHERE date >= ?
      ''',
      [startDate],
    );
    final first = rows.isNotEmpty ? rows.first : const <String, Object?>{};
    final totalSessions = (first['totalSessions'] as int?) ?? 0;
    final totalDurationSeconds = (first['totalDurationSeconds'] as int?) ?? 0;
    final maxDurationSeconds = (first['maxDurationSeconds'] as int?) ?? 0;
    final avgMinutes = totalSessions > 0
        ? ((totalDurationSeconds / totalSessions) / 60).round()
        : 0;
    return {
      'totalSessions': totalSessions,
      'totalMinutes': (totalDurationSeconds / 60).round(),
      'avgSessionMinutes': avgMinutes,
      'maxSessionMinutes': (maxDurationSeconds / 60).round(),
    };
  }

  /// 获取某一天的会话次数（可设置最小时长门槛）。
  Future<int> getSessionCountForDay(
    DateTime date, {
    int minDurationSeconds = 0,
  }) async {
    final db = await dbService.database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM reading_sessions
      WHERE date = ? AND durationInSeconds >= ?
      ''',
      [_dateKey(date), minDurationSeconds],
    );
    return (rows.first['count'] as int?) ?? 0;
  }

  /// 最近 N 天的平均单次会话时长（分钟）。
  Future<double> getAverageSessionMinutes({int days = 30}) async {
    final db = await dbService.database;
    final startDate = _dateKey(DateTime.now().subtract(Duration(days: days)));
    final rows = await db.rawQuery(
      '''
      SELECT AVG(durationInSeconds) as avgDurationSeconds
      FROM reading_sessions
      WHERE date >= ? AND durationInSeconds > 0
      ''',
      [startDate],
    );
    final avgSeconds = rows.first['avgDurationSeconds'];
    if (avgSeconds is num && avgSeconds > 0) {
      return avgSeconds / 60.0;
    }
    return 0;
  }

  /// 获取所有阅读统计（用于同步）- 保持兼容旧同步结构。
  Future<List<Map<String, dynamic>>> getAllStats() async {
    final mergedByDate = await _loadMergedDurationByDate();
    final dates = mergedByDate.keys.toList()..sort((a, b) => b.compareTo(a));
    return dates
        .map(
          (date) => <String, dynamic>{
            'date': date,
            'durationInSeconds': mergedByDate[date] ?? 0,
          },
        )
        .toList(growable: false);
  }

  Future<Map<String, int>> _loadMergedDurationByDate({
    String? startDate,
    String? endDate,
  }) async {
    final db = await dbService.database;
    final args = <Object?>[];
    final whereClause = _buildDateRangeClause(
      startDate: startDate,
      endDate: endDate,
      args: args,
    );

    final statsRows = await db.rawQuery('''
      SELECT date, SUM(durationInSeconds) as totalDuration
      FROM reading_stats
      $whereClause
      GROUP BY date
      ''', args);
    final statsByDate = <String, int>{};
    for (final row in statsRows) {
      final date = (row['date'] ?? '').toString();
      if (date.isEmpty) continue;
      final duration = (row['totalDuration'] as num?)?.toInt() ?? 0;
      if (duration <= 0) continue;
      statsByDate[date] = duration;
    }

    final sessionRows = await db.rawQuery('''
      SELECT date, SUM(durationInSeconds) as totalDuration
      FROM reading_sessions
      $whereClause
      GROUP BY date
      ''', args);
    for (final row in sessionRows) {
      final date = (row['date'] ?? '').toString();
      if (date.isEmpty) continue;
      final duration = (row['totalDuration'] as num?)?.toInt() ?? 0;
      if (duration <= 0) continue;
      // 会话明细优先，避免旧的 daily 聚合被重复累加后污染展示。
      statsByDate[date] = duration;
    }

    return statsByDate;
  }

  String _buildDateRangeClause({
    String? startDate,
    String? endDate,
    required List<Object?> args,
  }) {
    final clauses = <String>[];
    if (startDate != null && startDate.isNotEmpty) {
      clauses.add('date >= ?');
      args.add(startDate);
    }
    if (endDate != null && endDate.isNotEmpty) {
      clauses.add('date <= ?');
      args.add(endDate);
    }
    if (clauses.isEmpty) {
      return '';
    }
    return 'WHERE ${clauses.join(' AND ')}';
  }

  Future<void> _upsertReadingDuration({
    required dynamic db,
    required String dateString,
    required int deltaSeconds,
  }) async {
    if (deltaSeconds <= 0) return;
    final existing = await db.query(
      'reading_stats',
      where: 'date = ?',
      whereArgs: [dateString],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final newDuration =
          ((existing.first['durationInSeconds'] as int?) ?? 0) + deltaSeconds;
      await db.update(
        'reading_stats',
        {'durationInSeconds': newDuration},
        where: 'date = ?',
        whereArgs: [dateString],
      );
    } else {
      await db.insert('reading_stats', {
        'date': dateString,
        'durationInSeconds': deltaSeconds,
      });
    }
  }

  List<_SessionChunk> _splitSessionByDate({
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final chunks = <_SessionChunk>[];
    var cursor = startTime;
    while (cursor.isBefore(endTime)) {
      final nextDay = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final chunkEnd = nextDay.isBefore(endTime) ? nextDay : endTime;
      final seconds = chunkEnd.difference(cursor).inSeconds;
      if (seconds > 0) {
        chunks.add(
          _SessionChunk(
            dateString: _dateKey(cursor),
            startTime: cursor,
            endTime: chunkEnd,
            durationSeconds: seconds,
          ),
        );
      }
      cursor = chunkEnd;
    }
    return chunks;
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String().split('T').first;
  }
}

class _SessionChunk {
  final String dateString;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;

  const _SessionChunk({
    required this.dateString,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
  });
}
