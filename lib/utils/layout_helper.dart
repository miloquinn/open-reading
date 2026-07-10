// 文件说明：响应式布局工具，根据屏幕尺寸判断导航模式与布局类型。
// 技术要点：工具方法、Flutter。

import 'package:flutter/material.dart';

class LayoutHelper {
  // 屏幕尺寸断点
  static const double largeMobileBreakpoint = 414.0; // iPhone Plus/Pro Max等大屏手机
  static const double tabletBreakpoint = 820.0; // 降低断点以支持小尺寸平板(7-8英寸)和折叠屏
  static const double desktopBreakpoint = 1200.0;
  
  // 判断是否为普通手机
  static bool isSmallMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < largeMobileBreakpoint;
  }

  // 判断是否为大屏手机
  static bool isLargeMobile(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= largeMobileBreakpoint && width < tabletBreakpoint;
  }

  // 判断是否为手机（包括大屏手机）
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < tabletBreakpoint;
  }

  // 判断是否为平板
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletBreakpoint && width < desktopBreakpoint;
  }

  // 判断是否为桌面
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }
  
  // 判断是否为宽屏设备（平板或桌面）
  static bool isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }
  
  // 获取屏幕类型
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopBreakpoint) {
      return ScreenType.desktop;
    } else if (width >= tabletBreakpoint) {
      return ScreenType.tablet;
    } else if (width >= largeMobileBreakpoint) {
      return ScreenType.largeMobile;
    } else {
      return ScreenType.mobile;
    }
  }
  
  // 根据屏幕类型返回不同的值
  static T getValue<T>(
    BuildContext context, {
    required T mobile,
    T? largeMobile,
    T? tablet,
    T? desktop,
  }) {
    switch (getScreenType(context)) {
      case ScreenType.desktop:
        return desktop ?? tablet ?? largeMobile ?? mobile;
      case ScreenType.tablet:
        return tablet ?? largeMobile ?? mobile;
      case ScreenType.largeMobile:
        return largeMobile ?? mobile;
      case ScreenType.mobile:
        return mobile;
    }
  }
  
  // 获取响应式边距
  static double getHorizontalPadding(BuildContext context) {
    return getValue(
      context,
      mobile: 16.0,
      largeMobile: 20.0,
      tablet: 32.0,
      desktop: 64.0,
    );
  }
  
  // 获取响应式列数
  static int getColumnCount(BuildContext context, {
    int mobileColumns = 1,
    int? tabletColumns,
    int? desktopColumns,
  }) {
    return getValue(
      context,
      mobile: mobileColumns,
      tablet: tabletColumns ?? mobileColumns * 2,
      desktop: desktopColumns ?? tabletColumns ?? mobileColumns * 3,
    );
  }
  
  // 获取响应式字体大小
  static double getFontSize(
    BuildContext context, {
    required double baseFontSize,
    double? tabletScale,
    double? desktopScale,
  }) {
    final scale = getValue(
      context,
      mobile: 1.0,
      tablet: tabletScale ?? 1.1,
      desktop: desktopScale ?? 1.2,
    );
    return baseFontSize * scale;
  }
  
  // 获取书库网格的纵横比
  static double getBookGridAspectRatio(BuildContext context) {
    return getValue(
      context,
      mobile: 0.7,
      tablet: 0.5,  // 平板封面再高一点
      desktop: 0.8,  // 桌面也相应调整
    );
  }
  
  // 获取书库网格的列数
  static int getBookGridColumns(BuildContext context) {
    return getValue(
      context,
      mobile: 2,
      tablet: 3,    // 平板减为3列，封面更高更接近3:4
      desktop: 5,   // 桌面增加到5列
    );
  }
  
  // 判断是否应该显示双页布局
  static bool shouldShowDoublePage(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    
    // 横屏且宽度足够时显示双页
    return width > height && width >= tabletBreakpoint;
  }
  
  // 获取导航栏类型
  static NavigationType getNavigationType(BuildContext context) {
    if (isDesktop(context) || isTablet(context)) {
      return NavigationType.rail;
    } else {
      return NavigationType.bottom;
    }
  }
}

enum ScreenType {
  mobile,
  largeMobile,
  tablet,
  desktop,
}

enum NavigationType {
  bottom,
  rail,
}
