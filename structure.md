# Open Reading 项目结构

> 最后更新：2026-07-17  
> 当前版本：1.2.0  
> 本文记录稳定的项目结构、模块边界和核心数据结构，不罗列每个实现细节。

## 维护规则

出现以下情况时更新本文：

- 新增、删除或重组核心目录与模块。
- 阅读器、书源、导入、存储等主流程的边界发生变化。
- 数据库版本、核心表、重要模型字段或持久化方案发生变化。
- 新增平台工程或改变跨平台能力边界。

普通样式调整、小型组件和局部修复无需更新。

## 技术栈与平台

- Flutter / Dart 多平台应用。
- 支持 Android、iOS、Windows、macOS、Linux、Web 和 OpenHarmony 工程。
- 本地结构化数据使用 SQLite，移动端通过 `sqflite`，桌面端通过 `sqflite_common_ffi`。
- 轻量设置使用 `SharedPreferences`。
- 在线书源使用 Open Reading Source Protocol，不包含 Legado 兼容层。

## 顶层目录

```text
open-reading/
├─ android/                 Android 原生工程和存储桥接
├─ ios/                     iOS 原生工程和文档存储桥接
├─ linux/ macos/ windows/   桌面平台工程
├─ web/                     Web 平台工程
├─ ohos/                    OpenHarmony 平台工程
├─ assets/                  字体、图标、图片等资源
├─ docs/                    设计、规范、计划和示例文档
├─ lib/                     Flutter 主源码
├─ test/                    单元、组件、回归和 Golden 测试
├─ tool/                    项目辅助脚本
├─ shaders/                 阅读翻页等着色器资源
├─ CHANGELOG.md             面向版本的正式变更记录
├─ structure.md             项目结构与数据结构基线
└─ Log.md                   关键开发流水和决策记录
```

`.dart_tool/`、`build/`、平台生成目录属于构建产物，不是源码结构的一部分。

## lib 目录

```text
lib/
├─ book_sources/
│  ├─ models/               已注册书源等本地模型
│  ├─ protocol/             Open Reading Source Protocol 数据结构与校验
│  └─ services/             书源注册、请求、缓存、书架和阅读进度
├─ core/reader/             阅读器共享核心
├─ data/migration/          SQLite 前向迁移
├─ l10n/                    ARB 与生成的多语言代码
├─ models/                  Book、Bookmark、BookNote 等领域模型
├─ pages/                   页面与页面级控制器
├─ reader_core/             AI 阅读等历史阅读核心能力
├─ services/
│  ├─ ai/                   全局 AI 阅读服务
│  ├─ books/                导入、DAO、封面、图片、修复和文本预处理
│  ├─ core/                 数据库、设置、应用状态、缓存、更新检查与自定义字体存储
│  ├─ library/              书库事件和聚合服务
│  ├─ reading/              阅读统计与阅读计划
│  └─ storage/              平台存储桥接与 Android 文件夹授权
├─ utils/                   主题、字体、玻璃效果、本地化扩展等工具
└─ widgets/                 可复用 UI，包含统一阅读器控制层
```

## 主要页面

- `home_shell_page.dart`：应用主壳和导航入口。
- `library_page.dart`：本地与在线书架。
- `import_book_page.dart`：跨平台书籍导入队列。
- `native_reader_page.dart`：本地 TXT、EPUB 等内容适配器。
- `book_source_reader_page.dart`：在线书源章节内容适配器。
- `book_source_search_page.dart`：在线书源搜索与发现。
- `book_source_management_page.dart`：原生协议书源管理。
- `settings_page.dart`：应用设置、版本与维护入口。
- `custom_fonts_page.dart`：用户字体库的导入、应用、重命名和删除入口。
- `changelog_page.dart`：应用内版本历史。
- `open_source_licenses_page.dart`：应用、历史版本、内置字体及 Flutter/Dart 依赖的许可查看入口。

## 字体架构

- `FontCatalog` 维护 App 字体与阅读字体两套内置语义目录；用户字体作为共享资产同时合并到两套候选列表。
- `AppSettingsNotifier` 分别保存 `app_font_id_v2` 与 `reader_font_id_v2`，同一用户字体可独立用于 App、阅读或两者。
- `CustomFontService` 在原生平台负责 TTF/OTF 校验、SHA-256 去重、运行时 `FontLoader` 注册、清单恢复和文件删除；Web 首版不提供持久化字体导入。
- 用户字体使用 `custom_<hash>` 稳定 ID 和 `OpenReadingCustom_<hash>` 运行时 family，避免同名字体互相覆盖。
- 删除正在使用的用户字体时，App 字体与阅读字体分别恢复各自默认值；阅读字体 ID 仍参与分页布局签名。
- 内置字体的 SIL OFL 1.1 原文保存在 `assets/fonts/licenses/`，通过应用内开源许可页离线展示；用户自行导入的字体仍由用户负责确认授权范围。

## 阅读器架构

本地书籍与在线书源保留不同的内容获取和进度保存适配器，但共用一套阅读 UI 与设置逻辑。

```text
本地文件适配器 ─┐
                ├─ ReaderSettings / ReaderSettingsStore
在线章节适配器 ─┘  ReaderSettingsSheet / ReaderPageModeSheet
                   ReaderChromeOverlay
                   ReaderSafeAreaMetrics
                   ReaderPageMode / ReaderLayoutFingerprint
```

核心文件：

- `core/reader/reader_settings.dart`：统一字号、行高、主题、翻页模式和独立上下边距。
- `core/reader/reader_layout.dart`：翻页模式和分页缓存指纹。
- `core/reader/reader_safe_area.dart`：系统安全区、正文边距和页码位置。
- `core/reader/canonical_locator.dart`：与排版无关的稳定阅读位置。
- `widgets/reader_settings_controls.dart`：完整阅读设置和翻页模式面板。
- `widgets/reader_control_chrome.dart`：统一顶部、底部控制栏和状态层。
- `widgets/reader_navigation_sheet.dart`：目录、书签和定位面板。

支持的翻页模式：

- `verticalScroll`
- `instantPage`
- `horizontalSlide`
- `pageCurl`

## 在线书源结构

协议标识为 `open-reading-source`，当前主版本为 `1.1`。

主要数据对象：

- `BookSourceManifest`：书源身份、API 地址、语言和能力声明。
- `BookSourceBook`：在线书籍元数据。
- `BookSourceChapter`：章节目录项。
- `BookSourceChapterContent`：章节正文，支持纯文本、Markdown 和 HTML。
- `BookSourceSearchPage`：分页搜索结果。
- `BookSourceDiscoveryPage`：可选的发现页分区。

书源服务边界：

- `BookSourceRegistry`：注册和启用状态。
- `BookSourceClient`：协议请求。
- `BookSourceChapterCache`：章节缓存和并发去重。
- `BookSourceShelfService`：在线书籍加入本地书架。
- `BookSourceReadingProgressStore`：在线章节阅读进度。

## 核心数据模型

### Book

`Book` 同时承载本地书籍和加入书架的在线书籍：

- 基础元数据：标题、作者、格式、导入时间、封面。
- 文件数据：`filePath`、编码、修改时间和内容哈希。
- 阅读数据：当前页、总页数、目录和分页缓存。
- 稳定定位：`lastCanonicalLocator`。
- 渲染定位：`lastRenderedLocator`、`layoutSignature`。
- 来源身份：`storageType`、`sourceId`、`sourceBookId`、来源 JSON 和来源定位。

### Bookmark

书签通过 `bookId` 关联书籍，并保存页码、CFI、CanonicalLocator、稳定锚点、章节信息和摘录。

### ReaderSettings

统一保存：

- 字号、行高、水平边距。
- 独立的上边距和下边距。
- 阅读主题。
- 翻页模式。

旧的单一纵向边距仅作为迁移输入，不再作为当前设置模型。

## SQLite 数据结构

- 数据库文件：`xxread_v2.db`
- 当前 schema 版本：17
- 迁移策略：只向前、幂等检查后增加字段。

主要表：

| 表 | 用途 | 关键关系 |
|---|---|---|
| `books` | 书籍元数据、来源身份、缓存和阅读定位 | 主表 |
| `bookmarks` | 书签、章节锚点和摘录 | `bookId -> books.id`，级联删除 |
| `book_notes` | 笔记、高亮和文本范围 | `book_id -> books.id`，级联删除 |
| `reading_stats` | 按日期汇总的阅读时长 | 独立统计 |
| `reading_sessions` | 单次阅读会话、页数和时长 | 可选关联 `bookId` |

`books` 使用 `storage_type` 区分本地与在线书籍，并通过 `source_*` 字段保存可重建的来源信息。

## 持久化边界

- SQLite：书籍、书签、笔记、阅读会话和核心业务数据。
- SharedPreferences：阅读 UI 设置、App/阅读字体选择、应用偏好和轻量状态。
- 应用私有目录：数据库、缓存、封面、应用管理的书籍文件，以及 `custom_fonts/` 下的用户字体和 `manifest.json`。
- 用户授权目录：通过平台存储桥接原地管理或导入书籍。
- 网络：仅在用户使用在线书源、封面、AI、同步或更新检查等功能时访问。

## 测试结构

- `reader_*_test.dart`：阅读设置、分页、安全区、导航和翻页效果。
- `book_source_*_test.dart`：原生书源协议、缓存、搜索、书架和在线阅读。
- `book_import_*_test.dart`：导入模型、迁移、来源和队列。
- `*_page_test.dart`：页面组件回归。
- `test/goldens/`：视觉基准图。
