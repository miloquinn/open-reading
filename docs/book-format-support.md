# 本地书籍格式支持（Open Reading）

> 状态：架构基线（2026-07-18），能力矩阵更新（2026-07-26：Kindle 正文 / CBZ 漫画 / HTML / Markdown 已接线；CBT 可读、CBR/CB7 按文件头嗅探）  
> 代码单一事实来源：`lib/services/books/book_format_support.dart`  
> Lightink 对照资料：`F:\work\lightink-reverse\docs\09-reader-complete.md`（及 05/06）

本文约定：**Open Reading 将来要支持哪些格式、各自怎么进阅读器、与 Lightink 如何对齐**。  
实现可分阶段，但**不得再散落多份互相矛盾的扩展名列表**。

---

## 1. 目标架构（必须遵守）

```text
文件
  ├─ 文字书进口（TXT / EPUB / FB2 / RTF / DOC… / Kindle 文本化后）
  │     → 章节纯文本 List<Chapter>
  │     → NativeTextPaginator（统一行盒分页）
  │     → 翻页：无动画 / 水平滑动 / 仿真 curl / 竖滑
  │
  ├─ 容器（ZIP / RAR）
  │     → 解压 → 识别内层 → 走对应进口
  │
  └─ 专用渲染（PDF 页、CBZ/CBR 图页）
        → 不走文本行盒；独立阅读适配器
```

与 Lightink 一致的核心原则：

1. **文字书只有一套分页引擎**（OR：`NativeTextPaginator`；Lightink：`TxtLayout`）。  
2. **EPUB 不是 WebView 排版**，而是解析后抽章节文本再分页。  
3. **翻页动画不重跑分页**，只切换已分好的页 / 快照。  
4. **容器不排版**，只负责展开。

---

## 2. 格式能力矩阵

| 格式 | 扩展名 | 选择器 | 当前能力 | 管线 | Lightink 对照 |
|------|--------|--------|----------|----------|----------------|
| TXT | `txt` | ✓ | **完整阅读** | 编码→切章→统一分页 | 完整主路径 |
| EPUB | `epub` | ✓ | **转文本后阅读** | epubx→章节文本→统一分页 | 完整（自研解析→TxtLayout） |
| PDF | `pdf` | ✓ | **专用渲染阅读**（Linux 除外） | PdfReaderPage 按页位图渲染（pdfx） | 不支持阅读排版 |
| MOBI/AZW/AZW3 | `mobi` `azw` `azw3` | ✓ | **转文本后阅读**（无 DRM；Web 端不放行） | kindle_unpack→XHTML→EPUB 同款章节转换→统一分页 | 仅图标/MIME，无本地引擎 |
| FB2 | `fb2` | ✓ | **转文本后阅读** | section 切章→纯文本→统一分页 | 无 |
| RTF | `rtf` | ✓ | **转文本后阅读** | 去控制字→纯文本→统一分页 | 无 |
| Word (DOCX) | `docx` | ✓ | **转文本后阅读** | document.xml 抽正文→统一分页 | 无 |
| Word (DOC) | `doc` | ✓ | 元数据导入 | 无纯 Dart 方案，暂不读 | 无 |
| HTML | `html` `htm` `xhtml` | ✓ | **转文本后阅读** | 按标题切章→统一分页 | 无 |
| Markdown | `md` `markdown` | ✓ | **转文本后阅读** | 去标记→TXT 章节规则 | 无 |
| Comic (CBZ) | `cbz` | ✓ | **专用漫画阅读** | ComicReaderPage 按页图渲染 | 基本无 |
| Comic (CBT) | `cbt` | ✓ | **专用漫画阅读** | TAR 容器→同一 ComicReaderPage | 无 |
| Comic (CBR) | `cbr` | ✓ | **按文件头尝试阅读**（实为 ZIP/TAR 可读；真 RAR 提示转 CBZ） | 容器嗅探→ComicReaderPage | 基本无 |
| Comic (CB7) | `cb7` | ✓ | 按文件头尝试阅读（实为 ZIP/TAR 可读；真 7z 提示转 CBZ） | 容器嗅探→ComicReaderPage | 无 |
| ZIP | `zip` | 计划中 | **planned** | 解压→内层分流 | 有 ZipDecoder 容器 |
| RAR | `rar` | 计划中 | **planned** | 解压→内层分流 | 有 `unrar_file` |

能力枚举见代码：`BookFormatCapability`  
（`fullReader` / `convertThenLayout` / `container` / `metadataImport` / `planned` / `unsupported`）

---

## 3. 各格式目标行为

### 3.1 TXT（已具备，持续对齐）

```text
bytes → 编码探测 → 章节规则切章 → NativeTextPaginator → 阅读器
```

应对齐 / 可增强（参考 Lightink）：

- 章节规则可配置（`ChapterMatchRule` 一类）  
- 首行缩进、段距、`lineHeight` 与可选额外行距  
- 进度用字符 offset / CanonicalLocator，重排不丢位置  

### 3.2 EPUB（已具备进口，统一分页边界要对齐）

```text
.epub → ZIP/OPF/spine → 每章 XHTML → 纯文本
      → NativeTextPaginator（与 TXT 同一引擎）
```

- 目录来自 spine / nav / NCX  
- 封面单独抽取（已有 `epub_image_extractor`）  
- **正文主路径不走 WebView**  
- 图文混排：后续增量；首期保证纯文本阅读质量  

### 3.3 MOBI / AZW / AZW3（已接线，2026-07-26）

基于 `kindle_unpack`（纯 Dart，PalmDB → EXTH → PalmDOC/HUFF-CDIC 解压 → KF8 XHTML 拼接）：

- **导入**：`_extractMobiMetadata` 走 `parseKindleMetadata`，取 EXTH 真实书名/作者/简介/语言/ISBN/主题与内嵌封面；DRM 只影响正文，元数据/封面仍可用。Kindle 文件全量读取（EXTH 封面在文件尾部，禁止 10MB 截断）。
- **阅读**：`native_reader_page` 的 `_parseKindleChapters`（compute isolate）→ KF8 skeleton 分段成章 / MOBI7 按 `<mbp:pagebreak>` 切章 → `recindex`/`kindle:embed` 图片引用重写（`rewriteKindleImageRefs`）→ 与 EPUB 共用 `_chapterMapFromHtmlDocument`（样式块 + 内嵌图片）→ 统一分页。
- **DRM**：抛 `KindleDrmException` → 阅读器展示本地化提示（`readerKindleDrmProtected`）。
- **Web**：`kindle_unpack` 依赖 dart:io，Web 端为安全桩，`NativeReaderService` 不放行。
- 解析器文件：`kindle_book_parser{,_types,_io,_stub}.dart`。

### 3.4 ZIP / RAR（容器，必须支持）

```text
zip/rar → 解压到临时/托管目录
        → 扫描内层（优先 txt/epub，其次其它已注册格式）
        → 单书或多书导入队列
```

- 实现完成前 **`acceptInFilePicker: false`**，避免选中却无法读  
- 实现后打开选择器，并写清「压缩包内需含可读格式」  

### 3.5 PDF（专用路径，已接线 2026-07-26）

- `PdfReaderPage`（`pages/reader/pdf_reader_page.dart`）：pdfx `PdfDocument` 打开，
  按页渲染 PNG 位图（屏幕像素密度自适应、白底、最大宽 2160px），
  **渲染严格串行**（Android 不允许并行渲染），LRU 缓存 5 页 + 相邻页预载。  
- UI 骨架与 CBZ 漫画共用 `paged_image_reader.dart`（翻页/缩放/跳页/进度/点击区域/阅读方向/背景色/音量键/屏幕常亮）。  
- 平台：Android / iOS / macOS / Windows / Web（pdf.js 已在 `web/index.html` 配置）；
  **pdfx 无 Linux 实现**，Linux 端打开提示 `readerPdfLinuxUnsupported`。  
- 不与 `NativeTextPaginator` 混用；进度存 `currentPage`（页索引）。  

### 3.6 FB2 / RTF / DOC / DOCX（OR 扩展，Lightink 无）

一律：**进口转换 → 章节纯文本 → 统一分页**。  
复杂版式不承诺 1:1，以可读为主。

### 3.7 CBZ / CBT / CBR / CB7（漫画）

- CBZ：**已接线**（2026-07-26）。`ComicReaderPage`（`pages/reader/comic_reader_page.dart`）+ `comic_book_parser.dart`：isolate 解 ZIP 目录建页索引（数字感知排序、过滤 __MACOSX/隐藏文件）、按需解压单页、LRU 页缓存与相邻页预载、双击/双指缩放（缩放中锁翻页）、进度写回 `currentPage`。不走文本行盒。  
- **共享控制层**（2026-07-26）：`paged_image_reader.dart` 为漫画与 PDF 提供统一控制层——共享 3×3 点击区域（`reader_tap_zones`，RTL 下镜像列）、Android 音量键翻页与屏幕常亮、上/下一页按钮、进度滑条、跳页输入；`paged_image_reader_settings.dart` 持久化按书阅读方向（日漫 RTL）与全局页面背景色（黑/灰/白）。  
- **容器嗅探**（2026-07-26）：所有漫画格式打开与导入时按文件头识别真实容器（ZIP 前缀魔数 / `Rar!` / 7z 魔数 / offset 257 的 `ustar`），扩展名只作无魔数时的兜底。市面上大量 CBR/CB7 实为 ZIP 改名，识别后直接走 CBZ 同款管线。  
- CBT：**已接线**。TAR 容器由 `archive` 的 `TarDecoder` 解包，页索引/解压/阅读与 CBZ 完全共用；旧式 V7 TAR 无 ustar 魔数时按扩展名兜底。  
- CBR / CB7：真实容器为 RAR/7z 时无纯 Dart 解码，`comic_book_parser` 抛 `ComicArchiveUnsupportedException`，阅读页展示本地化提示（真 RAR→`readerComicCbrUnsupported`，其余→`readerComicArchiveUnsupported`）；元数据与封面在容器可解包时照常提取，否则回退估算值。  

---

## 4. 与现有代码的落点

| 职责 | 位置 |
|------|------|
| 格式注册表 | `lib/services/books/book_format_support.dart` |
| 选择器扩展名 | `BookFormatRegistry.pickerExtensions`（`book_import_source_service` / `book_import_service` 引用） |
| TXT 增强导入 | `enhanced_txt_import_service.dart` |
| EPUB | `book_import_service` + `epubx` + `epub_image_extractor_service` |
| 统一分页 | `core/reader/native_text_paginator.dart` |
| 本地阅读入口 | `pages/reader/native_reader_page.dart` |
| 导入队列 | `book_import_*` + `pages/library/import_book/import_book_page.dart` |

**规则：** 新增/调整格式时：

1. 先改 `BookFormatRegistry`  
2. 再改解析/阅读适配器  
3. 更新本文与 `structure.md` / `Log.md`（若影响主流程）  
4. 补测试  

禁止在 `FilePicker` 处再手写一长串扩展名而不走注册表。

---

## 5. 实施优先级（建议）

| 优先级 | 项 | 状态 / 原因 |
|--------|----|------|
| P0 | 注册表统一 + 文档（本文） | ✅ |
| P0 | TXT / EPUB 阅读质量与 Lightink 体验对齐 | 主路径，持续 |
| P1 | MOBI/AZW/AZW3 正文可读 | ✅ 2026-07-26（kindle_unpack） |
| P2 | FB2 / RTF / DOCX / HTML / Markdown 正文可读 | ✅（简化排版） |
| P3 | CBZ 漫画阅读 | ✅ 2026-07-26（ComicReaderPage） |
| P3 | CBT 漫画 + CBR/CB7 文件头嗅探 | ✅ 2026-07-26（改名 ZIP/TAR 可读；真 RAR/7z 提示转 CBZ） |
| P1 | ZIP 容器导入 | 待做；与 Lightink 对齐，实现成本低 |
| P2 | 真 RAR 容器解压 | 待做；需平台解压依赖与授权评估 |
| P3 | PDF 应用内阅读 | ✅ 2026-07-26（PdfReaderPage；Linux 待引擎支持） |
| P3 | DOC（旧版二进制）正文 | 无纯 Dart 方案，暂不做 |

---

## 6. Lightink 不支持、OR 仍要做的

- PDF 应用内阅读  
- MOBI/AZW3 **完整**正文阅读  
- FB2 / RTF / Office 文本化  
- CBZ/CBR 漫画  

Lightink 已验证、OR 应对齐的：

- TXT / EPUB → **统一文本分页**  
- ZIP / RAR → **容器再分流**  
- 仿真翻页与分页解耦（另见 lightink-reverse 移植包）  

---

## 7. 验收清单（格式相关功能完成时）

- [ ] 扩展名只来自 `BookFormatRegistry`  
- [ ] TXT/EPUB 打开后分页与进度稳定  
- [ ] 新文字格式最终调用 `NativeTextPaginator`（或明确 documented 例外）  
- [ ] 容器包内嵌套 TXT/EPUB 可导入  
- [ ] 选择器不出现「能选不能读」的 planned 格式（或明确提示）  
- [ ] `docs/book-format-support.md` 与代码能力级别一致  

---

*参考逆向：`lightink-reverse` docs 05、06、09；不把对方闭源实现当授权源码拷贝。*
