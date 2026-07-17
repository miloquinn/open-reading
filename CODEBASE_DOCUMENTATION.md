# 开元阅读代码库说明

> 范围：主 Flutter 工程及 Android、iOS、Windows、macOS、Linux、Web 平台壳层
> 目标：提供与当前代码一致的阅读顺序和模块边界。

## 当前主链路

开元阅读的核心阅读入口是 `NativeReaderService`，阅读页面是 `NativeReaderPage`。
书籍内容经本地解析后进入 Flutter 原生排版和分页流程。字号、行距、边距或视口变化会
形成新的布局签名，并通过阅读锚点恢复位置。

```text
首页 / 书库
    ↓
NativeReaderService
    ↓
NativeReaderPage
    ├── 章节解析与懒加载
    ├── TextPainter 精确测量
    ├── 分页与内存缓存
    ├── 图片和富文本块
    └── CanonicalLocator 进度保存
```

## 建议阅读顺序

1. `lib/main.dart`：应用启动与全局服务初始化。
2. `lib/pages/home_shell_page.dart`：主导航和页面装配。
3. `lib/pages/library_page.dart`：本地书库与打开书籍入口。
4. `lib/core/reader/native_reader_service.dart`：阅读路由边界。
5. `lib/pages/native_reader_page.dart`：原生阅读、分页和交互实现。
6. `lib/core/reader/canonical_locator.dart`：稳定阅读定位模型。
7. `lib/services/books/`：导入、数据库、图片、笔记与进度。
8. `lib/reader_core/`：格式解析和统一文档支撑。
9. `lib/book_sources/` 与 `lib/pages/book_sources_page.dart`：开放书源能力。
10. `test/`：通过测试理解模块预期行为。

## 目录职责

### `lib/core/`

放置跨页面共享的核心模型与阅读入口。阅读定位模型把内容位置和屏幕排版位置分开，避免
字号、边距或设备变化后只能依赖旧页码。

### `lib/pages/`

应用页面层，包括首页、书库、原生阅读器、开放书源、统计、设置和用户协议。复杂页面
可通过同目录 `part` 文件拆分，但状态所有权仍保留在主页面。

### `lib/reader_core/`

阅读支撑层，包括格式解析、统一文档模型、块级内容和分页计划。该目录提供可复用能力，
实际阅读交互由原生阅读页面负责。

### `lib/services/books/`

书籍领域服务，处理文件导入、编码识别、元数据、封面与图片、数据库访问、书签、笔记、
分页缓存清理和存储修复。

本地书籍导入采用“来源发现 → 暂存队列 → 顺序导入”结构：

- `book_import_models.dart` 定义来源、所有权、进度阶段和结果；
- `book_import_source_service.dart` 负责多文件、Android SAF、iOS Files 与 iCloud 来源；
- `book_import_service.dart` 每次只导入一本，验证哈希并回滚本次拥有的失败产物；
- `pages/import_book/` 管理页面生命周期内的队列、单书进度和失败重试。

Android 目录只使用 SAF 持久化 URI 权限，不申请广泛存储权限。iOS 的本地
`Documents/books` 原地注册；iCloud `Documents/books` 仅同步书籍文件，导入时再物化到
本地书库。SQLite、阅读进度、书签和笔记不会放入 iCloud Documents。

### `lib/book_sources/`

开放书源协议实现：

- `models/`：已注册书源与协议数据模型；
- `protocol/`：协议常量、发现文档和响应解析；
- `services/`：HTTP 客户端与本地书源注册表。

规范和参考服务独立维护在：
https://github.com/miloquinn/open-reading-source-protocol

### `lib/services/core/`

数据库、缓存、备份、应用设置和全局状态等基础设施。

### `lib/services/ai/` 与 `lib/reader_core/ai/`

可选 AI 能力。负责提供商配置、模型列表、请求参数和阅读场景提示。API 密钥由用户配置，
不得写入仓库。

### `lib/l10n/`

应用本地化资源。以 ARB 文件为真相源，生成的 Dart 文件不应手工修改。

### 平台目录

`android/`、`ios/`、`windows/`、`macos/`、`linux/` 和 `web/` 只承载 Flutter 运行所需的
平台启动、窗口、系统 UI 和插件注册代码。业务和阅读逻辑应优先保留在 `lib/`。

## 开发检查

```bash
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

针对书源协议：

```bash
flutter test test/book_source_protocol_test.dart test/book_source_e2e_test.dart
```

## 代码注释原则

- 注释解释当前实现的原因、约束和边界，不记录已经删除的历史方案。
- 不在注释中写未经验证的性能结论或来源猜测。
- 第三方包名称只在真实依赖、许可和必要 API 上下文中出现。
- 删除功能时同步删除失效文档、平台桥接、构建依赖和资源。
- 生成文件由对应工具更新，不手工添加业务说明。

更新时间：2026-07-17
