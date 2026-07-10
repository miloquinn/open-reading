// 文件说明：首页响应式布局常量文件，统一定义间距、断点和尺寸策略。
// 技术要点：Flutter UI。

/// 首页布局公共常量。
///
/// 目的：
/// 1) 避免魔法数字散落在多个页面文件
/// 2) 让 HomeShell 与移动端首页内容页共享同一套尺寸基准
/// 3) 后续改动时只改这一处
const double kHomeMobileTopBarHeight = 76.0;
const double kHomeMobileFloatingNavHeight = 68.0;
const double kHomeMobileFloatingNavBottomGap = 25.0;
const double kHomeMobileSafeBottomMax = 50.0;
const double kHomeMobileContentBottomExtra = 12.0;
