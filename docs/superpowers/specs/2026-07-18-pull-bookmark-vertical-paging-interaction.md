# 下拉书签 × 上下翻页交互规格

日期：2026-07-18
状态：交互设计定稿；固定阅读窗口已实现，下拉书签边界移交待实现与真机调优
参考：Lightink `docs/17-pull-bookmark-vs-vertical-scroll.md`、Open Reading 当前 `ReaderPullBookmark` 与上下翻页实现

## 1. 目标

在保留下拉书签快捷操作的同时，确保上下翻页的正文滚动永远拥有更高优先级：

- `pullBookmarkEnabled` 与 `ReaderPageMode.verticalScroll` 保持正交，可同时开启。
- 横翻、无动画和仿真模式继续使用“顶缘下拉即可触发”的现有规则。
- 上下翻页使用“顶缘候选 + 语义起点 + leading overscroll”移交规则。
- 正文中部的所有纵向拖动只属于正文列表。
- 上下翻页只禁用拖动进度条定位；目录跳转和下拉书签继续保留。
- 书签写入必须使用稳定的可见阅读锚点，不使用滚动百分比临时推算。

## 2. 非目标

- 不改变书签数据模型与 `BookmarkDao`。
- 不改变目录点击、书签列表跳转和分页模式左右点击/滑动规则。
- 不让固定章名、页码、书签丝带或下拉反馈层参与命中测试。
- 不依赖某个平台私有的滚动距离或物理常数。

## 3. 当前实现与缺口

`ReaderPullBookmark` 当前已经具备：

- 与翻页模式独立的设置开关。
- `safeTop + 72px` 顶缘热区。
- 76px 触发阈值和 116px 最大视觉位移。
- 横向偏移、向上移动、取消事件的复位。
- 添加/移除书签提示、书签丝带与触发回调。

当前缺口：

- 顶缘起手后立即开始累计位移，没有判断上下翻页列表是否还能向上滚。
- 原始 `Listener` 会与下层滚动列表同时观察指针，因此正文中部可能一边回滚、一边显示书签反馈。
- 不能只用 `ScrollMetrics.pixels == minScrollExtent` 判断全书起点；`ScrollablePositionedList` 远跳后会重组内部列表。
- 控制栏显示时，顶部按钮区域仍处于下拉书签监听范围。
- 触发目标在松手时从当前状态重新计算，缺少手势开始时的稳定锚点快照。

## 4. 核心原则

### 4.1 设置正交

```text
pullBookmarkEnabled = true/false
pageMode = verticalScroll / instantPage / horizontalSlide / pageCurl
```

两项设置互不修改。进入上下翻页不会自动关闭下拉书签。

### 4.2 正文滚动优先

上下翻页中，顶缘按下只产生一个候选手势。列表仍先处理拖动；只有抵达语义起点并继续向下拉时，书签层才开始反馈。

### 4.3 同一手势允许边界移交

用户可从顶缘开始向下拖动，把正文一路滚回顶部。同一次拖动抵达顶部后，继续向下产生的额外位移可转为下拉书签。

到顶前已经用于滚动正文的距离不得计入书签阈值。

### 4.4 Chrome 只读

- 固定章名：`IgnorePointer`
- 固定页码：`IgnorePointer`
- 下拉反馈：`IgnorePointer`
- 书签丝带：`IgnorePointer`

真正接收输入的只有外层原始指针监听与正文滚动容器。

## 5. 语义起点

不能单独信任底层滚动像素，需要结合 `ItemPositionsListener` 的可见位置。

### 5.1 单章上下翻页

```text
当前章内页 = 0
且 item[0].leadingEdge >= -(2 / viewportHeight)
```

每章是独立竖向列表，因此该章第 0 页完全贴齐顶部时视为语义起点。

### 5.2 整书上下翻页

```text
当前章 = 0
当前章内页 = 0
且 chapterItem[0].leadingEdge >= -(2 / viewportHeight)
```

跳到第 20 章章首不属于全书起点，不能触发下拉书签。

### 5.3 Leading overscroll

`OverscrollNotification.overscroll < 0` 表示正常方向列表在顶部继续向下拉。该事件只有在语义起点为真时才可用于移交。

overscroll 应作为一次性事件消费，不应以长期布尔值跨手势保留。

## 6. 手势状态机

```text
Idle
  └─ 顶缘内按下、设置开启、非 busy、控制栏隐藏
       → Candidate

Candidate
  ├─ 横向占优 / 明显向上 / 多指 / PointerCancel
  │    → Cancelled → Idle
  ├─ 非上下翻页 + 确认向下意图
  │    → Tracking
  ├─ 上下翻页 + 尚未到语义起点
  │    → 保持 Candidate，列表继续滚动
  └─ 上下翻页 + 语义起点 + leading overscroll
       → Tracking，并把当前位置记为移交原点

Tracking
  ├─ 有效下拉距离 < 76px
  │    → 显示“下拉添加/移除书签”
  ├─ 有效下拉距离 >= 76px
  │    → Armed，显示“松开添加/移除书签”，轻触震动一次
  ├─ 回推到阈值以内
  │    → 回到 Tracking
  └─ 离开边界 / 方向失效 / PointerCancel
       → Cancelled → Idle

PointerUp
  ├─ Armed → Triggered → 写入锚点快照 → Idle
  └─ 未 Armed → 回弹 → Idle
```

## 7. 输入判定

推荐逻辑像素参数：

| 参数 | 值 | 含义 |
|---|---:|---|
| 顶缘热区 | `safeTop + 72` | 只按起点判断，不要求后续指针留在热区 |
| 意图 slop | `8` | 超过后才锁定方向 |
| 横向取消下限 | `30` | 防止轻微抖动取消 |
| 纵向优势 | `dy > abs(dx) * 1.25` | 只接受明确下拉 |
| 触发距离 | `76` | 进入 Armed |
| 最大视觉位移 | `116` | 超过阈值后增加阻尼 |
| 顶部 epsilon | `1–2` | 处理浮点和回弹误差 |

只接受触摸和手写笔。鼠标拖动、滚轮和触控板滚动不触发下拉书签。

## 8. 视觉与触觉反馈

- `Candidate` 阶段不显示任何书签 UI，避免正常回滚正文时闪烁。
- 进入 `Tracking` 后，固定章名在约 120ms 内淡出，书签提示接管顶部状态区域。
- 0–76px 使用接近线性的跟手位移；超过阈值后增加阻尼，最大显示到 116px。
- 首次跨过阈值时进行一次轻触震动，同一手势不重复震动。
- 回推到阈值以内时恢复未 Armed 样式，但不再次震动。
- 松手、取消或失败后提示使用弹性回位，固定章名恢复。
- 添加与移除使用动作明确的文案：

```text
下拉添加书签 → 松开添加书签
下拉移除书签 → 松开移除书签
```

## 9. 书签目标锚点

进入 `Tracking` 时冻结：

```text
chapterIndex
pageInChapter
canonicalTextOffset
anchorKey
bookmarkedAtStart
```

触发时只操作该快照，避免异步分页刷新、目录跟随或回弹过程中锚点改变。

本地阅读器使用 `VisibleReadingAnchor` 对应的 `_ReaderPageData.startOffset`；书源阅读器使用当前 `_BookSourceVerticalLayout.pages[pageIndex].startOffset`。

## 10. 模式矩阵

| 场景 | 行为 |
|---|---|
| 横翻/无动画/仿真 + 顶缘下拉 | 确认向下意图后直接 Tracking |
| 上下翻页 + 正文中部顶缘下拉 | 只滚动正文，不显示提示 |
| 上下翻页 + 同次手势滚到顶部后继续下拉 | 从移交点重新累计书签距离 |
| 上下翻页 + 屏幕中部下拉 | 只滚动正文 |
| 整书模式 + 其他章节章首 | 仍可向前滚，不允许书签移交 |
| 单章模式 + 当前章第 0 页贴顶 | 允许书签移交 |
| 控制栏/目录/设置显示 | 禁止开始下拉书签 |
| 目录点章 | 始终保留 |
| 拖动进度定位 | 上下翻页禁用或降级 |

## 11. 推荐代码边界

不要把边界直接拼进 `enabled`：

```dart
// 不推荐：滚动过程中 enabled 会反复变化，无法表达同手势移交。
enabled: pullBookmarkEnabled && verticalAtTop
```

推荐拆分：

```text
ReaderPullBookmark
  ├─ Candidate / Tracking / Armed 状态机
  ├─ 顶缘、指针类型、方向与控制栏门闩
  └─ 冻结 VisibleReadingAnchor

ReaderVerticalBoundaryController
  ├─ semanticAtStart
  ├─ consumeLeadingOverscroll()
  └─ currentAnchor
```

`ReaderPullBookmark` 保持原始 `Listener`，不主动抢占 Flutter gesture arena。上下翻页列表继续拥有滚动手势；书签层只观察在边界处无法继续消费的下拉。

## 12. 验收用例

1. 书中部从顶缘下拉：只回滚正文，不出现书签提示。
2. 同一次手势滚到顶部后继续下拉不足 76px：不触发。
3. 同一次手势到顶后额外拉满 76px：触发一次。
4. 整书模式位于其他章节章首：不能触发。
5. 单章模式第 0 页完全贴顶：允许触发。
6. 第 0 页仍有内容藏在顶部外：不能触发。
7. 从屏幕中部下拉：任何模式都不触发。
8. 控制栏显示或从顶部按钮区域拖动：不触发。
9. 横向占优、上滑、多指、系统取消：立即复位。
10. 跨过阈值一次：只震动一次。
11. 触发过程中可见页刷新：仍操作冻结锚点。
12. 目录跳章、书签列表跳转继续可用。

## 13. 真机调优项

- Android 16 上 BouncingScrollPhysics 的顶部阻尼和 overscroll 通知幅度。
- 72px 热区是否与状态栏、固定章名和系统下拉手势形成舒适边界。
- 76px 触发距离是否需要按手机/平板分别调整。
- 顶部提示与固定章名切换时是否有重影。
- 快速下拉、慢速拉到顶部再继续下拉、斜向拖动的误触率。

## 14. 固定阅读窗口与跨页空白规则

上下翻页的固定章名和页码属于 viewport chrome，不属于每一个正文 page item。正文必须只在两者之间的窗口内出现：

```text
屏幕顶部
  固定章名留白（contentTop）
  ┌──────────────────────┐
  │ ClipRect 正文窗口     │
  │ page 0                │
  │ page 1                │
  │ ...                   │
  └──────────────────────┘
  固定页码留白（contentBottom）
屏幕底部
```

统一几何公式：

```text
pageExtent = viewportHeight - contentTop - contentBottom
```

- `Padding(top: contentTop, bottom: contentBottom) + ClipRect` 只在列表外层建立一次固定阅读窗口。
- 每个纵向 page item 的高度严格等于 `pageExtent`，内部只保留水平正文边距，不再重复加入 `contentTop/contentBottom`。
- 分页器的可用高度、列表 item 高度、缓存范围、目录/书签跳转偏移和恢复偏移必须共用同一个 `pageExtent`，禁止再以整屏高度乘页码。
- 相邻正文页之间只允许存在分页器因整行容纳产生的少量行尾余量，不允许叠加上一页底部 chrome 留白和下一页顶部 chrome 留白。
- `ClipRect` 保证正文和回弹 overscroll 不会绘制到固定章名或页码下方。
- TXT 的纯章节标题页是有意保留的特殊 page item；本规则只消除普通正文页重复留白，不删除章节标题页。

该结构同时用于本地 TXT/EPUB 等文件阅读器和在线书源阅读器，并覆盖“按章节滚动”开启与关闭两条路径。
