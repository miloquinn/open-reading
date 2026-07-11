// 文件说明：本地化扩展方法，为 BuildContext 提供便捷的文案访问入口。
// 技术要点：工具方法、Flutter。

import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';

extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
