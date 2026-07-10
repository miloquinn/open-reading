// 文件说明：阅读路由服务，按书籍格式打开当前主阅读页面。
// 技术要点：服务层、Flutter。

import 'package:flutter/material.dart';
import 'package:xxread/core/reader/foliate_reader_service.dart';
import 'package:xxread/models/book.dart';

/// 阅读器路由服务（委托 FoliateReaderService 统一走 WebView 阅读线路）
class ReadingRouterService {
  /// 打开书籍——委托 FoliateReaderService.openBook 处理全部路由逻辑。
  static Future<void> openBook(BuildContext context, Book book) async {
    await FoliateReaderService.openBook(context, book);
  }
}
