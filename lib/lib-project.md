# lib/ 结构总览

> 更新：2026-04-03
> 说明：这是 `lib/` 的快速入口版索引，详细逐文件说明请看 `../CODEBASE_DOCUMENTATION.md`。

## 快速入口

- `lib/main.dart`：应用启动入口
- `lib/pages/home_shell_page.dart`：首页导航壳层
- `lib/services/books/book_import_service.dart`：导入总入口
- `lib/pages/native_reader_page.dart`：当前 Flutter 原生阅读页面
- `lib/reader_core/`：阅读支撑实现（解析、文档模型与共享数据结构）
- `lib/services/pagination/`：旧分页链路
- `lib/services/sync/webdav_sync_service.dart`：同步主入口

## 本次整理结果

- 统一以当前工作区中的 `OpenReading/` 为主工程真相源。
- 删除 9 个无引用叶子文件，减少阅读噪音。
- 为可维护的 Dart 源码补齐文件头简介，方便直接从文件顶部理解职责。
- 把 `lib/` 内文件重新按“入口/页面/阅读内核/服务/工具/组件”分类。

## 重点提醒

- 当前线上默认阅读链路偏向 `WebReaderPage`，不是旧文档里提到的 `reader_page.dart`。
- `reader_core/` 是后续理解 TXT 新平台和统一文档模型时最重要的目录。
- `services/pagination/` 和 `reader_core/` 同时存在，代表项目仍处于解析支撑层与旧分页链路并存阶段。
- `l10n/app_localizations*.dart` 是生成文件，只需要知道用途，不建议手改。
