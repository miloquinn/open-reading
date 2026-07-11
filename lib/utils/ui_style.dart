// 文件说明：应用 UI 风格扩展，定义 Material3 与玻璃态等风格切换。
// 技术要点：工具方法、Flutter。

import 'package:flutter/material.dart';

enum AppUiStyle {
  glass,
  material3,
}

extension AppUiStyleX on AppUiStyle {
  String get storageValue {
    switch (this) {
      case AppUiStyle.glass:
        return 'glass';
      case AppUiStyle.material3:
        return 'material3';
    }
  }
}

AppUiStyle appUiStyleFromStorage(String? value) {
  switch (value) {
    case 'glass':
      return AppUiStyle.glass;
    case 'material3':
    default:
      return AppUiStyle.material3;
  }
}

@immutable
class UiStyleThemeExtension extends ThemeExtension<UiStyleThemeExtension> {
  final AppUiStyle style;

  const UiStyleThemeExtension({required this.style});

  bool get isMaterial3Style => style == AppUiStyle.material3;

  @override
  UiStyleThemeExtension copyWith({AppUiStyle? style}) {
    return UiStyleThemeExtension(style: style ?? this.style);
  }

  @override
  UiStyleThemeExtension lerp(
    covariant ThemeExtension<UiStyleThemeExtension>? other,
    double t,
  ) {
    if (other is! UiStyleThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}
