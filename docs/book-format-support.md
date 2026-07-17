# 本地书籍格式支持（Open Reading）

> 状态：架构基线（2026-07-18）  
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

| 格式 | 扩展名 | 选择器 | 当前能力 | 目标管线 | Lightink 对照 |
|------|--------|--------|----------|----------|----------------|
| TXT | `txt` | ✓ | **完整阅读** | 编码→切章→统一分页 | 完整主路径 |
| EPUB | `epub` | ✓ | **转文本后阅读** | epubx→章节文本→统一分页 | 完整（自研解析→TxtLayout） |
| PDF | `pdf` | ✓ | 元数据/导入为主 | 专用 PDF 渲染 | 不支持阅读排版 |
| MOBI/AZW/AZW3 | `mobi` `azw` `azw3` | ✓ | 元数据导入 | 解析→纯文本→统一分页 | 仅图标/MIME，无本地引擎 |
| FB2 | `fb2` | ✓ | 元数据导入 | XML→纯文本→统一分页 | 无 |
| RTF | `rtf` | ✓ | 元数据导入 | 去控制字→纯文本→统一分页 | 无 |
| Word | `doc` `docx` | ✓ | 元数据导入 | 抽正文→统一分页 | 无 |
| Comic | `cbz` `cbr` | ✓ | 元数据导入 | 按页图专用渲染 | 基本无 |
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

### 3.3 MOBI / AZW / AZW3（必须支持，分阶段）

Lightink **没有**完整本地引擎；Open Reading **明确要做**，避免用户只能「导入进书架却打不开正文」。

| 阶段 | 交付 |
|------|------|
| 现有 | 选择器可进、元数据/封面尽力提取 |
| P1 | 可靠抽纯文本 + 切章 + 统一分页可读 |
| P2 | 目录、封面、编码边界用例与回归测试 |

实现可选：成熟 Dart/原生解析库，或受限转换；**出口必须是章节纯文本**。

### 3.4 ZIP / RAR（容器，必须支持）

```text
zip/rar → 解压到临时/托管目录
        → 扫描内层（优先 txt/epub，其次其它已注册格式）
        → 单书或多书导入队列
```

- 实现完成前 **`acceptInFilePicker: false`**，避免选中却无法读  
- 实现后打开选择器，并写清「压缩包内需含可读格式」  

### 3.5 PDF（专用路径）

- 不与 `NativeTextPaginator` 混用  
- 保留 pdfx（或后续引擎）做页渲染 / 元数据  
- 与文字书设置面板可共用主题/亮度等，分页模型独立  

### 3.6 FB2 / RTF / DOC / DOCX（OR 扩展，Lightink 无）

一律：**进口转换 → 章节纯文本 → 统一分页**。  
复杂版式不承诺 1:1，以可读为主。

### 3.7 CBZ / CBR（漫画）

- 专用图页阅读器（左右翻页/竖滑）  
- 不走文本行盒  

---

## 4. 与现有代码的落点

| 职责 | 位置 |
|------|------|
| 格式注册表 | `lib/services/books/book_format_support.dart` |
| 选择器扩展名 | `BookFormatRegistry.pickerExtensions`（`book_import_source_service` / `book_import_service` 引用） |
| TXT 增强导入 | `enhanced_txt_import_service.dart` |
| EPUB | `book_import_service` + `epubx` + `epub_image_extractor_service` |
| 统一分页 | `core/reader/native_text_paginator.dart` |
| 本地阅读入口 | `pages/native_reader_page.dart` |
| 导入队列 | `book_import_*` + `import_book_page` |

**规则：** 新增/调整格式时：

1. 先改 `BookFormatRegistry`  
2. 再改解析/阅读适配器  
3. 更新本文与 `structure.md` / `Log.md`（若影响主流程）  
4. 补测试  

禁止在 `FilePicker` 处再手写一长串扩展名而不走注册表。

---

## 5. 实施优先级（建议）

| 优先级 | 项 | 原因 |
|--------|----|------|
| P0 | 注册表统一 + 文档（本文） | 避免分叉 |
| P0 | TXT / EPUB 阅读质量与 Lightink 体验对齐 | 主路径 |
| P1 | MOBI/AZW/AZW3 → 纯文本可读 | 用户刚需；Lightink 也做不到完整 |
| P1 | ZIP 容器导入 | 与 Lightink 对齐；实现成本低 |
| P2 | RAR 容器 | 需解压依赖与授权评估 |
| P2 | FB2 / RTF 正文可读 | OR 扩展优势 |
| P3 | DOC/DOCX 正文 | 依赖重、版式复杂 |
| P3 | PDF / 漫画阅读体验完善 | 专用 UI |

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
