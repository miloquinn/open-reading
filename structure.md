# Open Reading 项目结构

> 最后更新：2026-07-22
> 当前版本：2.2.8
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
- 应用图标以 `ios/Runner/AppIcon.icon` 的 Icon Composer 分层工程为 iOS 原生源；`assets/images/app_icon*.png` 提供 Flutter、Android 与桌面回退，Windows runner 使用多尺寸 ICO，Linux runner 从打包后的 Flutter assets 加载窗口图标。
- 本地结构化数据使用 SQLite，移动端通过 `sqflite`，桌面端通过 `sqflite_common_ffi`。
- 轻量设置使用 `SharedPreferences`。
- 在线书源使用 Open Reading Source Protocol，不包含 Legado 兼容层。
- 官网、发行 API、安装包镜像和下载统计已拆分到独立仓库 `miloquinn/open-reading-web`；本仓库只保留客户端集成和发布后的官网下载校验工具。

## 顶层目录

```text
open-reading/
├─ android/                 Android 原生工程、存储与更新安装桥接
├─ ios/                     iOS 原生工程和文档存储桥接
├─ linux/ macos/ windows/   桌面平台工程
├─ web/                     Web 平台工程
├─ ohos/                    OpenHarmony 平台工程
├─ assets/                  字体、图标、图片等资源
├─ marketing/app-store/     原始商店截图、1242×2688 宣传图与素材说明
├─ docs/                    设计、规范、计划和示例文档
├─ .github/workflows/       日常验证、跨平台构建和发布自动化
├─ lib/                     Flutter 主源码
├─ test/                    单元、组件、回归和 Golden 测试
├─ tool/                    项目辅助脚本与官网下载校验工具
├─ shaders/                 阅读翻页等着色器资源
├─ CHANGELOG.md             面向版本的正式变更记录
├─ structure.md             项目结构与数据结构基线
└─ Log.md                   关键开发流水和决策记录
```

`.dart_tool/`、`build/`、平台生成目录属于构建产物，不是源码结构的一部分。

## 持续集成与发布

- `.github/workflows/pr-checks.yml`：对 Pull Request、`main` 推送和手动运行执行锁定依赖解析、国际化生成一致性、格式检查、静态分析、带覆盖率测试，以及 Android debug 和 Web release 冒烟构建；官网服务使用独立 Python 3.12 job 执行 Ruff 和 Pytest；Pull Request 额外执行依赖安全审查。Web 构建当前为提示性检查，不阻塞合并。
- `.github/workflows/platform-smoke.yml`：在相关源码或平台工程变更、每周计划任务和手动运行时，构建 Linux、Windows、macOS release 以及不签名的 iOS release，用于尽早发现平台工程漂移。OpenHarmony 仍依赖专用 SDK，不在 GitHub 托管运行器中构建。
- `.github/workflows/release.yml`：所有版本 Tag 共用同一发布并发锁；Tag 发布前验证客户端与官网服务，并在写入 GitHub Latest 前拒绝低于或等于当前 Latest 的其他 Tag，同 Tag 重跑保持幂等。随后构建 Android、Windows、Linux 发布包、校验 Android 签名、生成校验和并发布 GitHub Release；发布成功后重新校验全部资产、读取 split APK 实际版本码，再通过固定 `known_hosts` 和受控导入 wrapper 原子镜像到官网。
- GitHub `release` Environment 同时保护 Android 签名 job 和官网镜像 job，并应配置 required reviewers。Android 签名 Secrets 与 `OFFICIAL_SITE_SSH_HOST`、`OFFICIAL_SITE_SSH_PORT`、`OFFICIAL_SITE_SSH_USER`、`OFFICIAL_SITE_SSH_PRIVATE_KEY`、`OFFICIAL_SITE_SSH_KNOWN_HOSTS` 均只保存在该 Environment，不保留仓库级副本。
- `pubspec.lock` 纳入版本控制，CI 和发布流程均使用 `--enforce-lockfile` 保证依赖解析可复现。

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
├─ pages/                   按功能域组织的页面与页面级控制器
│  ├─ home/                 首页壳层、仪表盘、parts 与 widgets
│  ├─ library/              书库、下载任务与 import_book 导入流程
│  ├─ book_sources/         书源发现、搜索、管理与业务 widgets
│  ├─ reader/               本地/书源阅读器与 themes
│  ├─ reading_stats/        阅读统计页与 parts
│  ├─ settings/             设置、字体、parts 与 about 页面
│  └─ legal/                协议等法律页面
├─ reader_core/             AI 阅读等历史阅读核心能力
├─ services/
│  ├─ ai/                   全局 AI 阅读服务
│  ├─ books/                导入、格式注册表、DAO、封面、图片、修复和文本预处理
│  ├─ core/                 数据库、设置、应用状态、缓存、更新、后台下载通知与自定义字体存储
│  ├─ library/              书库事件、聚合服务和下载任务队列
│  ├─ reading/              阅读统计与阅读计划
│  └─ storage/              平台存储桥接与 Android 文件夹授权
├─ utils/                   主题、字体、玻璃效果、本地化扩展等工具
└─ widgets/                 可复用 UI，包含统一阅读器控制层
```

页面目录命名规则：

- 路由页面使用 `<feature>_<purpose>_page.dart`，控制器使用 `*_controller.dart`。
- 同主题的多组件文件使用 `*_widgets.dart`；单组件文件直接使用组件语义名，不追加多余的 `_widget`。
- 私有拆分文件统一放在所属功能域的 `parts/`，并以 `*_part.dart` 结尾。
- 跨功能域引用使用 `package:xxread/pages/...`；同一功能域内部可以使用相对 import。
- 页面公开类名不随目录整理做无关扩大重命名；后续业务拆分与文件归档分开进行。

## 主要页面

- `pages/home/home_shell_page.dart`：应用主壳和导航入口；手机悬浮底栏支持纯图标与“图标＋文字”两种模式，宽度在手机上取 `screenWidth - 36` 并以四项约 368px 为理想上限，选中底板按真实单项槽宽自适应；宽屏继续使用 `NavigationRail`。新用户完成欢迎协议后，主壳可挂载一次性开发者支持浮层。
- `pages/reading_stats/detailed_stats_page.dart`：阅读统计详情入口与数据加载；`reading_stats/parts/` 按公共样式、总览、图表、热力图、书籍排行和成就拆分页面模块，避免统计页继续膨胀为巨型文件。
- `pages/library/library_page.dart`：本地与在线书架；书库顶部提供下载任务入口。
- `pages/library/download_tasks_page.dart`：跨平台书籍下载队列的状态查看页。
- `pages/library/import_book/import_book_page.dart`：跨平台书籍导入队列；手机确认态采用顶部安全标题栏、独立滚动书目区和页面内底部操作区，并对文件选择器返回的异常窗口 inset 做限幅。
- `pages/reader/native_reader_page.dart`：本地 TXT、EPUB 等内容适配器。
- `pages/reader/book_source_reader_page.dart`：在线书源章节内容适配器。
- `pages/book_sources/source_search_page.dart`：在线书源搜索与发现。
- `pages/book_sources/book_source_management_page.dart`：原生协议书源管理。
- `pages/settings/settings_page.dart`：应用设置、版本与维护入口；`SettingsPageController` 可从首页导航后定位到“支持开发”区域。
- `pages/settings/custom_fonts_page.dart`：用户字体库的导入、应用、重命名和删除入口。
- `pages/settings/about/changelog_page.dart` 与 `services/core/changelog_service.dart`：应用内版本历史异步加载与展示；版本、顺序和四语文案统一来自 `assets/changelog/changelog.json`，首项自动标记为当前版本，语言按完整 locale、语言代码、英文和任意可用语言逐级回退。新增版本只更新数据资产，不再修改页面代码或增加版本专属 ARB getter。
- `pages/settings/about/open_source_licenses_page.dart`：应用、历史版本、内置字体及 Flutter/Dart 依赖的许可查看入口。
- `pages/legal/user_agreement_page.dart`：首次使用协议、隐私与第三方书源责任确认；条款披露 GitHub/官网更新检查和官网下载统计，含原始 IP 的下载明细最多保留 30 天。

## 官网更新集成

- `services/core/update_check_service.dart`：并行查询 GitHub Releases 与 `open.xxread.top` 的版本化 latest API，按语义版本选择最新结果；官网异常、无匹配 ABI 或元数据无效时保留 GitHub 兜底。
- `services/core/app_update_download_service*.dart`：Android 将官网 APK 下载到私有缓存的 `.part` 文件，只允许 `open.xxread.top` HTTPS 同域跳转，并以 512 MiB 为硬上限；下载进度或响应长度超过元数据声明时立即取消，完成后校验大小与 SHA-256 再原子改名。下载完成后立即把经校验的 APK 交给系统安装器，同时保留完成通知作为重试入口；Web/非 IO 平台使用安全桩实现。
- `services/core/background_download_notifier*.dart` 与 `services/library/download_task_controller.dart`：应用内书籍下载采用单任务队列，保留章节级三并发；Android 将活跃任务同步到前台数据同步服务和系统通知，通知权限失败不影响下载。iOS 继续只展示应用内任务状态，更新跳转官网或 GitHub。
- `widgets/update_check_gate.dart`：更新提示提供“稍后 / GitHub / 官网”三个选择。Android 官网路径在应用内后台下载、校验后直接进入系统安装器，完成通知可再次发起安装；iOS 当前打开官网下载页，后续上架后再切换 App Store。
- `android/app/src/main/kotlin/com/niki/xxread/AppUpdateBridge.kt`：提供 ABI 查询、未知来源安装授权和 FileProvider 安装桥；打开安装器前复核 APK 包名、实际 versionCode 和当前已安装应用的签名身份，普通应用不能静默安装。
- `android/app/src/main/kotlin/com/niki/xxread/DownloadForegroundService.kt` 与 `BackgroundDownloadBridge.kt`：Android 13+ 请求通知权限，使用前台 `dataSync` 服务更新书籍/APK 进度通知；完成通知把书籍 ID 或已验证 APK 路径送回 Flutter，由应用打开阅读器或系统安装器。
- 独立仓库 `miloquinn/open-reading-web` 负责 `open.xxread.top` 的页面、版本化 latest API、镜像导入、下载统计、后台、生产部署与运行数据安全；其发布和数据结构文档不再由客户端仓库重复维护。
- `.github/workflows/release.yml` 在 GitHub Release 完成后仍通过受控 SSH 导入官网镜像，并使用 `tool/official_site/verify_official_download.py` 下载、核对官网 arm64 APK 的元数据、大小和 SHA-256。
- `marketing/app-store/` 保存官网 WebP 的原始截图来源；界面更新时需要同步向独立官网仓库提交新的 `app/static/product/*-latest.webp`。

## 首次首页支持引导

- `widgets/first_home_support_overlay.dart`：正视透明纸张的卷轴展开、悬浮、退出动画与两个操作按钮；系统开启减少动态效果时直接展示完成态。
- `services/core/first_home_support_intro_service.dart`：以 SharedPreferences 键 `first_home_support_intro_seen_v1` 原子领取一次性展示资格。
- `assets/images/cyber_begging_paper.png`：无背景 RGBA 纸张素材；阴影与悬浮层次由运行时 UI 绘制，不写入图片本身。
- “立即支持”切换到设置页并滚动到捐赠卡片；“再说吧”关闭浮层。入口只在当前会话刚完成欢迎协议时请求展示，已领取后不重复出现。

## 字体架构

- `FontCatalog` 维护 App 字体与阅读字体两套内置语义目录；用户字体作为共享资产同时合并到两套候选列表。
- `AppSettingsNotifier` 分别保存 `app_font_id_v2` 与 `reader_font_id_v2`，同一用户字体可独立用于 App、阅读或两者。
- `AppSettingsNotifier` 同时持久化手机底部导航文字显隐；设置页外观开关更新后，`HomeShellPage` 通过 Provider 立即重建底栏，默认保持纯图标模式。
- `CustomFontService` 在原生平台负责 TTF/OTF 校验、SHA-256 去重、运行时 `FontLoader` 注册、清单恢复和文件删除；Web 首版不提供持久化字体导入。
- 用户字体使用 `custom_<hash>` 稳定 ID 和 `OpenReadingCustom_<hash>` 运行时 family，避免同名字体互相覆盖。
- 删除正在使用的用户字体时，App 字体与阅读字体分别恢复各自默认值；阅读字体 ID 仍参与分页布局签名。
- 内置字体的 SIL OFL 1.1 原文保存在 `assets/fonts/licenses/`，通过应用内开源许可页离线展示；用户自行导入的字体仍由用户负责确认授权范围。

## 本地书籍格式

- 单一事实来源：`lib/services/books/book_format_support.dart`（`BookFormatRegistry`）。
- 设计说明：`docs/book-format-support.md`（含 Lightink 对照与分阶段目标）。
- **目标架构**：文字书最终都进入 `NativeTextPaginator` 统一分页；ZIP/RAR 为容器解压后再分流；PDF/漫画走专用渲染。
- 文件选择器扩展名只使用 `BookFormatRegistry.pickerExtensions`（当前含 txt/epub/pdf/mobi/azw/azw3/fb2/rtf/doc/docx/cbz/cbr；zip/rar 为 planned，实现前不进选择器）。
- Lightink 1.22 对照：TXT/EPUB 完整文本引擎；ZIP/RAR 容器；MOBI/AZW3 仅 UI 级；PDF 无阅读引擎。Open Reading 在 Kindle/PDF/FB2 等上目标不低于并部分超过 Lightink。

## 阅读器架构

本地书籍与在线书源保留不同的内容获取和进度保存适配器，但共用一套阅读 UI 与设置逻辑。

```text
本地文件适配器 ─┐
                ├─ ReaderSettings / ReaderSettingsStore
在线章节适配器 ─┘  ReaderSettingsSheet / ReaderPageModeSheet
                   ReaderCustomTheme library / ReaderCustomThemeStore
                   ReaderThemeBackground / private image storage
                   ReaderTextLayout → ReaderTextPage → NativeTextPaginator
                   ReaderTextPageContent → identical RichText painting
                   ReaderPaperPageLeaf → ReaderShaderPageCurl
                   ReaderPullBookmark → BookmarkDao
                   ReaderChromeOverlay / ReaderSafeAreaMetrics
                   ReaderTopBarStyle / ReaderSystemUiController
                   ReaderKeepScreenOnController → Android window flag
                   BookOpenTransition → deferred reader mount
                   ReaderPageMode / ReaderLayoutFingerprint
```

核心文件：

- `utils/book_open_transition.dart`：书架封面展开/缩回路由；打开阶段只渲染封面与轻量纸色占位，路由动画落定后的下一帧才挂载目标阅读页，使 TXT 解析、同步分页、系统栏切换和 page-curl 快照抓取不进入打开动画帧预算。阅读页一旦挂载便保持到退出结束，反向飞回仍使用实时解析的封面位置。
- `core/reader/reader_settings.dart`：统一字号、行高、主题、翻页模式、首行缩进、段落间距、独立上下边距、“下拉书签”“点击动画”和平板双页偏好。`tabletTwoPageEnabled` 默认开启，以 `reader_tablet_two_page_enabled` 在两个阅读器之间共享持久化。
- `core/reader/reader_custom_theme.dart`：有序自定义阅读主题库模型；每个主题拥有稳定 ID、名称、字体色、阅读背景色、控制栏色、可选背景图片路径与显示强度。`ReaderCustomThemeStore` 使用 SharedPreferences JSON 列表持久化，并自动迁移旧的单主题 `reader_custom_theme_v1` 数据。
- `core/reader/reader_theme_order.dart`：阅读主题全局顺序存储；以稳定主题 ID 列表统一持久化预设与自定义主题的排列，并在读取时去除空值和重复项。
- `core/reader/reader_layout.dart`：翻页模式、分页缓存指纹与阅读布局断点；最短边至少 600 才视为平板，双页仅在横屏且宽度至少 720 时可用，并继续受用户开关控制。`pageCurl` 固定使用经典折页，不再维护额外的仿真样式状态。
- `core/reader/native_text_paginator.dart`：本地与在线纯文本分页共享实现；正文统一两端对齐，分页测量与最终绘制共用同一文字流；正文行高仅作用于行间，首行上方和末行下方的 leading 统一裁剪，配套 strut 不携带 `height`。分页可为第一页单独指定 `firstPageHeight`，供 EPUB 图片页缩小首屏文字区而让后续纯文字页恢复全高。
- `core/reader/reader_text_pagination.dart`：本地文件与在线书源唯一的文字章节分页入口和 `ReaderTextPage` 页面模型；统一 canonical/display offset、首行缩进、段落间距、独占章节标题页、首屏特殊高度和 760px 单 leaf 内容宽度上限。书源兼容包装不再拥有独立分页算法。
- `core/reader/reader_text_characters.dart`：TXT、EPUB、HTML/HTM/XHTML、Markdown、FB2、RTF、DOCX 与在线书源共享的硬换行和段首空白规则；覆盖 CR/LF、VT、FF、NEL、Unicode line/paragraph separator，以及常见 Unicode 空格和 BOM，保证各适配器与 Flutter 排版对段落起点的判断一致。
- `core/reader/txt_chapter_parser.dart`：TXT 章节识别与标题/正文边界的单一实现；识别出的标题独立存储，正文范围跳过标题行和相邻空行，并输出 `isNeedSplitTitle` 供分页模式插入章节标题页。小文件解析缓存和大文件 UTF-8 索引共用该边界结果。
- `core/reader/reader_text_layout.dart`：把首行缩进和段落间距投影成显示文字，并维护显示 UTF-16 boundary 到原文 boundary 的单调映射，保证书签和阅读进度仍使用 canonical offset；所有可重排文本格式使用同一段首识别，EPUB 解析器生成的连续段落换行只在显示层归一化，不改写规范文本。
- `core/reader/reader_page_turn_geometry.dart`：经典折页使用“局部装订始终为 x=0”的 leaf canonical 坐标；`bindingEdge` 只负责左右 leaf 的坐标换算，翻页方向不再移动书脊。几何显式区分 outgoing（当前页卷走）与 incoming（上一页展开）两种运动；手机 backward 按起手后的位移驱动折线，固定起手高度参与对角斜率，纵向移动会实时改变折痕。提交时双轴弹簧吸附到精确的 x=0 / x=width 竖直端点，使 shader 的透明/identity 终态分支稳定命中。
- `core/reader/reader_leaf_status.dart`：分钟级时间、电量状态；Android/iOS 通过 `com.niki.xxread/reader_status` method channel 读取电量。分页模式选用阅读信息栏时，状态 revision 会参与纸页快照更新；上下翻页则由固定视口信息栏直接消费。
- `core/reader/reader_safe_area.dart`：系统安全区、阅读信息栏预留、正文边距和页码位置。
- `core/reader/reader_system_ui.dart`：统一三态顶部样式（系统状态栏、阅读信息栏、完全沉浸）、旧布尔偏好迁移和 Android/iOS 系统栏切换；iOS 的 `ReaderFlutterViewController` 通过控制器级 `prefersStatusBarHidden` 同步隐藏状态栏和 Home Indicator，只有“系统状态栏”模式显示系统顶部栏；退出阅读页时恢复应用级 edge-to-edge。
- `core/reader/reader_vertical_paging.dart`：上下翻页的固定视口留白、正文窗口高度、中心可见项选择和章内页索引换算；不依赖具体列表包，供本地与书源阅读器共享。
- `core/reader/canonical_locator.dart`：与排版无关的稳定阅读位置。
- `core/reader/reader_volume_key_controller.dart`：Android 音量键翻页桥接；读取全局开关，只在非滚动分页模式下启用原生按键拦截，并把上一页/下一页事件路由给当前阅读器。
- `core/reader/reader_keep_screen_on.dart`：共享“阅读时保持屏幕常亮”控制；按活动阅读页持有/释放 `keepScreenOn` 偏好，并通过 Android 原生窗口 `FLAG_KEEP_SCREEN_ON` 生效，应用恢复前台时重新应用。
- `pages/reader/themes/reader_custom_themes_page.dart`：阅读主题管理页，预设与自定义主题共用一套拖拽顺序；自定义主题额外支持新增、编辑与删除，选择和排序结果直接回传两个阅读器。
- `pages/reader/themes/reader_custom_theme_page.dart`：单个自定义阅读主题编辑页，提供名称、实时纸页预览、预设/十六进制选色、背景图片上传/移除/强度和正文对比度提示。
- `services/core/reader_theme_background_service*.dart`：原生平台背景图片导入边界；校验 JPG/PNG/WebP 与 20 MB 上限，把文件复制到应用私有目录，Web 保持安全不支持实现。
- `widgets/reader_theme_background.dart`：阅读背景合成层，按主题底色铺底并以受控强度叠加用户图片；本地阅读器、在线书源阅读器、纸页快照和主题预览共同使用。
- `widgets/reader_settings_controls.dart`：完整阅读设置、主题横向卡片、翻页模式、三态顶部信息选择器和阅读交互开关面板；平板会显示双页布局开关，手机不渲染该选项。预设与自定义主题按统一用户顺序展示，最右侧固定为带自定义主题数量的管理入口。
- `widgets/reader_pull_bookmark.dart`：只从屏幕顶部区域起手的原始指针下拉手势、阈值反馈和当前页书签页缘标记；数据仍复用既有 `BookmarkDao`。
- `widgets/reader_vertical_paging_surface.dart`：本地文件与在线书源共用的上下翻页交互宿主；把中间轻点识别放在 `SelectionArea` 内部，统一“轻点呼出控制栏、竖滑只滚正文”的手势优先级。
- `widgets/reader_chapter_title_page.dart`：章节独占标题页组件；从正文样式继承字体与主色，字号按正文 `1.8×` 并限制在 28–34，标题水平居中且垂直略偏上。
- `widgets/reader_text_page_content.dart`：本地与在线文字页的共享最终绘制组件；直接消费分页阶段生成的 `ReaderTextPage` 与 `NativeTextFlowStyle`，正文统一使用同一 `RichText` 参数，章节标题统一转交独占标题页组件。
- `widgets/reader_paper_page_leaf.dart`：正文、可选的页内阅读信息栏与章内页码组成完整纸页；无动画、横滑和仿真翻页均以它为最小 page leaf，因此时间、标题、电量和页码会随纸张运动。手机/单页页码位于右下，平板 spread 的左 leaf 位于左下、右 leaf 位于右下；空白和补位 leaf 保留对应顶部信息角色，但不显示虚假页码。页码距离外侧屏幕边缘至少 24px，避开圆角遮挡。
- `widgets/reader_top_information_bar.dart`：时间、章节标题和电量的共享绘制组件；单页使用 `full`，平板 spread 左页使用 `spreadLeft` 仅在左上显示章节标题，右页使用 `spreadRight` 仅在右上显示时间和电量；上下翻页复用于固定视口 chrome。
- `widgets/reader_shader_page_curl.dart`：经典折页公共 library 入口，外部 API 保持稳定；实现按 API、状态机、快照缓存、绘制、收尾物理和内部类型拆到 `widgets/src/page_curl/`。手机 forward 以 current 为卷动源、next 为实时底页；backward 以 previous 为展开 source、current 为实时 underlay。平板 outgoing 可额外传入 `outgoingBackPage` 作为纸张背面：右页 forward 使用下一 spread 左页，左页 backward 使用上一 spread 右页；第二张 shader sampler 会在折叠逆变换后再反转纹理 X，使背页落到书脊另一侧时保持正常阅读方向，手机未传该页时继续沿用镜像 source。所有拖动先等待累计位移超过 18px，再把当时手指位置记录为 activation point；backward 激活后每帧直接使用真实 X/Y 位移，不保留水平/对角永久锁，松手只比较最终 X 是否越过 activation X 且不读取 release velocity。120ms 自由边追赶只属于屏幕中部起手的 outgoing，真实边缘起手直接跟手。Incoming 的提交与取消都以 X 为主通道，并在剩余 X 行程前 84% 内平滑拉平 Y，进入终点后保持精确竖直 pose，避免右下甩尾或阴影复现。活动 source 或纸背缓存未命中时先用已完成 paint 的 `RepaintBoundary.toImageSync()` 临时纹理保证首帧跟手，随后在页面准备完成后异步重抓并原子替换；Shader 直接消费 canonical `posA/posB`，保留恢复出的 `max(0,x)` 装订硬边界。单 leaf 连续请求走有界 FIFO；平板左右 leaf 通过共享 coordinator 串行化，并由 `ReaderPageCurlSpread` 按当前活动装订边动态调整绘制层级。
- `widgets/reader_control_chrome.dart`：统一顶部、底部控制栏，并仅为上下翻页承载固定视口阅读信息栏；信息栏在系统安全区下方显示时间、章节标题和电量，并在控制栏展开时淡出。上下翻页的章内页码固定在右下，其余分页模式的信息栏与页码均由纸页 leaf 绘制。
- `widgets/reader_navigation_sheet.dart`：目录、书签和定位面板；整个面板使用当前阅读主题配色，目录按 EPUB 等来源提供的 `depth` 还原为可展开/收起的层级树，搜索结果保留祖先路径，“当前”定位会自动展开被折叠的父链。
- `widgets/generated_book_cover.dart`：无真实封面时的统一实时封面组件，与持久化 PNG 共用同一绘制器。

支持的翻页模式：

- `verticalScroll`（上下翻页；先分页再用 `ScrollablePositionedList` 竖向滑动，不拦截音量键；可在单章页列表与整书可定位页列表之间切换；正文列表固定裁剪在章名与页码之间）
- `instantPage`（无动画）
- `horizontalSlide`（水平滑动）
- `pageCurl`（仿真翻页；固定使用对角反射与真实弹簧驱动的经典折页）

平板仿真翻页按两张独立 leaf 组成 spread，本地文件与在线书源阅读器共用相同约束：只有横屏平板满足断点且 `tabletTwoPageEnabled` 开启时才进入双页，关闭后回退单页；设置变化时本地阅读器按文本锚点恢复，书源阅读器会失效分页缓存并按文本 offset 恢复。左页从屏幕最左自由边向后翻并使用右装订，右页从屏幕最右自由边向前翻并使用左装订，翻页步长为两页；正中的 24px `_spreadGutter` 是固定书脊，不进入任一 leaf 的抓图变换或手势命中区。`ReaderPageCurlSpread` 以固定位置的 `Stack` 保持左右页布局不变，并把 coordinator 当前持有的活动 leaf 放到最后绘制；活动经典折页的 shader 绘制边界会沿装订侧扩展到整张 spread，因此下一页由右页跨书脊覆盖左页，上一页则由左页覆盖右页，静止 leaf 与手势命中区仍限制在各自半屏。纸张内容按“正面 / 背面 / 底页”三层分离：例如 8/9 向前翻时右 leaf 的 source 为 9、独立纸背为 10、实时底页为 11；向后翻时左 leaf 的 source 为当前左页、纸背为上一 spread 右页、底页为上一 spread 左页。native 双页会给奇数页章节补右侧空白 slot，使每章稳定从左页开始，动态扩展章节窗口不会改变既有 spread 奇偶；两个阅读器在视口重排时都按文本 offset 恢复，而在线书源跨章优先使用已预取章节的真实目标 leaf，并为左右 boundary/blank slot 使用不同快照身份，按最后可见页保存双页进度。手机单页使用整屏 leaf，前后翻页的物理装订边都位于左缘；backward 是独立 incoming 通道，不再通过方向镜像书脊或整套 forward 几何。

TXT 在识别到“第 X 章 / Chapter X / Part X / 序章”等章节行时，把标题与正文分离。分页模式将 `isNeedSplitTitle` 章节的第 0 页作为特殊标题页：标题使用正文主色、约 `1.8×` 正文字号（限制在 28–34）、水平居中并略偏上；后续页面进入 `ReaderTextLayout → ReaderTextPage → NativeTextPaginator`。在线书源目录天然提供章节结构，因此同样先生成独占标题页，正文不再把标题嵌入首屏或缩减第一页高度。未识别出章节结构的普通 TXT 不把文件名强制转为独占标题页。上下翻页直接竖向排列同一套分页结果，并由固定视口章名跟随当前中心可见页。

EPUB 图片块与其后的正文共用同一个显示投影：携带图片的第一张页面按图片区/文字区约 `5:6` 排列，只有该页使用较小的文字高度；同一图片块后的纯文字续页立即恢复完整页面高度，避免图片影响扩散到后续多页。图片块本身仍作为不可拆分内容边界，因此图片前一个文本段落的末页可能比普通非末页短。

上下翻页的正文宿主采用外层 `Padding + ClipRect` 固定阅读窗口：`contentTop` 与 `contentBottom` 只在屏幕上下各保留一次，每个纵向 page item 高度等于中间 `contentHeight` 且只携带水平边距。分页测量、item extent、预缓存、章节内跳转和位置恢复共用该高度，避免 EPUB 等连续正文页重复叠加顶底 chrome 留白，也阻止正文滚入固定章名和页码区域。TXT 独占章节标题页仍作为正常 page item 保留。

## 在线书源结构

协议标识为 `open-reading-source`，当前版本为 `1.3`；v1 客户端继续接受所有 `1.x` 发现文档。

主要数据对象：

- `BookSourceManifest`：书源身份、API 地址、语言和能力声明，以及可选的运营者、联系入口、内容许可、权利声明和章节目录单页上限。
- `BookSourceBook`：在线书籍元数据。
- `BookSourceChapter`：章节目录项；客户端按 ORSP 1.4 分页信封持续拉取，直至 `hasMore` 为 `false`。
- `BookSourceChapterContent`：章节正文，支持纯文本、Markdown 和 HTML。
- `BookSourceSearchPage`：分页搜索结果。
- `BookSourceDiscoveryPage`：可选的发现页分区。

书源服务边界：

- `BookSourceRegistry`：注册和启用状态。
- `BookSourceClient`：协议请求。
- `BookSourceChapterText`：仅把 HTML/纯文本响应转换为 canonical chapter text，并清理重复远端页码；若正文最前面的首行/首段与接口标题或目录标题规范化后完全相同，则像本地 TXT 章节解析一样剥离该重复标题。不注入首行缩进、段间距或章节标题，这些展示语义全部交给共享文字阅读内核。
- `BookSourceChapterCache`：章节正文的内存/磁盘缓存和并发去重；在线阅读器优先预取下一章并生成分页布局，再机会式准备上一章与更远的后一章，缓存始终限制在相邻范围。水平滑动到相邻章节时，真实预览页先在当前 `PageView` 内完成整段动画，只有 `ScrollEnd` 确认停在边界页后才提交章节状态；提交后复用已预热布局，并让新控制器直接挂接目标页，避免停稳后的可见重置。中途回滑会取消待提交切章，进度持久化不阻塞跨章提交。
- `BookSourceShelfService`：在线书籍加入本地书架；书源未提供封面时生成并持久化统一封面。
- `BookSourceReadingProgressStore`：在线章节阅读进度。

发现页默认聚合当前栏目下所有已启用且声明对应能力的书源，并允许按单一书源筛选。
推荐分区和分类保留来源边界；最新列表保留各源内部顺序后按来源均衡穿插，每个书籍身份
始终由 `sourceId + bookId` 共同确定。
分类栏目只在主页面展示当前分类；完整分类集合在移动端底部面板或桌面对话框中按书源
分组，并通过可搜索的惰性列表选择，避免分类数量随书源增长时同步构建全部标签。

官方发行版不包含默认或预装书源，也不订阅官方书源目录；`BookSourceRegistry` 首次安装
为空，只保存用户在本机主动添加的 URL。首次启动条款与每次新增书源分别要求确认第三方
责任边界；新增书源确认明确禁止绕过登录、付费、DRM 或其他访问控制。书源管理页展示
运营者自行提供的权利元数据并标注“未经项目核验”，项目控制材料的投诉进入仓库专用
rights-report Issue 表单，第三方书源内容投诉优先指向其运营者或托管方。

## 核心数据模型

### Book

`Book` 同时承载本地书籍和加入书架的在线书籍：

- 基础元数据：标题、作者、格式、导入时间、封面。
- 封面策略：真实本地封面或书源封面优先；缺失、历史空数据或加载失败时，统一按书名与作者生成简约封面，生成结果不受文件格式和来源影响。
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
- “下拉书签”开关；关闭时保留工具栏书签入口，只禁用顶部下拉快捷手势。
- “点击动画”开关；开启时左右点击复用当前翻页模式动画，关闭时点击直接切页，拖动和音量键行为不受影响。
- 首行缩进（0–4 个全角字宽）和段落间距（0–2 个附加空行）；EPUB 的 `0` 会压缩解析器生成的双换行为单个结构换行，真正不保留空白行，`1/2` 再分别加入一行或两行空白。
- “按章节滚动”开关；本地文件与在线书源读取同一个持久化键。
- “平板双页布局”开关；仅平板设置面板显示，默认开启，手机始终使用单页且不显示该开关。

旧的单一纵向边距仅作为迁移输入，不再作为当前设置模型。在线书源关闭“按章节滚动”后使用懒加载的跨章节纵向列表，并按当前可见章节保存章节索引与章内进度。

水平页边距由 `ReaderMarginSettings` 统一限定为 `0..48`，设置面板、持久化恢复和两个阅读器入口使用同一范围。本地与在线书源正文统一采用两端对齐，把中文软换行后不足一字宽的余量分散到字间；分页测量与实际渲染使用同一对齐规则。在线书源正文在扣除用户页边距后，仍以最大 760 logical pixels 的内容宽度居中。

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
- SharedPreferences：阅读 UI 设置、App/阅读字体选择、手机底部导航文字显隐、应用偏好和轻量状态；自定义阅读主题以 JSON 列表保存，预设与自定义主题的统一顺序以稳定 ID 列表单独保存，两个阅读器共享，旧单主题记录首次读取时自动迁移。
- 应用私有目录：数据库、缓存、封面、应用管理的书籍文件，`custom_fonts/` 下的用户字体与清单，以及 `reader_theme_backgrounds/` 下由应用托管的阅读主题背景图片。
- 用户授权目录：通过平台存储桥接原地管理或导入书籍。
- 网络：仅在用户使用在线书源、封面、AI、同步或更新检查等功能时访问。

## 测试结构

- `reader_*_test.dart`：阅读设置、分页、安全区、导航和翻页效果。
- `book_source_*_test.dart`：原生书源协议、缓存、搜索、书架和在线阅读。
- `book_import_*_test.dart`：导入模型、迁移、来源和队列。
- `*_page_test.dart`：页面组件回归。

Flutter Golden 失败时生成的 `test/failures/` 属于本地诊断产物，不纳入版本控制。
