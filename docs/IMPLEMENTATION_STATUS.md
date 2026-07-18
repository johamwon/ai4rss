# River 实施状态

更新时间：2026-07-16

## 已完成

- FND-002：Composition Root，Clock、ID、HTTP、SQLite、全文提取和平台桥均可注入。
- FND-004：`dart run tool/ci.dart fast` 可在 Windows 独立运行；GitHub 已配置 PR Fast、Merge、Nightly、Release 四条 CI/CD Lane 与 Dependabot。
- DATA-001：Drift/SQLite v1 九张核心表、外键、唯一键和级联规则。
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
- 首个纵向切片：添加 Feed URL → 下载 → 解析 → SQLite 幂等写入 → 订阅及文章列表。
- Windows Debug 构建和真实 Runner Integration Test。

## 部分完成

- FND-001：Android/iOS/Windows Runner 已生成；Windows 已验证，Android SDK 尚未安装，iOS 需 macOS CI/真机验证。
- DATA-003：已有 v0/v1 Fixture；需要在首次 v2 迁移时补充中断迁移和 N-1/N-2 升级演练。
- FEED-001：需要增加 gzip/deflate、更多非 UTF-8 编码和 DNS/私网安全策略测试。
- FEED-002：需要引入更大公开兼容语料并达到 PRD 规定的 99% 成功率，补强 RSS 1.0/RDF 扩展字段。
- FEED-008：URL 直订、网站发现、多 Feed 选择和错误反馈已完成；离线提示尚未完成。
- EXT-004：微信公众号静态适配器已支持 `#js_content`、标题/作者/发布时间/Canonical URL、懒加载图片、媒体占位和关注组件清理；结构缺失时可回退 Readability。仍需扩大语料达到 95% 门槛并接入动态 WebView 回退。
- EXT-005：统一 HTML Sanitizer 已清理可执行节点、事件属性、内联样式和危险协议；资源代理策略尚未实现。

## 下一批

1. EXT-006：正文缓存、同 URL 并发合并、内容哈希与规则版本重解析。
2. EXT-007：Android WebView、WKWebView 与 WebView2 动态渲染回退契约。
3. READ-001：文章状态、阅读页和离线闭环。
4. FEED-007：接入三端平台后台刷新契约与 Smoke Test。
5. FEED-008：离线提示和断网重试体验。

## 最近验证

- Fast Lane：通过，静态分析 0 问题。
- `river_feed`：22 个测试通过。
- `river_data`：15 个测试通过，覆盖并发限制、部分失败、取消和重启恢复。
- `river_app`：7 个测试通过，覆盖刷新进度与取消反馈。
- `river_extract`：16 个测试通过，覆盖安全清理、Feed 全文判定、微信静态提取、Readability 中英正文、多栏噪声、富结构、输入上限、流水线回退与异常分类。
- Harness：fixtures 11/11、feeds 3/3、extraction 7/7、AI replay 1/1、ranking 2/2。
- 三端构建：最近一次 Android/iOS/Windows Nightly 发布候选与主分支 Debug 构建均已通过；FEED-006 不修改原生平台代码。
