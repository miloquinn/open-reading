# 小元读书项目索引 (Project.md)

## 核心架构
本项目采用 **Flutter + Foliate (WebView)** 的混合架构，旨在提供高性能、高兼容性的阅读体验。

### 关键目录说明
- **`lib/main.dart`**: 应用启动入口，负责初始化与全局状态注入。
- **`lib/pages/`**: 视图层。
  - `foliate_reader_page.dart`: **当前主阅读器页面**（Foliate 渲染 + Flutter UI 控制）。
  - `home_shell_page.dart`: 主导航页面。
- **`lib/services/`**: 业务服务层。
  - `reading/reading_router_service.dart`: 阅读路由分发中心。
  - `books/book_import_service.dart`: 书籍导入管理。
  - `tts_service.dart`: 语音朗读服务。
- **`lib/reader_core/`**: 阅读支撑层，负责解析、文档转换与共享模型。
  - `parser/`: 书籍解析器（TXT, EPUB, PDF 等）。
  - `document/`: 统一文档模型 (`FlowDoc`)。
- **`assets/foliate-js/`**: 阅读器网页端资源，基于 Foliate-JS 深度定制。

### 工作流索引
- **导入书籍**: `LibraryPage` -> `ImportBookPage` -> `BookImportService`。
- **打开阅读器**: `LibraryPage` -> `ReadingRouterService` -> `FoliateReaderPage`。
- **同步进度**: `FoliateReaderPage` (JS Handler) -> `BookDao` -> `SharedPreferences`。
- **切换主题**: `FoliateReaderPage` (Flutter UI) -> `InAppWebView` (JS Bridge) -> CSS 注入。

---
*更新时间：2026-04-16*
