# 模板上下文约定

后端渲染模板时建议提供以下上下文。模板对多数展示字段有空值回退，但鉴权与表单字段应由后端明确传入。

- 全局：`current_year`、可选 `admin_user`。
- `home.html`：无需必填上下文。
- `download.html`：`platforms`（每项包含 `key|slug`、`name`、`package_types`、可选 `latest`），可选 `recommended_platform`、`github_releases_url`。
- `releases.html`：`releases`、`platforms`，可选 `selected_platform`、`selected_channel`、`pagination`。
- `release_detail.html`：`release`。`release_notes_html` 必须是后端经过安全 Markdown 渲染/清洗后的 HTML，否则仅传 `release_notes` 纯文本。
- `login.html`：`oauth_enabled`。
- 后台全局：`admin_user`、`csrf_token`。
- `admin/dashboard.html`：`stats`、`platforms`、`recent_releases`。
- `admin/upload.html`：`platforms`、`form`、可选 `errors`、`package_types`、`architectures`、`max_upload_size_display`。每个平台如需前端联动，应提供 JSON 字符串字段 `package_types_json` 与 `architectures_json`。

Release 常用字段：`id`、`platform`、`version`、`build_number`、`channel`、`package_type`、`architecture`、`file_size`、`file_size_display`、`sha256`、`release_notes`、`release_notes_excerpt`、`github_release_url`、`stored_filename`、`is_latest`、`is_available`、`published_at`、`published_at_display`、`download_count`。
