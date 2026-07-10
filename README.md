<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d1117,50:1a1b26,100:0d1117&height=200&section=header&text=Open%20Reading&fontSize=50&fontColor=f7768e&fontAlignY=40&desc=%E5%B0%8F%E5%85%83%E9%98%85%E8%AF%BB%E5%99%A8%20%E2%80%94%20An%20Elegant%20Cross-Platform%20Ebook%20Reader&descSize=16&descAlignY=60&descAlign=50&animation=fadeIn" width="100%" />
</p>

<p align="center">
  <a href="https://github.com/KeloYuan/open-reading/releases"><img src="https://img.shields.io/github/v/release/KeloYuan/open-reading?style=for-the-badge&color=f7768e" /></a>
  <a href="https://github.com/KeloYuan/open-reading/stargazers"><img src="https://img.shields.io/github/stars/KeloYuan/open-reading?style=for-the-badge&color=e0af68" /></a>
  <img src="https://img.shields.io/badge/Flutter-3.35-blue?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-3.9-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Rust-Powered-da4326?style=for-the-badge&logo=rust&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" />
</p>

<p align="center">
  <b>优雅的 Flutter 跨平台电子书阅读器，支持多种格式，提供舒适的阅读体验。</b><br/>
  <i>An elegant cross-platform ebook reader — beautifully crafted with Flutter & Rust.</i>
</p>

---

## 📖 About

**Open Reading** (小元阅读器) 是 [小元读书 (Origo Reader)](https://github.com/KeloYuan/Origo-Reader) 项目的**开源跨平台版本**，基于 Flutter 构建，覆盖 Android、iOS、macOS、Windows、Linux 五个平台。

> 市面上的阅读器要么功能臃肿，要么界面丑陋。
> Open Reading 只想做一件事：**让你安静地读书，顺便好看一点。**

---

## ✨ Features

### 📖 Reading Experience
| Feature | Description |
|---------|-------------|
| 📄 **Multi-Format** | EPUB · PDF · TXT · ZIP 全格式支持 |
| 📐 **Smart Pagination** | 二分搜索算法精准分页，告别排版错乱 |
| 🔄 **Page Turn Modes** | 翻页 / 滑动 / 滚动 / 3D 仿真翻页 |
| 🎨 **Reading Themes** | 多种预设主题 + 自定义背景/字体颜色 |
| 🔤 **Typography Control** | 字号 · 行距 · 字距 · 缩进，精细调节 |
| 🌙 **Dark Mode** | 护眼暗色模式，深夜阅读不伤眼 |

### 🛠️ Smart Tools
| Feature | Description |
|---------|-------------|
| 🔖 **Bookmarks** | 一键添加书签，快速跳转 |
| ✏️ **Highlights & Notes** | 高亮标注 + 笔记，深度阅读 |
| 🔊 **TTS** | 文本朗读，支持语速/音量/音调调节 + 逐句高亮 |
| 📊 **Reading Stats** | 每日/每周/每月阅读统计，可视化图表 |
| ☁️ **WebDAV Sync** | 书籍 · 进度 · 书架 · 笔记全量云端同步 |

### 🔧 Tech Highlights
| Feature | Description |
|---------|-------------|
| 🦀 **Rust Core** | 核心解析引擎 Rust 编写，极致性能 |
| 📱 **5 Platforms** | Android · iOS · macOS · Windows · Linux |
| ⚡ **Riverpod** | 响应式状态管理，丝滑流畅 |
| 💾 **SQLite** | 本地数据持久化，零依赖云服务 |

---

## 📱 Supported Platforms

<table>
  <tr>
    <td align="center"><img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" /><br/><sub>API 21+</sub></td>
    <td align="center"><img src="https://img.shields.io/badge/iOS-007AFF?style=for-the-badge&logo=apple&logoColor=white" /><br/><sub>iOS 11+</sub></td>
    <td align="center"><img src="https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white" /><br/><sub>Apple Silicon</sub></td>
    <td align="center"><img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" /><br/><sub>Win 10+</sub></td>
    <td align="center"><img src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black" /><br/><sub>x64</sub></td>
  </tr>
</table>

---

## 📦 Tech Stack

```
Frontend    → Flutter 3.35 + Dart 3.9 + Material 3
State       → Riverpod 2.6
Database    → SQLite (sqflite)
Reader      → WebView (Foliate) + Rust Core Engine
```

---

## 🚀 Getting Started

```bash
# Clone
git clone https://github.com/KeloYuan/open-reading.git
cd open-reading

# Install dependencies
flutter pub get

# Run
flutter run
```

### Build

```bash
flutter build apk        # Android
flutter build ios        # iOS
flutter build macos      # macOS
flutter build windows    # Windows
flutter build linux      # Linux
```

---

## 📁 Project Structure

```
lib/
├── main.dart              # Entry point
├── models/                # Data models (books, chapters, bookmarks)
├── pages/                 # UI pages & home components
├── reader_core/           # Reader engine core (parser, document model)
├── services/              # Business services (import, DAO, sync, reading, TTS)
├── utils/                 # Themes, layout, encoding utilities
├── widgets/               # Reusable UI components
└── l10n/                  # Internationalization
```

---

## 🗺️ Roadmap

- [x] EPUB / PDF / TXT / ZIP 格式支持
- [x] 智能分页引擎（二分搜索）
- [x] 多种翻页模式（含 3D 仿真）
- [x] 多种阅读主题 + 自定义主题
- [x] 书签 · 高亮 · 笔记
- [x] TTS 文本朗读
- [x] 阅读统计图表
- [x] WebDAV 全量同步
- [ ] 🔥 书源搜索 & 在线阅读
- [ ] URL 导入书籍
- [ ] iCloud 同步
- [ ] 全局暗色模式
- [ ] 自定义字体导入

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

[MIT](LICENSE) © [KeloYuan](https://github.com/KeloYuan)

---

<p align="center">
  <b>小元阅读器</b> — <i>Reading, refined.</i><br/><br/>
  Part of <a href="https://github.com/KeloYuan/Origo-Reader">Origo Reader (小元读书)</a><br/><br/>
  If you like this project, give it a ⭐ — it keeps me going!
</p>
