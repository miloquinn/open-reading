# Open Reading 构建编号与构建记录

本文件同时定义正式构建号规则和保存构建台账。所有签名构建、可分发 release 构建及发布流水线构建都必须遵守；记录只追加或修正状态，不删除、不复用编号。

## 构建号规则

- `pubspec.yaml` 的 build number 固定使用 9 位十进制格式 `YYMMDDNNN`。
- `YYMMDD` 使用构建开始时的 Asia/Shanghai 日期；例如 2026-07-22 为 `260722`。
- `NNN` 是当天正式构建尝试序号，从 `001` 开始，每次递增 1，跨日重置为 `001`。
- 构建号在执行构建命令前占用并写入下方台账。成功、失败、中止的尝试都占用序号，任何情况下不得复用。
- 同一天的新构建必须先检查本文件已有的最大 `NNN`，使用下一个序号；不得仅根据产物目录或 Git 历史猜测。
- 版本写法为 `<versionName>+<YYMMDDNNN>`，例如 `2.2.10+260722001`。
- Flutter 的 Android `--split-per-abi` 会在基础构建号上增加 ABI 偏移：`armeabi-v7a +1000`、`arm64-v8a +2000`、`x86_64 +4000`。台账同时记录基础构建号和 APK 实际 versionCode。
- 普通 debug、本地测试、lint、静态分析和不产生可分发产物的编译验证不占用正式构建号。

## 每次构建流程

1. 完整读取当前机器对应的 release runbook、签名说明和本文件。
2. 确认 Asia/Shanghai 日期及当天最大序号，在台账新增状态为“构建中”的记录。
3. 将 `pubspec.yaml`、CHANGELOG 和其他公开版本记录更新为同一个 versionName 与基础构建号。
4. 执行签名或可分发 release 构建，不把凭据写入仓库、台账或构建日志。
5. 构建结束后立即回写状态、实际 versionCode、产物路径和验证结果；失败或中止必须记录原因。
6. 签名构建只有在包名、versionName、实际 versionCode、文件存在性和签名身份全部核验后才能记为成功。

## 构建台账

| 开始时间（Asia/Shanghai） | 版本 | 基础构建号 | 平台/类型 | 状态 | 实际版本码 | 产物与验证 |
| --- | --- | ---: | --- | --- | --- | --- |
| 2026-07-22 16:52 | 2.3.5 | 260722009 | GitHub 正式发布：Android split APK、Windows、Linux、macOS universal、公证、Web 部署与官网镜像 | 成功；Action 的 CDN 公网探测误报 403 | armeabi-v7a `260723009`；arm64-v8a `260724009`；x86_64 `260726009`；桌面/Web `260722009` | GitHub Latest Release `v2.3.5` 已发布 6 个安装包和 `SHA256SUMS.txt`；macOS universal 已通过 Developer ID、Hardened Runtime、Apple 公证、staple 与 Gatekeeper；官网六个平台/架构均为 2.3.5 且 Range 206，`read.xxread.top/version.json` 为 `2.3.5+260722009`。正式 Run `29911228236` 的构建、Release、官网镜像和实际 Web 部署成功，仅 Cloudflare 对 GitHub Runner 的冗余公网探测持续返回 403；后续工作流已将该 CDN 探测降级为告警。 |
| 2026-07-22 16:08 | 2.3.1 | 260722008 | Flutter Web 首次正式部署 | 构建中 | `260722008` | 为 `read.xxread.top` 构建可分发 Web 产物；包含 IndexedDB SQLite WASM/Worker 适配、GitHub Release 自动 SSH 原子部署与 Caddy 独立路由；产物与公网验证待回写 |
| 2026-07-22 14:59 | 2.3.1 | 260722007 | iOS App Store / TestFlight 隔离快照重建 | 构建中 | 待确认 | 以稳定提交 `c096c2b` 为基线，仅叠加 v2.3.1 发布元数据与 App Store 90683 权限修复；用于替代归档期间工作区发生并发源码修改的 `260722006`；产物与验证待回写 |
| 2026-07-22 14:41 | 2.3.1 | 260722006 | iOS App Store / TestFlight Archive | 上传成功但不作为候选 | `260722006` | `build/testflight/2.3.1-260722006/` 下保存 `.xcarchive`、App Store IPA、导出摘要与 Packaging 日志；IPA 内已确认 `NSLocationWhenInUseUsageDescription`，包名、版本、Cloud Managed Apple Distribution 签名、App Store provisioning、iCloud Production entitlement、隐私清单与 codesign 均通过；Transporter 于 14:53 上传成功且无错误，Delivery UUID `1c6db1f3-c0a4-4d17-8f6c-54beeb64b7fc`，IPA SHA-256 `C3ECE0C8E0BA40E9DE85169635C34A5E4E1FD6C969B7A6F76561672B67487255`；但归档期间共享工作区在 14:45–14:46 出现并发源码修改，无法证明产物来自单一已验证快照，因此不得选为 TestFlight/App Store 候选 |
| 2026-07-22 14:18 | 2.3.1 | 260722005 | Android release，split per ABI | 成功 | armeabi-v7a `260723005`；arm64-v8a `260724005`；x86_64 `260726005` | `build/app/outputs/flutter-apk/` 下三套 release APK，另复制 arm64 测试包为 `open-reading-2.3.1-260722005-arm64-v8a.apk`；包名、versionName、实际 versionCode、APK 完整签名和共享 Origo 证书身份均已核验；SHA-256：v7a `37C0E30AE6E0A45A94A0A0AE8593BEE94227CDED6B47C702CEDAFEAF64BEE02D`，arm64 `C1526EE61A9D35BCE54138175BBD0662B717F4BFC7BE5E884635ACD6C2A9BB8F`，x86_64 `C887242E347F705944F80FB800A8A8072C4F1B8FD43A30B9B88BC2C71A51FD59`；未执行安装、真机或完整发布验证 |
| 2026-07-22 12:40 | 2.3.0 | 260722004 | iOS App Store / TestFlight Archive | 成功 | `260722004` | `build/testflight/2.3.0-260722004/` 下保存 `.xcarchive`、App Store IPA 和导出摘要；包名 `com.niki.xxread`、版本 `2.3.0`、Cloud Managed Apple Distribution 签名、App Store provisioning、iCloud Production entitlement、隐私清单、非豁免加密声明与 codesign 完整性均已核验；IPA SHA-256 `E13C346FB51675B9277CA271F06A02EAAE887EE53707EACD23245EC72207C5FE` |
| 2026-07-22 11:52 | 2.3.0 | 260722003 | 正式发布，Android split per ABI + GitHub 跨平台流水线 | Android 成功；跨平台待 Tag | armeabi-v7a `260723003`；arm64-v8a `260724003`；x86_64 `260726003` | 本地三套 APK 的包名、versionName、versionCode、APK v2 签名和共享 Origo 证书身份均已核验；SHA-256：v7a `DB26D67BE986D0AE8A893D6026D4FE2037574D49008367B0D2FA535C6A52EC37`，arm64 `A3EF10D31121D26D053EB1F2BD8B782A86841F8BA885E1B37DF590CCB7DF4087`，x86_64 `2B9D2C2AF48CF03523ACA46B1202C9437CBB28714345B77E40BF2ED10A88A35D`；Tag 推送后由 GitHub Actions 打包 Windows/Linux 与校验清单 |
| 2026-07-22 11:34 | 2.2.10 | 260722002 | Android release，split per ABI | 成功 | armeabi-v7a `260723002`；arm64-v8a `260724002`；x86_64 `260726002` | `build/app/outputs/flutter-apk/` 下三套 release APK；包名、versionName、versionCode、APK v2 完整签名和共享 Origo 证书身份均已核验；SHA-256：v7a `A0AAC489D5AEFEE1CE7D7EBA21FAAB5582C9190659414529A31577398AC41806`，arm64 `888E4D3E2FB007D1BBFF6DF6D1BCCB8DF4AB7D1A153380BCE94873715ECD06FF`，x86_64 `F2C16899059E99354CF76A288306D24B193D91022D545A36A124F759A436403B` |
| 2026-07-22 | 2.2.10 | 260722001 | Android release，split per ABI | 成功 | armeabi-v7a `260723001`；arm64-v8a `260724001`；x86_64 `260726001` | `build/app/outputs/flutter-apk/` 下三套 release APK；包名、versionName、versionCode、APK 完整性和共享 Origo 签名身份均已核验 |
