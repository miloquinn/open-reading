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

  String get displayName {
    switch (this) {
      case AppUiStyle.glass:
        return '毛玻璃';
      case AppUiStyle.material3:
        return 'Material 3';
    }
  }

  String get subtitle {
    switch (this) {
      case AppUiStyle.glass:
        return '半透明、模糊和悬浮层次感';
      case AppUiStyle.material3:
        return '标准 M3 实体化层级，更简洁统一';
    }
  }

  IconData get icon {
    switch (this) {
      case AppUiStyle.glass:
        return Icons.blur_on_rounded;
      case AppUiStyle.material3:
        return Icons.layers_rounded;
    }
  }
}

AppUiStyle appUiStyleFromStorage(String? value) {
  switch (value) {
    case 'material3':
      return AppUiStyle.material3;
    case 'glass':
    default:
      return AppUiStyle.glass;
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
