# 国际化（i18n）规范

本项目使用 Flutter 官方 `gen-l10n` 方案。配置见根目录 `l10n.yaml`。

## 目录结构

```
l10n.yaml                          # gen-l10n 配置（nullable-getter: false）
lib/l10n/
  app_en.arb                       # 模板文件（英文），含 @key 元数据
  app_zh.arb                       # 中文翻译，键集合必须与 en 一致
  app_localizations*.dart          # 生成代码，勿手改
lib/utils/localization_extension.dart  # context.l10n 扩展
l10n_untranslated.json             # 生成的缺翻译报告（已 gitignore，应保持 {}）
```

## 使用方式

```dart
import '../utils/localization_extension.dart';

Text(context.l10n.settings)              // 普通文案
Text(context.l10n.libraryPageOf(3, 10))  // 带占位符的文案
```

- `context.l10n` 返回非空 `AppLocalizations`（`nullable-getter: false`）。
- `part of` 文件不能单独 import，由其库文件统一引入扩展。
- 不要在 `initState` 里读取 l10n（此时 context 未就绪），在
  `didChangeDependencies` 或 `build` 中读取。

## 键名规范

- camelCase，按页面/功能加前缀：`settings*`、`library*`、`stats*`、
  `home*`、`reader*`、`import*`、`agreement*`、`tts*`。
- 通用词复用现有键：`cancel`、`confirm`、`delete`、`save`、`retry`…
- 单位类：`unitMinute`、`unitHour`、`unitBook`、`unitDay`。

## 新增文案流程

1. 在 `app_en.arb` 中添加键 + `@key` 元数据（description 必填，
   有插值时声明 placeholders 类型）。
2. 在 `app_zh.arb` 中添加同名键的中文翻译。
3. 运行 `flutter gen-l10n`（或直接 `flutter run`，`generate: true` 会自动生成）。
4. 确认 `l10n_untranslated.json` 内容为 `{}`（无缺翻译）。

带占位符示例：

```jsonc
// app_en.arb
"libraryDeleteConfirmMessage": "Delete \"{title}\"? The file will be permanently removed.",
"@libraryDeleteConfirmMessage": {
  "description": "Confirm dialog body when deleting a book",
  "placeholders": { "title": { "type": "String" } }
}
// app_zh.arb
"libraryDeleteConfirmMessage": "确定要删除《{title}》吗？文件将从设备中永久移除。"
```

## 禁止事项

- UI 代码中硬编码用户可见的中文/英文文案（`Text('设置')` ❌）。
- 手改 `app_localizations*.dart` 生成文件。
- 在 model / service 层返回硬编码显示文案 —— 应返回枚举或键，
  由 UI 层通过 `context.l10n` 解析（参考 `main.dart` 的 `_BootstrapError`）。
- `debugPrint`/日志/异常内部信息不需要国际化。

## 待迁移（历史遗留）

以下文件仍含硬编码中文，多为 service/model 层，需要把文案上移到 UI 层解析：

- `lib/services/books/book_import_service.dart`
- `lib/services/books/enhanced_txt_import_service.dart`
- `lib/reader_core/ai/ai_service.dart`
- `lib/services/ai/global_ai_reading_service.dart`
- `lib/models/book_note.dart`（类型名/颜色名/分享文本）
- `lib/utils/app_themes.dart`（主题显示名）
