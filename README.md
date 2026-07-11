# 开元阅读 · Open Reading

一个开源、跨平台、专注阅读体验的电子书阅读器。

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Repository](https://img.shields.io/badge/GitHub-miloquinn%2Fopen--reading-181717?logo=github)](https://github.com/miloquinn/open-reading)

开元阅读希望把阅读器重新变简单：本地导入、稳定排版、舒适阅读、必要的笔记与 AI 辅助，不依赖云端服务，也不把设置页变成功能仓库。

## 功能

- 支持 EPUB、PDF、TXT、ZIP 等常见电子书格式
- 原生 Flutter 阅读页与分页缓存
- 字号、行距、边距、主题等排版选项
- 书签、高亮、笔记与阅读进度
- TTS 文本朗读
- 阅读统计与本地书架管理
- 可配置 OpenAI、Claude、Gemini、GLM、MiniMax 及兼容接口的 AI 模型
- Android、iOS、Windows、macOS、Linux 与 Web 多端工程

## 本地优先

书籍、阅读进度和笔记默认保存在当前设备。项目当前不包含云端同步或 WebDAV 功能，数据由用户自行掌控。

## 开始开发

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

## 项目结构

```text
lib/
├── core/          # 阅读内核与定位模型
├── models/        # 书籍、书签、笔记等数据模型
├── pages/         # 应用页面与阅读界面
├── reader_core/   # 文档解析与 AI 请求层
├── services/      # 导入、存储、统计、朗读等服务
├── utils/         # 主题、布局、编码等工具
└── widgets/       # 通用组件
```

## 贡献

欢迎提交 Issue 和 Pull Request。提交前请至少运行格式化、静态分析和测试，并避免把 API Key、书籍文件或本地数据库提交到仓库。

## 许可证

[MIT](LICENSE) © [miloquinn](https://github.com/miloquinn)
