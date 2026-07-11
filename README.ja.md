<div align="center">
  <img src="assets/images/app_icon.png" width="112" alt="Open Reading アイコン">
  <h1>Open Reading</h1>
  <p>ローカルファースト、クロスプラットフォーム、オープンな書籍ソースに対応した電子書籍リーダー</p>
  <p><a href="README.en.md">English</a> · <a href="README.md">简体中文</a> · <a href="README.zh-TW.md">繁體中文</a> · <strong>日本語</strong> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a></p>
</div>

Open Reading は Flutter で構築されたオープンソースの電子書籍リーダーです。書籍、
進捗、ブックマーク、ノートを標準で端末内に保持し、組版、読み上げ、注釈、読書統計、
任意の AI 機能、拡張可能な書籍ソースを提供します。

## 主な機能

- EPUB、PDF、TXT、ZIP のインポートとローカル書庫管理
- 文字サイズ、行間、余白、テーマ、ページングキャッシュ
- ブックマーク、ハイライト、ノート、履歴、統計
- システム TTS と設定可能な AI サービス
- Android、iOS、Windows、macOS、Linux、Web プロジェクト

## オープン書籍ソース

オンラインソースは **Open Reading Source Protocol（ORSP）** を使用します。検索、書籍情報、
章一覧、本文取得を共通 HTTP API として定義しています。

**[ORSP の仕様・OpenAPI・参照サーバーを見る](https://github.com/miloquinn/open-reading-source-protocol)**

ORSP はオリジナル、パブリックドメイン、または正式に許諾されたコンテンツを対象とします。

## 開発

```bash
git clone https://github.com/miloquinn/open-reading.git
cd open-reading
flutter pub get
flutter run
```

ライセンス：[MIT](LICENSE)。Issue、Pull Request、翻訳を歓迎します。
