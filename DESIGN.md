# Design

## Source of truth

- Status: Implemented baseline
- Last refreshed: 2026-07-22
- Primary product surfaces: 首页、书库、阅读器、阅读统计、设置，以及“数据与同步 / WebDAV”页面。
- Evidence reviewed: `README.md`、`structure.md`、`lib/pages/settings/settings_page.dart`、`lib/services/core/database_service.dart`、`lib/services/core/app_settings_service.dart`、`lib/services/books/`、`lib/book_sources/`、现有导入与存储实现，以及 Git 历史中 2026-07-11 移除的旧 WebDAV 同步实现。
- Feature specifications: `docs/webdav-sync-design.md`（同步协议与数据架构）、`docs/webdav-sync-ux-design.md`（页面、交互、文案与状态流）。

## Brand

- Personality: 开放、克制、可靠，以阅读内容为中心，不把基础功能包装成账号体系或平台锁定。
- Trust signals: 本地优先、用户自有存储、同步范围透明、可验证的最近同步状态、明确的数据删除边界。
- Avoid: 强制登录、模糊的“云端已保存”文案、默认上传书籍原文件、用成功动画掩盖部分失败、把服务器错误直接暴露成技术堆栈。

## Product goals

- Goals: 通过用户自己的 WebDAV 在多设备间同步阅读进度、书架元数据、书签、笔记和阅读统计；可选同步本地书籍原文件；断网时继续本地使用。
- Non-goals: 自建 Open Reading 云账号、多人协作、实时共同编辑、把缓存和设备路径复制到其他设备、首版提供端到端加密或后台常驻同步。
- Success signals: 两台设备离线修改后可无损合并；重复同步幂等；新设备可完整恢复已选择的数据域；同步失败不阻断阅读；用户能判断最后一次成功时间和待上传状态。

## Personas and jobs

- Primary personas: 同时使用手机与电脑阅读的用户；使用 NAS、Nextcloud 或自建 WebDAV 的隐私敏感用户；需要迁移设备的长期用户。
- User jobs: 在另一台设备继续阅读；保留书签和笔记；恢复书架；选择是否上传版权或隐私敏感的书籍文件；诊断为什么没有同步成功。
- Key contexts of use: 网络不稳定、设备时钟不完全一致、服务端实现差异、应用被系统挂起、远端已有其他设备数据。

## Information architecture

- Primary navigation: 设置页新增“数据与同步”分区，入口为“WebDAV 同步”。
- Core routes/screens: WebDAV 概览页、首次配置四步流程、同步内容页、书籍文件同步页、同步活动与错误详情、危险操作确认；书库卡片和多选模式直接提供单本/批量上传下载。
- Content hierarchy: 当前状态与主要操作优先；连接信息其次；同步范围和自动同步策略再次；诊断与危险操作置底。

## Design principles

- Local first: 本地数据库和文件始终可独立工作，远端是同步媒介而不是运行依赖。
- Safe by default: 首次连接默认合并；书籍原文件默认不上传；HTTP 默认拒绝；清除本机配置不删除远端数据。
- Explain state: 区分“正在同步”“同步完成”“有待上传变更”“部分失败”“需要处理”，不只显示一个开关。
- Tradeoffs: 首版优先保证一致性和可恢复性，不追求实时同步；元数据变更日志会占用少量远端文件数量，以换取不依赖 WebDAV 锁和共享文件覆盖。

## Visual language

- Color: 复用现有主题色和 Material 3 色彩；成功、警告、错误使用语义色，不自建同步专属调色板。
- Typography: 复用应用字体与现有设置页层级。
- Spacing/layout rhythm: 沿用设置页卡片、16px 页面边距和 20px 分区间距。
- Shape/radius/elevation: 复用 `_buildSectionCard`、现有输入框和按钮形态。
- Motion: 仅对状态切换和进度做轻量过渡；遵循减少动态效果设置。
- Imagery/iconography: 使用 `cloud_sync_outlined`、`storage_outlined`、`security_outlined` 等 Material 图标，不新增插画。

## Components

- Existing components to reuse: 设置页分区卡片、操作项、开关项、侧边 Toast、确认对话框、响应式导航容器。
- New/changed components: 同步状态卡、分步连接测试、同步范围列表、书籍文件三段筛选、云端书籍卡片状态、批量传输操作栏、待处理变更摘要、同步活动详情、远端空间信息卡。
- Variants and states: 未配置、测试连接中、已连接、同步中、成功、部分成功、失败、离线、凭据失效、远端空间不兼容。
- Token/component ownership: 样式继续由现有主题与设置页组件拥有；同步页面只组合，不创建第二套设计系统。

## Accessibility

- Target standard: 以 WCAG 2.1 AA 为目标。
- Keyboard/focus behavior: 桌面端表单有稳定 Tab 顺序；回车不绕过连接测试或危险确认；密码显隐按钮有语义标签。
- Contrast/readability: 状态不只依赖颜色，同时显示图标和文案；错误详情允许复制。
- Screen-reader semantics: 同步进度使用 live region 语义；字段错误关联到输入项；开关说明包含实际影响。
- Reduced motion and sensory considerations: 减少动态效果时禁用循环旋转和脉冲动画，保留静态进度文本。

## Responsive behavior

- Supported breakpoints/devices: Android、iOS、Windows、macOS、Linux 首版；Web 与 OpenHarmony 延后验证。
- Layout adaptations: 手机单列；宽屏将连接配置与状态/同步范围分为双栏，最大内容宽度受限，避免表单横向拉伸。
- Touch/hover differences: 触屏操作目标至少 44×44；桌面端补充 hover、快捷复制和键盘焦点样式。

## Interaction states

- Loading: 明确当前阶段，例如“读取远端设备列表”“上传 3 项变更”，允许离开页面，单次同步不可重复启动。
- Empty: 未配置时解释需要 WebDAV 地址、用户名和应用密码；无远端数据时说明首次同步将创建独立目录。
- Error: 给出可行动分类，如地址无效、认证失败、证书错误、目录无写权限、空间不足、服务端不支持必要方法、数据损坏。
- Success: 显示最后成功时间、同步的数据域和本次上传/下载数量。
- Disabled: 未通过连接测试前禁用“开启自动同步”；同步过程中禁用配置修改和再次同步。
- Offline/slow network: 本地变更进入待同步状态；允许取消文件传输；元数据重试采用退避，不阻断阅读。

## Content voice

- Tone: 直接、可信、避免夸张。
- Terminology: 使用“同步”表示双向合并；“备份”只用于单向快照；使用“远端数据”而不是含糊的“云端”。
- Microcopy rules: 清楚区分“清除本机配置”“重置本机同步状态”“删除远端同步数据”；涉及覆盖或删除时说明对象、范围和不可逆性。

## Implementation constraints

- Framework/styling system: Flutter、Provider、现有 Material 3/玻璃风格适配；网络层复用 Dio。
- Design-token constraints: 不新增主题依赖和同步专属 token。
- Performance constraints: 阅读进度写入需防抖；元数据批次上限 1 MiB；书籍文件流式传输，不整文件载入内存。
- Compatibility constraints: WebDAV 服务端能力不一致；不得依赖 LOCK；Web 端受 CORS 与浏览器方法限制，首版不承诺可用。
- Test/screenshot expectations: UI 与状态流按 `docs/webdav-sync-ux-design.md` 验收；协议和冲突策略按 `docs/webdav-sync-design.md` 的验收矩阵验证。

## Open questions

- [ ] 首版是否把“书源注册列表”纳入默认同步范围；建议纳入，但不包含任何密钥或令牌。
- [ ] 本地书籍原文件同步是首版一起交付，还是在元数据同步稳定后作为第二阶段；建议第二阶段。
- [ ] 是否在首版引入客户端端到端加密；建议先明确披露“WebDAV 服务端可读取内容”，后续独立设计加密与恢复密钥流程。
- [ ] OpenHarmony 的安全存储与后台能力是否满足同一实现；需要平台专项验证。
