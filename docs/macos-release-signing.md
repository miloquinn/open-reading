# macOS GitHub Release 签名与公证

macOS 正式包由 `.github/workflows/release.yml` 的可选 `macos` job 构建。该 job 仅在仓库变量 `MACOS_RELEASE_ENABLED` 严格等于 `true` 时运行；未启用时，现有 Android、Windows、Linux 和官网镜像流程保持不变。

## 发布产物

- 文件名：`OpenReading-macOS-universal-<version>.zip`
- 架构：Apple Silicon `arm64` + Intel `x86_64`
- 应用身份：`com.niki.xxread`
- 签名：Developer ID Application
- 安全：Hardened Runtime、Apple Notary Service、公证票据 stapling
- 校验：bundle 版本、双架构、`codesign --strict`、`stapler validate`、Gatekeeper `spctl`

ZIP 内是已经签名并 stapled 的 `.app`。ZIP 本身只作为保留扩展属性和资源分叉的传输容器。

## GitHub `release` Environment

在已有 `release` Environment 中增加以下 Secrets：

```text
MACOS_DEVELOPER_ID_P12_BASE64
MACOS_DEVELOPER_ID_P12_PASSWORD
MACOS_NOTARY_KEY_ID
MACOS_NOTARY_ISSUER_ID
MACOS_NOTARY_PRIVATE_KEY_BASE64
```

- P12 必须包含 `Developer ID Application` 证书及其私钥，不能使用 Apple Distribution 证书代替。
- 两个 Base64 Secret 都必须是原始文件字节的无换行标准 Base64，不能包含文件路径或说明文字。
- 公证凭据使用 App Store Connect API Key：Key ID、Issuer ID 和对应 `.p8` 私钥。
- 工作流只把材料写入 runner 临时目录和临时 keychain，并在 job 结束时删除。

## 启用顺序

1. 确认 `miloquinn/open-reading-web` 已部署 manifest 驱动的动态资产校验器，并允许：

   ```text
   (macos, zip, universal) -> OpenReading-macOS-universal-{version}.zip
   ```

2. 确认官网导入器仍会严格校验平台、包类型、架构、规范文件名、GitHub Release 资产集合和 SHA-256；资产总数不得重新锁死。
3. 写入上述五个 GitHub Environment Secrets。
4. 设置仓库变量：

   ```bash
   gh variable set MACOS_RELEASE_ENABLED \
     --repo miloquinn/open-reading \
     --body true
   ```

5. 只对新的版本 Tag 启用。已经发布的 Tag 受不可变资产集合保护，不能在重跑时追加 macOS 包。

若官网仍使用固定资产数量校验，不得打开变量；否则 GitHub Release 会生成 macOS 资产，但官网镜像导入会失败。

## 关闭

需要临时停用 macOS 构建时，将仓库变量改为 `false`。Secrets 可以继续保留在受审批保护的 `release` Environment 中：

```bash
gh variable set MACOS_RELEASE_ENABLED \
  --repo miloquinn/open-reading \
  --body false
```
