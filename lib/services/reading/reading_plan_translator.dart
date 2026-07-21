// 文件说明：阅读计划任务码翻译器，将 ReadingPlanTask 的码解析为用户可见文案。
// 技术要点：i18n、AppLocalizations。

import 'package:flutter/widgets.dart';

import '../../utils/localization_extension.dart';

/// Translate a reading plan task title code to user-visible text.
///
/// Title codes: `complete_daily_goal`, `complete_focus_reading`,
/// `keep_rhythm`.
String translatePlanTaskTitle(BuildContext context, String titleCode) {
  final l10n = context.l10n;
  switch (titleCode) {
    case 'complete_daily_goal':
      return l10n.homePlanTaskCompleteDailyGoal;
    case 'complete_focus_reading':
      return l10n.homePlanTaskCompleteFocusReading;
    case 'keep_rhythm':
      return l10n.homePlanTaskKeepRhythm;
    default:
      return titleCode;
  }
}

/// Translate a reading plan task detail code (with optional params)
/// to user-visible text.
///
/// Detail codes:
/// - `read_minutes` — requires `params['minutes']` (int)
/// - `focus_session` — requires `params['minutes']` (int)
/// - `week_achieved_days` — no params
String translatePlanTaskDetail(
  BuildContext context,
  String detailCode,
  Map<String, dynamic>? params,
) {
  final l10n = context.l10n;
  params ??= const <String, dynamic>{};
  switch (detailCode) {
    case 'read_minutes':
      return l10n.homePlanTaskReadMinutes(
        (params['minutes'] as num?)?.toInt() ?? 0,
      );
    case 'focus_session':
      return l10n.homePlanTaskFocusSession(
        (params['minutes'] as num?)?.toInt() ?? 0,
      );
    case 'week_achieved_days':
      return l10n.homePlanTaskWeekAchievedDays;
    default:
      return detailCode;
  }
}
