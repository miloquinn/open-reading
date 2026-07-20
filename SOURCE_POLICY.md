# 第三方书源与内容权利政策

## 官方发行边界

Open Reading 官方发行版不预装、不内置、不推荐任何第三方书源，也不运营或分发官方书源
目录。项目提供的是本地优先的开源阅读软件，以及用于连接独立内容服务的 Open Reading
Source Protocol（ORSP）实现。

书源注册表首次安装时为空。每个书源地址都必须由用户在设备上主动输入添加。应用直接向
用户选择的独立服务发送请求，不通过开发者运营的内容代理、正文服务器或账号系统。

## 独立第三方责任

用户添加的书源及其内容由相应运营者独立提供和控制，与 Open Reading 开发者不存在运营、
代理、授权、背书或内容审核关系。ORSP 兼容性只表示接口可以按协议通信，不证明内容合法、
安全、准确或已取得授权。

书源运营者负责确认自己有权提供和传播相关内容。用户在添加书源前应审查其运营者、授权
依据、隐私政策和服务条款，并对自己的访问、下载、缓存、转换、朗读、分享及其他使用行为
负责。不得利用 Open Reading 或 ORSP 绕过 DRM、访问控制、认证、付费机制或实施侵权行为。

ORSP 1.3 支持运营者名称、联系入口、内容许可和权利声明元数据。客户端展示这些字段仅用于
提高透明度；字段缺失或运营者的自我声明均不构成 Open Reading 对其身份、授权或内容合法性
的认证、推荐或背书。

## 权利报告

本项目无法删除或控制用户自行添加的独立书源。针对第三方书源内容的投诉，应优先提交给
对应书源运营者、托管服务商或有管辖权的平台。

如果 Open Reading 官方仓库、安装包、文档或其他由项目维护者直接控制的位置意外包含了
涉嫌侵权的文件、默认书源地址或推荐链接，可以通过
[GitHub 权利报告表单](https://github.com/miloquinn/open-reading/issues/new?template=rights_report.yml)
提交。报告应
包含具体 URL 或文件路径、权利归属说明、请求采取的措施和可联系的报告人信息。涉及不宜
公开的个人信息或安全细节时，请使用仓库的 GitHub Security Advisory 私下报告。

维护者会核查项目能够控制的材料，并在必要时移除链接或文件。协议实现、格式校验或技术
兼容性测试不构成对第三方内容权利的认证。任何免责声明或责任限制均只在适用法律允许的
范围内生效。

---

# Third-Party Source and Content Rights Policy

The official Open Reading distribution does not preinstall, bundle, recommend,
or operate third-party book sources or an official source directory. Every
source address is entered by the user, and the app connects directly to that
independent service without a developer-operated content proxy.

Third-party source operators are responsible for the content they provide.
Users must review authorization and service terms before adding a source and
remain responsible for their own access and use. ORSP compatibility is a
technical statement, not a certification of legality or licensing.

ORSP 1.3 supports operator, contact, content-license, and rights-statement
metadata. The client displays these fields for transparency only. Missing
fields and operator-supplied statements are not verification, endorsement, or
certification by Open Reading.

Reports about independently operated source content should be directed to the
source operator or hosting provider. If a project-controlled repository,
package, document, or link unexpectedly contains infringing material or a
default source address, report the exact location through GitHub Issues. Use a
private GitHub Security Advisory when a report contains sensitive information.
Project maintainers will address material they actually control, to the extent
required by applicable law.
