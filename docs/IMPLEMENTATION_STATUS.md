# River 实施状态

更新时间：2026-07-23

## 已完成

- FND-002：Composition Root，Clock、ID、HTTP、SQLite、全文提取和平台桥均可注入。
- FND-004：`dart run tool/ci.dart fast` 可在 Windows 独立运行；GitHub 已配置 PR Fast、Merge、Nightly、Release 四条 CI/CD Lane 与 Dependabot。
- DATA-001：Drift/SQLite v4 十张核心表及本地 FTS5 索引、外键、唯一键和级联规则；v2 新增可空 Feed 正文字段，v3 新增阅读设置单例表，v4 新增文章与知识库全文索引，并保留 v1/v2/v3 升级兼容。
- DATA-003：v0、v1、v2、v3、v4 Fixture 与 N-2 升级演练已完成；覆盖 v1/v2/v3→v4、各阶段迁移中断后的幂等恢复和当前 v4 打开。
- DATA-004：持久任务队列，支持幂等入队、租约、失败重试和中断恢复。
- FEED-001 核心：受限 HTTP(S)、超时、手动重定向、循环检测、响应体上限、User-Agent、编码、ETag 与 Last-Modified 条件请求。
- FEED-002 核心：RSS 2.0、Atom、JSON Feed 统一模型和固定离线语料。
- FEED-003：支持直接 Feed、HTML `<link rel="alternate">`、Content-Type 与同源常见路径发现，可去重并选择多个候选源。
- FEED-004：文件夹创建、改名、折叠、删除和来源移动，以及暂停、恢复、删除与规范化 URL 去重。
- FEED-005：OPML 文件导入导出、嵌套文件夹往返、事务写入、重复/非法项报告和输入安全上限。
- FEED-006：前台增量刷新、条件请求、持久批次、全局/同域并发限制、可观察状态、协作式取消和启动恢复。
- EXT-001：统一正文提取请求、规范化成功结果、稳定失败码、阶段尝试记录、Extractor 版本和质量评分。
- EXT-002：Feed 全文可信度判定，可区分完整正文、短摘要、显式截断和空内容，并在可信时停止后续提取。
- EXT-003 核心：纯 Dart Readability 候选评分、链接密度、正文兄弟合并、中文标点、多栏噪声清理、元数据归一化与输入规模上限。
- EXT-006：SQLite 正文缓存、SHA-256 内容哈希、ETag/Last-Modified 与规则版本失效、显式重解析、同 URL 请求合并、全局/同源并发限制及离线旧缓存回退。
- EXT-007：Android WebView、WKWebView 与 WebView2 共用动态渲染回退契约；限制协议、导航次数、超时和 HTML 大小，渲染结果重新进入 Readability 与 Sanitizer。三端 Debug 构建和 Windows 动态页面 Smoke Test 已进入 CI。
- READ-001：收件箱、未读、收藏、稍后读和文件夹文章视图，以及最新/最早确定性排序；列表展示来源、时间、阅读时长和状态，支持惰性大列表、分视图滚动恢复、加载/空/失败/重试状态。
- READ-002：渐进阅读页即时展示已净化的 Feed/缓存内容；摘要或截断 Feed 才下载静态网页并依次回退 Readability/WebView，完整正文在同一文档控件内替换，保留视口文本锚点和可映射选区；缓存/失败不阻断阅读。
- READ-003：阅读页支持系统/衬线/无衬线字体、字号、行高、内容宽度与系统/浅色/深色主题；设置持久化并保留系统字体缩放，手机、平板和 Windows 宽/窄窗口 Golden 矩阵已覆盖。
- READ-004：已读、收藏、稍后读和阅读进度支持幂等持久写入及重启恢复；阅读 90% 自动完成，系统分享仅发送标题与 Canonical URL，不发送正文。
- READ-005：本地全文搜索覆盖标题、作者、来源、摘要、正文、知识库标签和笔记；支持中文/英文/特殊字符、未读/收藏/稍后读/文件夹/来源过滤、相关性或时间排序、安全文本高亮、防抖、过期查询替换以及加载/空/失败/重试状态。10,000 篇文章搜索 P95 设有小于 500ms 的自动门槛。
- 首个纵向切片：添加 Feed URL → 下载 → 解析 → SQLite 幂等写入 → 订阅及文章列表。
- Windows Debug 构建和真实 Runner Integration Test。

## 部分完成

- FND-001：Android/iOS/Windows Runner 已生成且三端 Debug CI 构建通过；仍需 Android、iOS 和 Windows 真实设备/系统验收。
- FEED-001：需要增加 gzip/deflate、更多非 UTF-8 编码和 DNS/私网安全策略测试。
- FEED-002：需要引入更大公开兼容语料并达到 PRD 规定的 99% 成功率，补强 RSS 1.0/RDF 扩展字段。
- FEED-008：URL 直订、网站发现、多 Feed 选择和错误反馈已完成；离线提示尚未完成。
- EXT-004：微信公众号静态适配器已支持 `#js_content`、标题/作者/发布时间/Canonical URL、懒加载图片、媒体占位和关注组件清理；结构缺失时可依次回退 Readability 和动态 WebView。仍需扩大语料达到 95% 门槛。
- EXT-005：统一 HTML Sanitizer 已清理可执行节点、事件属性、内联样式和危险协议；资源代理策略尚未实现。

## 下一批

1. FEED-007：接入三端平台后台刷新契约与 Smoke Test。
2. FEED-008：离线提示和断网重试体验。
3. EXT-008：全文失败恢复 UX 与原文/重试入口。
4. READ-006/007：批量文章操作与键盘快捷键。

## 最近验证

- Fast Lane：通过，静态分析 0 问题。
- `river_feed`：27 个测试通过，新增搜索查询约束、大小写无关字面量高亮与 Unicode 索引安全覆盖。
- `river_domain`：3 个测试通过，覆盖阅读设置默认值、不可变更新与边界约束。
- `river_data`：37 个测试通过，新增中文/英文/特殊字符搜索、状态过滤、索引触发器、v1/v2/v3→v4、中断恢复、当前库打开及 10,000 篇文章 P95 1.4ms 基准。
- `river_app`：27 个测试通过，新增搜索防抖、筛选排序、结果高亮、失败重试和过期查询替换，并继续覆盖五组跨尺寸/主题 Golden。
- `river_extract`：29 个测试通过，新增完整 Feed 零网页请求、摘要静态下载和失败后平台回退编排覆盖。
- `river_platform`：7 个测试通过，覆盖动态页面边界以及系统分享请求和结果映射。
- Harness：fixtures 15/15、feeds 3/3、extraction 7/7、AI replay 1/1、ranking 2/2。
- 本机 Windows Runner 验证受环境缺少 NuGet 阻断在插件构建阶段；同一集成旅程由安装 NuGet 的 Merge/Nightly Windows CI 执行。
- 三端构建：最近一次 Android/iOS/Windows 主分支 Debug 构建及产物上传均已通过；READ-002 的 Windows 原生滚动/选区旅程已加入 Merge 与 Nightly CI。
