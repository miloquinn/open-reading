<div align="center">
  <img src="assets/images/app_icon.png" width="112" alt="开元阅读图标">
  <h1>开元阅读 · Open Reading</h1>
  <p>本地优先、跨平台、开放书源的现代电子书阅读器</p>

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
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-2ea44f" alt="MIT License"></a>
    <img src="https://img.shields.io/badge/Reader_Engine-Flutter_Native-0ea5e9" alt="Flutter Native Reader Engine">
    <img src="https://img.shields.io/badge/Core_Reader-No_WebView-f97316" alt="Core Reader Without WebView">
    <a href="https://github.com/miloquinn/open-reading"><img src="https://img.shields.io/badge/GitHub-open--reading-181717?logo=github" alt="GitHub"></a>
    <a href="https://github.com/miloquinn/open-reading-source-protocol"><img src="https://img.shields.io/badge/Book_Source-Open_Protocol-7c3aed" alt="Open Reading Source Protocol"></a>
  </p>
</div>

---

开元阅读是一款使用 Flutter 构建的开源电子书阅读器。项目希望把阅读重新变得简单：
书籍、进度和笔记默认留在自己的设备上，同时提供稳定排版、朗读、标注、阅读统计、
可选 AI 辅助，以及能够由社区共同扩展的开放书源能力。

## 🌐 项目与站点

| 名称 | 定位 | 地址 |
| --- | --- | --- |
| 开元阅读 | 本仓库对应的开源、跨平台阅读器 | [open.xxread.top](https://open.xxread.top/) |
| 小元读书 | 面向用户的阅读产品，目前仅提供 iOS 版本 | [xxread.top](https://xxread.top/) |
| 小元读书社区 | 阅读、创作与交流社区 | [community.xxread.top](https://community.xxread.top/) |

## 🚀 不是 WebView 套壳，是 Flutter 原生阅读引擎

很多跨平台阅读器会把 EPUB 的 HTML 直接交给 WebView，再围绕网页容器拼接阅读功能。
开元阅读的核心阅读页选择了一条更难、但上限更高的路：**自研 Flutter 原生阅读引擎**。

从章节解析、文本样式、精确测量、分页切割、图片混排，到页码、目录、阅读位置和布局
变化后的锚点恢复，都在 Flutter 渲染体系内完成。核心阅读链路不依赖 WebView，因此界面、
手势、主题和阅读状态可以与整个 App 保持一致，而不是在 Flutter 与网页容器之间来回同步。

原生引擎目前包含：

- 基于 Flutter `TextPainter` 的真实尺寸测量与二分分页，不用粗略字符数假装页码；
- 字号、行距、横纵边距和屏幕尺寸共同生成布局签名，配置变化后重新精确排版；
- 内存分页缓存与章节级懒加载，降低重复排版和大文本一次性加载的成本；
- EPUB 章节、样式与图片块解析，以及 TXT 等文本格式的原生章节索引；
- 基于字符偏移的稳定阅读锚点，重新排版后尽可能回到同一阅读位置；
- 分页完整性断言，确保分页前后不吞字、不重复字符。

这不是把网页塞进 App 的阅读壳，而是一套可以继续优化性能、排版能力和交互体验的原生
阅读基础设施。

> [!IMPORTANT]
> 在线书源通过独立开源的 **Open Reading Source Protocol（ORSP）** 接入。
> 查看[协议仓库、规范、OpenAPI 和测试书源](https://github.com/miloquinn/open-reading-source-protocol)。

## ✨ 核心能力

| 方向 | 已实现能力 |
| --- | --- |
| 📚 本地阅读 | EPUB、PDF、TXT、ZIP 导入，本地书架与阅读进度管理 |
| ⚡ 原生引擎 | 自研 Flutter 原生排版、精确分页、锚点恢复与章节级缓存，核心阅读链路无 WebView |
| 🎨 阅读体验 | 字号、行距、边距、主题、分页缓存与多种阅读布局 |
| 📝 阅读记录 | 书签、高亮、笔记、阅读统计与历史记录 |
| 🔊 辅助功能 | 系统 TTS 文本朗读与阅读状态保持 |
| 🌐 开放书源 | 添加符合 ORSP 的服务，跨已启用书源聚合搜索 |
| 🤖 AI 辅助 | OpenAI、Claude、Gemini、GLM、MiniMax 及兼容接口 |
| 🖥️ 跨平台 | Android、iOS、Windows、macOS、Linux 与 Web 工程 |

## 🌱 本地优先

- 书籍、阅读进度、书签和笔记默认保存在当前设备；
- 本地阅读不要求登录，也不依赖项目开发者提供的云端服务；
- AI、在线书源等联网功能由用户主动配置并选择服务提供方；
- 项目当前不内置云同步或 WebDAV，数据与备份由用户自行掌控。

## 🔌 开放书源协议

不同书源不再需要把站点脚本或可执行规则塞进阅读器。兼容服务只需按照统一 HTTP 协议
提供发现、搜索、书籍详情、章节目录和正文接口，阅读器即可接入。

- 协议仓库：**[miloquinn/open-reading-source-protocol](https://github.com/miloquinn/open-reading-source-protocol)**
- 协议名称：Open Reading Source Protocol
- 当前版本：`1.0` 早期公开草案
- 适用范围：原创、公共领域或已获得合法授权的内容

开发者可以直接搭建原生 ORSP 服务，也可以为自己有权使用的现有内容服务编写适配网关。
App 的“书源”页面内同样提供协议说明和 GitHub 仓库入口。

运行仓库内的本地测试书源：

```bash
dart run tool/example_book_source_server.dart
```

协议规范的独立副本、JSON Schema、OpenAPI 3.1 定义及零依赖 Dart 参考服务均维护在
[书源协议仓库](https://github.com/miloquinn/open-reading-source-protocol)。

## 🚀 开始开发

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

## 🧭 项目结构

```text
lib/
├── book_sources/  # ORSP 协议模型、客户端与书源注册表
├── core/          # 阅读内核与定位模型
├── l10n/          # 中英文应用本地化资源
├── models/        # 书籍、书签、笔记等数据模型
├── pages/         # 书架、书源、设置及阅读页面
├── reader_core/   # 文档解析与 AI 请求层
├── services/      # 导入、存储、统计与朗读服务
├── utils/         # 主题、布局、编码等工具
└── widgets/       # 通用界面组件

docs/              # 项目内协议与开发文档
test/              # 单元测试及书源端到端测试
tool/              # 本地开发与示例服务工具
```

## 🤝 参与贡献

欢迎提交 Issue 和 Pull Request，包括阅读体验改进、格式兼容、平台适配、无障碍优化、
翻译以及 ORSP 参考实现。提交前请运行格式化、静态分析和相关测试，并避免提交 API Key、
书籍文件、本地数据库或任何无权分发的内容。

## ⚖️ 负责任地使用

开元阅读不提供或托管盗版内容。请只导入、接入和传播自己有权使用的文件与服务，不要
使用书源能力绕过访问控制、付费机制或第三方服务条款。

## 📄 许可证

[MIT](LICENSE) © [miloquinn](https://github.com/miloquinn)
