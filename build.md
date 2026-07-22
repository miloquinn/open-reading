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
| 2026-07-22 11:52 | 2.3.0 | 260722003 | 正式发布，Android split per ABI + GitHub 跨平台流水线 | Android 成功；跨平台待 Tag | armeabi-v7a `260723003`；arm64-v8a `260724003`；x86_64 `260726003` | 本地三套 APK 的包名、versionName、versionCode、APK v2 签名和共享 Origo 证书身份均已核验；SHA-256：v7a `DB26D67BE986D0AE8A893D6026D4FE2037574D49008367B0D2FA535C6A52EC37`，arm64 `A3EF10D31121D26D053EB1F2BD8B782A86841F8BA885E1B37DF590CCB7DF4087`，x86_64 `2B9D2C2AF48CF03523ACA46B1202C9437CBB28714345B77E40BF2ED10A88A35D`；Tag 推送后由 GitHub Actions 打包 Windows/Linux 与校验清单 |
| 2026-07-22 11:34 | 2.2.10 | 260722002 | Android release，split per ABI | 成功 | armeabi-v7a `260723002`；arm64-v8a `260724002`；x86_64 `260726002` | `build/app/outputs/flutter-apk/` 下三套 release APK；包名、versionName、versionCode、APK v2 完整签名和共享 Origo 证书身份均已核验；SHA-256：v7a `A0AAC489D5AEFEE1CE7D7EBA21FAAB5582C9190659414529A31577398AC41806`，arm64 `888E4D3E2FB007D1BBFF6DF6D1BCCB8DF4AB7D1A153380BCE94873715ECD06FF`，x86_64 `F2C16899059E99354CF76A288306D24B193D91022D545A36A124F759A436403B` |
| 2026-07-22 | 2.2.10 | 260722001 | Android release，split per ABI | 成功 | armeabi-v7a `260723001`；arm64-v8a `260724001`；x86_64 `260726001` | `build/app/outputs/flutter-apk/` 下三套 release APK；包名、versionName、versionCode、APK 完整性和共享 Origo 签名身份均已核验 |
