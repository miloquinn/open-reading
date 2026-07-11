<div align="center">
  <img src="assets/images/app_icon.png" width="112" alt="Open Reading 아이콘">
  <h1>Open Reading</h1>
  <p>로컬 우선, 크로스 플랫폼, 공개 도서 소스를 지원하는 전자책 리더</p>
  <p><a href="README.en.md">English</a> · <a href="README.md">简体中文</a> · <a href="README.zh-TW.md">繁體中文</a> · <a href="README.ja.md">日本語</a> · <strong>한국어</strong> · <a href="README.es.md">Español</a></p>
</div>

Open Reading은 Flutter로 만든 오픈 소스 전자책 리더입니다. 도서, 진행 상황, 북마크와
메모를 기본적으로 사용자 기기에 보관하면서 조판, TTS, 하이라이트, 독서 통계, 선택적 AI
도구 및 확장 가능한 도서 소스를 제공합니다.

## 주요 기능

- EPUB, PDF, TXT, ZIP 가져오기와 로컬 서재 관리
- 글꼴 크기, 줄 간격, 여백, 테마와 페이지 캐시
- 북마크, 하이라이트, 메모, 기록과 통계
- 시스템 TTS 및 설정 가능한 AI 서비스
- Android, iOS, Windows, macOS, Linux, Web 프로젝트

## 공개 도서 소스

온라인 소스는 **Open Reading Source Protocol(ORSP)** 로 연결됩니다. 검색, 도서 정보,
목차와 본문을 공통 HTTP API로 정의합니다.

**[ORSP 명세, OpenAPI 및 참조 서버 보기](https://github.com/miloquinn/open-reading-source-protocol)**

ORSP는 창작물, 퍼블릭 도메인 및 정식 허가를 받은 콘텐츠를 위한 것입니다.

## 개발

```bash
git clone https://github.com/miloquinn/open-reading.git
cd open-reading
flutter pub get
flutter run
```

라이선스: [MIT](LICENSE). Issue, Pull Request와 번역을 환영합니다.
