# 开元阅读项目索引

## 核心架构

开元阅读采用 Flutter 原生界面与自研阅读引擎。核心阅读链路在 Flutter 渲染体系内完成
章节解析、文本测量、分页、图片混排、阅读定位与交互，不依赖网页容器。

## 关键目录

- `lib/main.dart`：应用启动、全局初始化与依赖装配。
- `lib/pages/native_reader_page.dart`：原生阅读页面、分页和阅读交互。
- `lib/core/reader/native_reader_service.dart`：统一打开本地书籍的阅读入口。
- `lib/core/reader/canonical_locator.dart`：跨排版阅读位置模型。
- `lib/reader_core/`：文档解析、统一文档模型与分页支撑。
- `lib/services/books/`：书籍导入、存储、图片、笔记与进度服务。
- `lib/book_sources/`：开放书源协议模型、客户端与本地注册表。
- `lib/pages/`：首页、书库、书源、设置及其他应用页面。
- `test/`：单元测试和端到端测试。

## 主要工作流

- 导入书籍：`ImportBookPage` → `BookImportService` → 本地数据库与文件存储。
- 打开书籍：书库或首页 → `NativeReaderService` → `NativeReaderPage`。
- 原生分页：章节内容 → 样式构建 → `TextPainter` 测量 → 页面计划与缓存。
- 保存进度：字符偏移阅读锚点 → `CanonicalLocator` → `BookDao`。
- 开放书源：发现文档 → 协议校验 → 聚合搜索 → 书籍与章节接口。

## 设计原则

- 本地优先：书籍、进度和笔记默认保存在用户设备。
- 原生阅读：核心排版、分页和交互由 Flutter 代码实现。
- 稳定定位：排版变化后通过字符偏移和章节标识恢复阅读位置。
- 明确边界：联网书源与 AI 功能均由用户主动配置。
- 可验证：协议、解析和关键状态逻辑由自动化测试覆盖。

更新时间：2026-07-11
