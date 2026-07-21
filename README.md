<div align="center">
  <img src="assets/images/app_icon.png" width="112" alt="开元阅读图标">
  <h1>开元阅读 · Open Reading</h1>
  <p>本地优先、跨平台、支持开放书源的现代电子书阅读器</p>

  <p>
    <a href="README.en.md">English</a> ·
    <strong>简体中文</strong> ·
    <a href="README.zh-TW.md">繁體中文</a> ·
    <a href="README.ja.md">日本語</a> ·
    <a href="README.ko.md">한국어</a> ·
    <a href="README.es.md">Español</a>
  </p>

  <p>
    <a href="https://open.xxread.top/"><strong>开元阅读官网</strong></a> ·
    <a href="https://community.xxread.top/">小元读书社区</a> ·
    <a href="https://xxread.top/">小元读书（仅 iOS）</a>
  </p>

  <p>
    <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-AGPL--3.0-2ea44f" alt="AGPL-3.0 License"></a>
    <img src="https://img.shields.io/badge/Reader_Engine-Flutter_Native-0ea5e9" alt="Flutter Native Reader Engine">
    <img src="https://img.shields.io/badge/Core_Reader-No_WebView-f97316" alt="Core Reader Without WebView">
    <a href="https://github.com/miloquinn/open-reading"><img src="https://img.shields.io/badge/GitHub-open--reading-181717?logo=github" alt="GitHub"></a>
    <a href="https://github.com/miloquinn/open-reading-source-protocol"><img src="https://img.shields.io/badge/Book_Source-ORSP_1.1-7c3aed" alt="Open Reading Source Protocol 1.1"></a>
  </p>
</div>

---

开元阅读是一款使用 Flutter 构建的开源电子书阅读器。它以本地文件阅读为基础，同时通过
Open Reading Source Protocol（ORSP）连接用户自行选择的公开内容服务。书籍、阅读进度、
书签、阅读统计与大多数设置默认保存在当前设备；本地阅读不要求登录，也不依赖项目方的
云端服务。

## 当前功能

### 本地书架与阅读

- 导入和管理本地书籍，记录最近阅读、阅读进度、阅读时长与会话统计；
- TXT 支持编码探测、章节识别和独立章节标题页，EPUB 支持目录、正文与图片内容解析；
- 无真实封面时自动生成简约封面，真实封面始终优先；
- 书架支持搜索以及“全部 / 在读 / 已读”筛选；
- Android 与 iOS 提供平台存储桥接，桌面端使用本地文件和 SQLite FFI。

### 原生阅读体验

- 核心正文使用 Flutter 原生排版与分页，不以 WebView 承载阅读页；
- 支持上下翻页、无动画、水平滑动和经典仿真折页四种模式；
- 平板支持双页阅读，仿真模式使用固定中缝和左右独立纸页；
- 支持字号、行高、上下左右边距、首行缩进、段落间距和正文两端对齐；
- 支持预设阅读主题，以及可新增、编辑、删除、排序的多套自定义主题；自定义主题可使用
  JPG、PNG 或 WebP 背景图片；
- 支持导入 TTF / OTF 字体，并可分别设置 App 字体和阅读字体；
- 阅读页顶部可选择系统状态栏、阅读信息栏或完全沉浸；分页纸页可显示时间、章节、电量和
  章内页码；
- EPUB 多级目录支持折叠、搜索和自动定位当前章节；
- 支持工具栏书签和顶部下拉书签手势；
- 支持系统 TTS 朗读；Android 还支持音量键翻页和阅读时保持屏幕常亮。

### 首页与阅读记录

- 首页展示最近阅读、今日 / 本周 / 累计阅读时长和周趋势；
- 支持每日阅读目标、今日阅读计划、连续阅读天数和专注计时；
- 可选配置 AI 服务，为首页提供阅读建议；API Key 和服务商由用户自行选择和管理。

### 开放书源

- 添加、启用、停用或移除符合 ORSP 1.4 的 HTTP(S) 书源；
- 聚合多个已启用书源的推荐、分类、最新内容和搜索结果，并可筛选全部或单一书源；
- 支持在线查看书籍详情、目录和章节正文，也可加入本地书架；
- 在线阅读与本地阅读共用主题、排版、翻页模式、书签入口和阅读设置；
- 章节内容按需获取并缓存，一个书源失败不会丢弃其他书源已返回的结果。

### 可选 AI 服务

设置页可配置 OpenAI、Claude、Gemini、GLM、MiniMax，以及兼容接口的自定义 Base URL、
模型和参数。AI 功能需要用户自行提供合法可用的服务与凭据；相关请求会直接发送给用户
选择的第三方服务商。

## 本地格式支持

格式支持以 [`BookFormatRegistry`](lib/services/books/book_format_support.dart) 为准。当前不要把
“文件选择器能够选中”理解为“正文阅读已经完整支持”。

| 状态 | 格式 | 当前说明 |
| --- | --- | --- |
| 可完整阅读 | TXT | 编码探测、章节切分、原生分页与稳定进度恢复 |
| 可阅读 | EPUB | 解析为章节文本和图片后进入原生分页，不使用 WebView 排版 |
| 有限支持 | PDF、MOBI / AZW / AZW3、FB2、RTF、DOC / DOCX、CBZ / CBR | 可进入导入流程并尽力读取元数据；部分格式的完整正文或专用阅读器仍未完成 |
| 计划中 | ZIP、RAR | 尚未进入文件选择器；后续将解压并按内层格式分流 |

更详细的能力矩阵和后续管线见
[`docs/book-format-support.md`](docs/book-format-support.md)。

## 为什么是 Flutter 原生阅读引擎

开元阅读不会把 EPUB 的 HTML 直接交给 WebView。章节解析、文本测量、分页、页面布局、
翻页交互和阅读位置恢复都在 Flutter 渲染体系内完成，因此本地文件与在线书源可以共用
同一套阅读界面和设置。

当前阅读内核包括：

- 基于 `TextPainter` 和行盒信息的实际尺寸测量与分页；
- 由字体、字号、行高、边距和可用页面尺寸共同决定的布局指纹；
- 章节级懒加载、分页缓存和纸页快照缓存；
- 基于原文 UTF-16 offset 与 Canonical Locator 的稳定阅读锚点；
- TXT / EPUB 文本统一分页，以及在线书源正文的同管线排版；
- 无动画、横滑、纵向分页和经典仿真折页共用同一份分页结果。

## 本地优先与联网边界

- 本地阅读不要求账号；
- 书籍、进度、书签、统计、字体和阅读主题主要保存在当前设备；
- 项目当前不内置云同步或 WebDAV，卸载、清理数据或设备故障前请自行备份；
- 只有在用户主动使用书源、封面检索、AI、更新检查等功能时才会访问网络；
- 更新检查会同时查询 GitHub Releases 与官方站点；从官方站点下载安装包时，服务端会为下载统计、安全防护和故障排查记录版本、架构、时间、IP 与 User-Agent，含原始 IP 的明细最多保留 30 天；
- 自定义字体、背景图片、书籍文件和第三方内容的使用与分发授权由用户自行确认。

## Open Reading Source Protocol

ORSP 1.4 让阅读器通过统一 HTTP 协议连接公开、无需登录的内容服务，而不是在客户端保存站点
抓取规则、Cookie 或可执行脚本。协议定义发现文档、搜索、书籍详情、分页章节目录与章节正文，
还可选提供推荐、分类和浏览能力，以及运营者、联系入口、内容许可与权利声明元数据。

- 协议仓库：[miloquinn/open-reading-source-protocol](https://github.com/miloquinn/open-reading-source-protocol)
- 仓库内规范副本：[`docs/book-source-protocol-v1.md`](docs/book-source-protocol-v1.md)
- OpenAPI 定义：[`docs/book-source-openapi.yaml`](docs/book-source-openapi.yaml)
- 示例发现文档：[`docs/examples/open-reading-source.json`](docs/examples/open-reading-source.json)

运行仓库内的本地示例书源：

```bash
dart run tool/example_book_source_server.dart
```

然后在 App 的“书源”页面添加 `http://127.0.0.1:8787`。Android 模拟器访问宿主机时通常需要
改用 `http://10.0.2.2:8787`。

请只接入原创、公共领域或已获得合法授权的内容，不要使用书源能力绕过访问控制、付费机制
或第三方服务条款。
客户端会展示书源运营者自行提供的权利信息，但不会把这些声明视为 Open Reading 的认证或
背书。项目控制范围内材料的权利投诉可通过
[GitHub 权利报告表单](https://github.com/miloquinn/open-reading/issues/new?template=rights_report.yml)提交。

## 开始开发

环境要求：Flutter 3.x、Dart `>=3.4.0 <4.0.0`。

```bash
git clone https://github.com/miloquinn/open-reading.git
cd open-reading
flutter pub get
flutter run
```

常用检查：

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

构建示例：

```bash
flutter build apk
flutter build windows
flutter build web
```

仓库包含 Android、iOS、Windows、macOS、Linux、Web 和 OpenHarmony 工程。版本 Tag 会通过
GitHub Actions 生成 Android、Windows 和 Linux 产物，发布到 GitHub Releases，并在校验后同步
到 [官方站点](https://open.xxread.top/download)。Android 可在更新提示中选择 GitHub 或官网，
官网下载会在应用内完成校验并交给系统安装器；iOS 当前打开网页，后续上架后再切换 App Store。

## 项目结构

```text
lib/
├── book_sources/  # ORSP 协议模型、客户端、注册表、缓存和在线进度
├── core/reader/   # 阅读设置、分页、定位、布局与翻页几何
├── data/          # 数据迁移
├── l10n/          # 多语言资源与生成代码
├── models/        # 书籍、书签等领域模型
├── pages/         # 首页、书架、发现、书源、设置和阅读页面
├── reader_core/   # AI 配置与请求层
├── services/      # 导入、存储、统计、字体、主题、AI 与 TTS 服务
├── utils/         # 主题、布局、编码等工具
└── widgets/       # 通用组件和共享阅读器界面

docs/              # 协议、格式支持、设计和开发文档
shaders/           # 仿真翻页着色器
test/              # 单元、组件、回归和端到端测试
tool/              # 本地开发、官网发布校验与示例服务工具
```

官网、发行 API、安装包镜像与下载统计服务位于独立仓库
[`miloquinn/open-reading-web`](https://github.com/miloquinn/open-reading-web)。

更完整的架构说明见 [`structure.md`](structure.md) 和
[`CODEBASE_DOCUMENTATION.md`](CODEBASE_DOCUMENTATION.md)，版本变化见
[`CHANGELOG.md`](CHANGELOG.md)。

## 支持开发

开元阅读的设计、开发、测试和持续维护投入了大量时间与精力。如果这个项目对你有帮助，
欢迎通过微信或支付宝自愿捐赠，支持项目继续迭代。

<div align="center">
  <img src="assets/images/wechat_donation_qr.png" width="340" alt="微信捐赠二维码">
  <img src="assets/images/alipay_donation_qr.jpg" width="340" alt="支付宝捐赠二维码">
  <p>使用微信或支付宝扫码支持持续开发</p>
</div>

> 捐赠完全自愿，不影响任何功能，也不构成购买或服务承诺。

## 参与贡献

欢迎提交 Issue 和 Pull Request，包括阅读体验、格式兼容、平台适配、无障碍、翻译和 ORSP
参考实现。提交前请运行格式化、静态分析和相关测试，并避免提交 API Key、书籍文件、本地
数据库或任何无权分发的内容。

## 许可证

[GNU AGPL-3.0](LICENSE) © [miloquinn](https://github.com/miloquinn)。修改版在分发或通过网络
提供服务时，须按 AGPL-3.0 提供对应源代码。`v1.0.0` 及更早发布版本仍适用其原有
[MIT 授权](LICENSE-MIT-LEGACY)，详见[授权边界说明](LICENSING.md)。

<!-- Minimal documentation-only change for pull request verification. -->
