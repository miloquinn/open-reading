# Open Reading Source Protocol v1.0

Open Reading Source Protocol（ORSP）是一套面向电子书与连载文本的开放 HTTP
协议。它把阅读器与具体内容站点解耦：阅读器只实现一次协议客户端，内容提供方或适配器
负责把自身数据转换成统一响应。

> 本协议用于接入原创、公共领域或已获授权的内容。实现者必须遵守内容版权、站点条款和
> 所在地区法律，不应使用本协议绕过访问控制或传播无授权内容。

## 1. 设计目标

- 一个阅读器可以连接多个互不相关的书源。
- 开发者可以直接搭建原生书源，也可以为现有合法服务编写适配网关。
- 书源差异停留在服务端，客户端不保存站点抓取规则、Cookie 或可执行脚本。
- 通过主版本号保证兼容性；v1 客户端接受所有 `1.x` 发现文档。
- v1 只定义公开、无需登录的 HTTP(S) 书源。认证扩展留给后续版本。

## 2. 服务发现

书源必须在以下地址发布 JSON 发现文档：

```text
GET /.well-known/open-reading-source.json
```

用户也可以直接向客户端提供发现文档的完整 URL。示例：

```json
{
  "protocol": "open-reading-source",
  "protocolVersion": "1.0",
  "id": "org.example.public-books",
  "name": "Example Public Books",
  "description": "Public-domain books maintained by Example.org",
  "apiBaseUrl": "https://books.example.org/api/",
  "iconUrl": "https://books.example.org/icon.png",
  "websiteUrl": "https://books.example.org/",
  "languages": ["zh-CN", "en"],
  "capabilities": ["search", "detail", "catalog", "content"]
}
```

必填字段：

| 字段 | 说明 |
| --- | --- |
| `protocol` | 固定为 `open-reading-source` |
| `protocolVersion` | 语义化版本；v1 客户端接受 `1.x` |
| `id` | 全局稳定标识，推荐反向域名 |
| `name` | 展示名称 |
| `apiBaseUrl` | API 根地址，必须是绝对 HTTP(S) URL |
| `capabilities` | 能力列表；v1 必须包含 `search` |

## 3. 通用约定

- 请求与响应编码为 UTF-8。
- JSON 响应使用 `application/json`。
- 客户端发送 `X-Open-Reading-Protocol: 1.0`。
- ID 是书源内部稳定、不透明的字符串。客户端不得推断 ID 格式。
- 时间使用 ISO 8601，例如 `2026-07-11T10:00:00Z`。
- 章节正文 `contentType` 仅允许 `text/plain`、`text/markdown`、`text/html`。
- HTML 正文必须是正文片段，不得包含脚本；客户端仍应在显示前执行清理。

## 4. 标准端点

所有路径都相对于发现文档中的 `apiBaseUrl`。

### 4.1 搜索

```text
GET /v1/search?q={query}&page=1&pageSize=20
```

```json
{
  "items": [
    {
      "id": "book-1001",
      "title": "示例书籍",
      "author": "示例作者",
      "description": "简介",
      "coverUrl": "https://books.example.org/covers/1001.jpg",
      "categories": ["文学"],
      "status": "completed",
      "latestChapter": "第三十章",
      "updatedAt": "2026-07-11T10:00:00Z"
    }
  ],
  "page": 1,
  "pageSize": 20,
  "total": 1,
  "hasMore": false
}
```

### 4.2 书籍详情

```text
GET /v1/books/{bookId}
```

响应使用与搜索项相同的书籍对象，可返回更完整的 `description` 和分类信息。

### 4.3 章节目录

```text
GET /v1/books/{bookId}/chapters
```

```json
{
  "items": [
    {
      "id": "chapter-1",
      "title": "第一章",
      "order": 1,
      "updatedAt": "2026-07-11T10:00:00Z"
    }
  ]
}
```

### 4.4 章节正文

```text
GET /v1/books/{bookId}/chapters/{chapterId}
```

```json
{
  "bookId": "book-1001",
  "chapterId": "chapter-1",
  "title": "第一章",
  "contentType": "text/plain",
  "content": "章节正文……"
}
```

## 5. 状态码

| 状态码 | 含义 |
| --- | --- |
| `200` | 请求成功 |
| `400` | 参数无效 |
| `404` | 书籍或章节不存在 |
| `429` | 请求过于频繁；可配合 `Retry-After` |
| `500` | 书源内部错误 |
| `503` | 书源暂时不可用 |

错误响应建议采用：

```json
{
  "error": {
    "code": "BOOK_NOT_FOUND",
    "message": "The requested book does not exist"
  }
}
```

## 6. 安全与部署

- 生产环境应使用 HTTPS。
- 对搜索参数、书籍 ID 和章节 ID 做长度限制与输入校验。
- 不要在发现文档或正文中返回密钥、Cookie、内部地址或可执行脚本。
- 面向 Web 客户端时，由书源自行配置合适的 CORS 策略。
- 建议设置速率限制、缓存头和最大正文尺寸。

## 7. 参考文件

- [OpenAPI 3.1 描述](book-source-openapi.yaml)
- [发现文档示例](examples/open-reading-source.json)
- [可运行的 Dart 示例书源](../tool/example_book_source_server.dart)

在仓库根目录启动示例书源：

```bash
dart run tool/example_book_source_server.dart
```

随后在 Open Reading 的“书源”页面添加 `http://127.0.0.1:8787`。Android
模拟器访问宿主机时通常需要改用 `http://10.0.2.2:8787`，并让服务监听可访问的网卡地址。

协议文本与参考实现随 Open Reading 项目按仓库许可证开放。建议第三方实现明确标注支持的
协议版本，例如 `Open Reading Source Protocol 1.0 compatible`。
