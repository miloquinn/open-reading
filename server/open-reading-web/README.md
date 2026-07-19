# 开元阅读官网与发行服务

`server/open-reading-web` 是 [open.xxread.top](https://open.xxread.top) 的 FastAPI
官网与安装包分发服务。它独立于 Flutter 客户端运行，负责公开下载页、版本元数据、
受控安装包导入、下载统计和维护者后台。

## 本地运行

要求 Python 3.12+。推荐使用仓库锁定的 `uv.lock`：

```bash
cd server/open-reading-web
uv sync --locked --extra dev
cp .env.example .env
uv run uvicorn app.main:create_app --factory --reload --port 3002
```

生产环境必须为 `OPEN_READING_DOWNLOAD_STATS_SECRET` 生成至少 32 字节的随机值，
不能直接使用公开占位文本：

```bash
openssl rand -hex 32
```

`OPEN_READING_ANDROID_CERT_SHA256` 必须配置为正式 Android 签名证书的 SHA-256
指纹。服务器还必须安装 Android SDK Build Tools，并确保 `aapt` 与 `apksigner`
可由 `open-reading` 服务用户执行；任一工具或证书配置缺失时，所有 APK 导入与
后台上传都会被拒绝，不能跳过签名校验。

GitHub OAuth 仅用于维护者后台。Client ID、Client Secret、管理员数字 ID 和登录名
都必须通过服务器环境文件配置；源码与示例配置不包含生产值。

## 公开更新 API

推荐客户端接口：

```text
GET /api/v1/releases/latest?platform=android&architecture=arm64-v8a&channel=stable
```

`abi` 可作为 `architecture` 的兼容参数。Android 必须明确提供其中一个参数，避免
把错误的 split APK 发给设备。响应是直接对象：

```json
{
  "schema_version": 1,
  "version": "2.2.0",
  "build_number": "14119",
  "platform": "android",
  "architecture": "arm64-v8a",
  "package_type": "apk",
  "channel": "stable",
  "release_notes": "...",
  "download_url": "https://open.xxread.top/download/file/<release-id>",
  "github_release_url": "https://github.com/miloquinn/open-reading/releases/tag/v2.2.0",
  "website_url": "https://open.xxread.top/download",
  "sha256": "...",
  "file_size": 123,
  "published_at": "2026-07-19T12:00:00Z",
  "mandatory": false
}
```

元数据接口按 IP 宽松限制为每分钟 120 次，下载短链按 IP 限制为每小时 30 次。
Caddy 直接提供 `/files/*`，Range 续传不会经过该限流器。进程内滑动窗口检查与
记账是原子的；过期 IP 桶会被清理，活跃 key 数量限制为 8192，超过后按最久未
使用淘汰，避免高基数 IPv6 来源耗尽 256 MiB 服务内存。

兼容接口仍保留：

- `GET /api/health`
- `GET /api/releases/latest`
- `GET /api/releases/latest/{platform}`
- `GET /api/releases`
- `GET /download/{platform}`
- `GET /download/file/{release_id}`

## 下载事件与隐私

每次下载短链命中时，服务端在 `download_events` 中记录发行 ID、请求 IP、IP 的
HMAC 摘要、User-Agent、来源和发生时间，并原子增加发行记录的下载次数。

- 原始 IP 与 User-Agent 仅供认证后的维护后台排障和统计使用。
- 每次写入、服务启动和统计查询都会清理 30 天前的事件明细。
- 公开 API 永远不返回 IP 或 User-Agent。
- 认证后的 `GET /api/v1/admin/download-stats?days=30` 返回总下载、独立 IP、
  按日期/发行聚合及最近 100 条受限明细。
- Caddy access log 同样最多滚动保留 30 天。
- 客户端无需发送设备 ID、账户信息或书籍数据。

`request_ip` 只使用 ASGI 的 `request.client.host`。生产 Uvicorn 仅信任来自
`127.0.0.1` 的 Caddy 代理头，应用不会直接信任任意客户端提交的
`X-Forwarded-For`。

## GitHub Actions 受控导入

Actions 完成 GitHub Release 后，把以下扁平目录上传到服务器。GitHub Release 本身
只包含 5 个安装包和 `SHA256SUMS.txt`；`release-manifest.json` 是镜像 job 在发布后
读取 GitHub 元数据生成的本地 staging 文件，不是 GitHub Release 资产：

```text
/tmp/open-reading-release-<run-id>-<attempt>/
├── release-manifest.json
├── SHA256SUMS.txt
└── <manifest 中声明的所有资产>
```

目录必须由专用低权限 SSH 用户 `open-reading-release` 创建，权限为 `0700`。
GitHub `release` Environment 使用以下 secrets，并配置 required reviewers；
`OFFICIAL_SITE_SSH_KNOWN_HOSTS` 必须预置
固定主机公钥，禁止关闭主机校验：

- `OFFICIAL_SITE_SSH_HOST`
- `OFFICIAL_SITE_SSH_PORT`
- `OFFICIAL_SITE_SSH_USER`
- `OFFICIAL_SITE_SSH_PRIVATE_KEY`
- `OFFICIAL_SITE_SSH_KNOWN_HOSTS`

将 `deploy/import_release.sh` 以 root 所有、`0755` 权限安装为：

```text
/usr/local/sbin/open-reading-import-release
```

sudoers 白名单示例（必须通过 `visudo` 校验）：

```sudoers
open-reading-release ALL=(root) NOPASSWD: /usr/local/sbin/open-reading-import-release *
```

sudoers 只允许专用发布用户调用这一固定 wrapper。wrapper 会验证调用者、严格
realpath、目录所有者、`0700` 权限和无符号链接，然后收回目录所有权，以
`open-reading` 服务用户执行导入，并无论成功失败都清理 staging 目录：

```bash
sudo -n /usr/local/sbin/open-reading-import-release \
  --source /tmp/open-reading-release-123-1 \
  --tag v2.2.0 \
  --repository miloquinn/open-reading \
  --manifest release-manifest.json
```

manifest schema v1 要求顶层 `build_number` 非空，并要求每个资产都提供自己的
`build_number`。Android split APK 必须写实际 versionCode；导入器强制通过
`aapt` 核对 `packageName=com.niki.xxread`、versionName 和 versionCode，并通过
`apksigner` 核对完整签名及正式证书 SHA-256。

导入器还会验证：

- tag、version、repository 与 GitHub Release URL 一致；
- 联网读取固定仓库与 tag 的 GitHub API，核对非草稿/非 stable prerelease、发布
  URL、发布时间、更新日志，以及 3 个 Android APK、Windows ZIP、Linux tar.gz
  的固定槽位与版本化命名；
- GitHub Release 资产集合必须恰好是上述 5 个安装包加 `SHA256SUMS.txt`，并核对
  每个资产的 uploaded 状态、大小、下载地址及 API 提供的 SHA-256 digest；本地
  `SHA256SUMS.txt` 必须与 GitHub 官方资产逐字节一致；网络或核验失败时拒绝导入；
- `SHA256SUMS.txt` 的键集合与 assets 完全相等；
- staging 根目录不存在任何未声明文件、子目录或符号链接；
- 文件大小、SHA-256、扩展名、平台/架构组合和文件签名合法；
- 同版本、平台、架构、渠道与包类型的同哈希导入幂等；不同哈希或构建号拒绝；
- stable latest 只允许同版本重激活或升级；一旦记录过更高 stable 版本，即使其后
  下架，也不能把较低版本重新设为 latest；
- 所有资产验证和落盘成功后，才在单个 SQLite 事务内切换 latest。

## 生产目录

部署主机必须预先安装 Python 3.12 与固定版本 `uv 0.11.8`，该版本与 GitHub
Actions 的 `UV_VERSION` 保持一致。发布脚本不会联网安装或升级 uv，也不会使用
普通 pip 重新解析依赖；远端先执行 `uv lock --check`，再执行
`uv sync --frozen --no-dev --python python3.12`。缺少 uv、版本不一致、`uv.lock`
与 `pyproject.toml` 不一致或同步失败时，发布会在切换 `current` 符号链接前终止。

```text
/srv/open-reading/
├── current -> code-releases/<timestamp>
├── code-releases/
├── releases/
├── data/releases.db
├── shared/.env
└── backups/
```

代码发布不会覆盖安装包、数据库、环境文件或备份。`deploy/publish.sh` 不包含真实
主机、SSH 用户或私钥路径；运行前必须显式设置 `DEPLOY_HOST` 和 `DEPLOY_USER`。
`deploy/backup.sh` 生成的是脱敏运维备份：删除下载事件、OAuth state 和后台会话，
并清空审计记录中的 IP 与 User-Agent；累计下载数仍保留在发行聚合字段中。

## 验证

```bash
cd server/open-reading-web
uv run --locked --extra dev ruff check app tests scripts
uv run --locked --extra dev pytest
```
