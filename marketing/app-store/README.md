# App Store 与官网宣传素材

本目录保存可长期复用的 Open Reading 宣传素材，避免成品只留在个人桌面或临时目录。

## 目录

- `screenshots/`：六张精选原始应用截图，统一为 1216×2640，保留真实状态栏和应用界面。
- `promotional/iphone-6.5/`：六张 1242×2688 的 App Store 宣传图及整套预览，符合 iPhone 6.5 英寸截图槽位要求。
- 正式应用图标继续使用 [`assets/images/app_icon.png`](../../assets/images/app_icon.png)，不在本目录重复保存。
- 官网加载的压缩 WebP 位于独立仓库 `miloquinn/open-reading-web` 的 `app/static/product/`，由本目录的精选截图派生。

## 素材对应关系

| 原始截图 | 宣传图 | 主要内容 |
| --- | --- | --- |
| `screenshots/home.jpg` | `01-daily-reading.png` | 首页、目标与阅读计划 |
| `screenshots/library.jpg` | `02-library.png` | 书库与阅读进度 |
| `screenshots/reader.jpg` | `03-immersive-reading.png` | 正文阅读 |
| `screenshots/page-turn.jpg` | `04-page-turn.png` | 仿真翻页 |
| `screenshots/personalization.jpg` | `05-personalization.png` | 主题、字体与排版 |
| `screenshots/stats.jpg` | `06-reading-stats.png` | 阅读统计与成就 |

## 维护规则

- 产品界面发生明显变化时，应同时更新原始截图、App Store 宣传图和官网 WebP。
- App Store 图必须保持 1242×2688，不得直接拉伸原始截图。
- 官网静态资源或 CSS 结构发生不兼容变化时，模板 URL 必须更新版本查询参数，避免旧缓存与新 HTML 混用。
- 不在素材中加入尚未实现的功能、虚构 UI 或无法验证的设备声明。
