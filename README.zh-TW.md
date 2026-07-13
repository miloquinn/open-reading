<div align="center">
  <img src="assets/images/app_icon.png" width="112" alt="開元閱讀圖示">
  <h1>開元閱讀 · Open Reading</h1>
  <p>本機優先、跨平台、支援開放書源的現代電子書閱讀器</p>
  <p><a href="README.en.md">English</a> · <a href="README.md">简体中文</a> · <strong>繁體中文</strong> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a></p>
</div>

開元閱讀是使用 Flutter 建構的開源電子書閱讀器。書籍、閱讀進度、書籤與筆記預設保留
在使用者裝置上，同時提供排版、朗讀、標註、統計、選用 AI 工具與開放書源功能。

## 不只是 WebView 外殼

核心閱讀頁採用**自研 Flutter 原生閱讀引擎**，不依賴 WebView 完成主要閱讀流程。章節
解析、`TextPainter` 精確測量、二分分頁、圖片混排、快取與閱讀錨點都在 Flutter 渲染
體系內完成，重新排版時也能依字符位置恢復閱讀進度。

## 主要功能

- 匯入 EPUB、PDF、TXT 與 ZIP，管理本機書庫；
- Flutter 原生排版、精確分頁、章節快取與閱讀位置恢復；
- 字型大小、行距、邊距、主題與分頁快取；
- 書籤、螢光標記、筆記、閱讀歷史與統計；
- 系統 TTS 文字朗讀；
- 連接相容書源並進行跨來源搜尋；
- 支援 OpenAI、Claude、Gemini、GLM、MiniMax 及相容 API；
- Android、iOS、Windows、macOS、Linux 與 Web 工程。

## 開放書源協議

線上書源透過獨立開源的 **Open Reading Source Protocol（ORSP）** 接入。協議定義發現、
搜尋、書籍詳情、章節目錄和正文介面。

**[前往書源協議開源倉庫](https://github.com/miloquinn/open-reading-source-protocol)**

協議僅適用於原創、公共領域或合法授權內容，請勿用於繞過存取控制或散布未授權作品。

## 開始開發

```bash
git clone https://github.com/miloquinn/open-reading.git
cd open-reading
flutter pub get
flutter run
```

歡迎提交 Issue、Pull Request 與翻譯。授權條款：[GNU AGPL-3.0](LICENSE)。修改版在散布或透過網路提供服務時，必須依 AGPL-3.0 提供對應原始碼。`v1.0.0` 及更早版本仍適用原有的 [MIT 授權](LICENSE-MIT-LEGACY)，詳見 [LICENSING.md](LICENSING.md)。
