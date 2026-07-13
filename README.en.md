<div align="center">
  <img src="assets/images/app_icon.png" width="112" alt="Open Reading icon">
  <h1>Open Reading</h1>
  <p>A local-first, cross-platform ebook reader with an open book-source ecosystem.</p>

  <p>
    <strong>English</strong> · <a href="README.md">简体中文</a> ·
    <a href="README.zh-TW.md">繁體中文</a> · <a href="README.ja.md">日本語</a> ·
    <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a>
  </p>

  <p>
    <a href="https://open.xxread.top/"><strong>Open Reading website</strong></a> ·
    <a href="https://community.xxread.top/">Xiaoyuan Reader Community</a> ·
    <a href="https://xxread.top/">Xiaoyuan Reader (iOS only)</a>
  </p>

  <p>
    <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-2ea44f" alt="MIT License"></a>
    <img src="https://img.shields.io/badge/Reader_Engine-Flutter_Native-0ea5e9" alt="Flutter Native Reader Engine">
    <img src="https://img.shields.io/badge/Core_Reader-No_WebView-f97316" alt="Core Reader Without WebView">
    <a href="https://github.com/miloquinn/open-reading-source-protocol"><img src="https://img.shields.io/badge/Book_Source-Open_Protocol-7c3aed" alt="Open Reading Source Protocol"></a>
  </p>
</div>

---

Open Reading is an open-source ebook reader built with Flutter. It keeps books,
progress, bookmarks, and notes on the user's device by default while providing
careful typography, TTS, annotations, reading statistics, optional AI tools,
and community-extensible book sources.

## Projects and websites

| Name | Role | Website |
| --- | --- | --- |
| Open Reading | The open-source, cross-platform reader maintained in this repository | [open.xxread.top](https://open.xxread.top/) |
| Xiaoyuan Reader | The user-facing reading product, currently available only on iOS | [xxread.top](https://xxread.top/) |
| Xiaoyuan Reader Community | A community for reading, writing, and discussion | [community.xxread.top](https://community.xxread.top/) |

## Not a WebView wrapper — a native Flutter reading engine

Many cross-platform readers hand EPUB HTML to a WebView and build the reading
experience around a browser container. Open Reading takes the harder route:
its core reader is a custom **Flutter-native rendering and pagination engine**.

Chapter parsing, styled text measurement, pagination, mixed image content,
reading anchors, table-of-contents navigation, and layout restoration all stay
inside Flutter's rendering system. The core reading path does not depend on a
WebView, so gestures, themes, state, and animation remain native to the app.

The engine includes:

- real layout measurement with Flutter `TextPainter` and binary-search pagination;
- layout signatures derived from typography, margins, and viewport dimensions;
- in-memory pagination caches and chapter-level lazy loading;
- native EPUB chapter, style, and image parsing plus indexed text chapters;
- character-offset anchors that survive repagination;
- integrity assertions ensuring pagination neither drops nor duplicates text.

This is not a webpage placed inside an app. It is native reading infrastructure
with room for deeper performance, typography, and interaction work.

> [!IMPORTANT]
> Online sources use the independently maintained **Open Reading Source
> Protocol (ORSP)**. Visit the [protocol repository](https://github.com/miloquinn/open-reading-source-protocol)
> for the specification, OpenAPI definition, schemas, and reference server.

## Highlights

| Area | Capabilities |
| --- | --- |
| Local reading | Import EPUB, PDF, TXT, and ZIP; manage a local library and progress |
| Native engine | Custom Flutter layout, precise pagination, reading anchors, and chapter caches without WebView in the core reader |
| Reading UI | Typography, spacing, margins, themes, layouts, and pagination cache |
| Notes | Bookmarks, highlights, notes, history, and reading statistics |
| Accessibility | System text-to-speech with reading-state preservation |
| Open sources | Add ORSP-compatible services and search enabled sources together |
| AI | Configurable OpenAI, Claude, Gemini, GLM, MiniMax, and compatible APIs |
| Platforms | Android, iOS, Windows, macOS, Linux, and Web projects |

## Local first

Local reading does not require an account or a developer-operated cloud
service. Network features such as AI and book sources are explicitly enabled
and configured by the user. Cloud sync and WebDAV are not currently built in.

## Open book sources

ORSP defines standard discovery, search, book-detail, chapter-catalog, and
chapter-content endpoints. Reader apps implement the protocol once; source
developers may use any server language or framework.

- Repository: [miloquinn/open-reading-source-protocol](https://github.com/miloquinn/open-reading-source-protocol)
- Version: `1.1` discovery candidate
- Intended content: original, public-domain, or properly licensed works

Run the local example source:

```bash
dart run tool/example_book_source_server.dart
```

## Development

Requires Flutter 3.x and Dart `>=3.4.0 <4.0.0`.

```bash
git clone https://github.com/miloquinn/open-reading.git
cd open-reading
flutter pub get
flutter run
```

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Project layout

```text
lib/book_sources/  ORSP models, client, and source registry
lib/core/          Reading engine and position models
lib/pages/         Library, sources, settings, and reader screens
lib/reader_core/   Document parsing and AI request layer
lib/services/      Import, storage, statistics, and TTS services
test/              Unit and source end-to-end tests
tool/              Local development tools and example source
```

## Contributing and responsible use

Issues, pull requests, translations, platform work, and ORSP implementations
are welcome. Do not commit API keys, private databases, book files, or content
you are not authorized to distribute. Open Reading does not provide or host
pirated content, and ORSP must not be used to bypass access controls or terms.

## License

[MIT](LICENSE) © [miloquinn](https://github.com/miloquinn)
