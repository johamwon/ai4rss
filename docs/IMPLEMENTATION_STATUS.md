# River 实施状态

更新时间：2026-07-15

## 已完成

- FND-002：Composition Root，Clock、ID、HTTP、SQLite、全文提取和平台桥均可注入。
- FND-004：`dart run tool/ci.dart fast` 可在 Windows 独立运行；GitHub 已配置 PR Fast、Merge、Nightly、Release 四条 CI/CD Lane 与 Dependabot。
- DATA-001：Drift/SQLite v1 九张核心表、外键、唯一键和级联规则。
- DATA-004：持久任务队列，支持幂等入队、租约、失败重试和中断恢复。
- FEED-001 核心：受限 HTTP(S)、超时、手动重定向、循环检测、响应体上限、User-Agent、编码、ETag 与 Last-Modified 条件请求。
- FEED-002 核心：RSS 2.0、Atom、JSON Feed 统一模型和固定离线语料。
- FEED-003：支持直接 Feed、HTML `<link rel="alternate">`、Content-Type 与同源常见路径发现，可去重并选择多个候选源。
- 首个纵向切片：添加 Feed URL → 下载 → 解析 → SQLite 幂等写入 → 订阅及文章列表。
- Windows Debug 构建和真实 Runner Integration Test。

## 部分完成

- FND-001：Android/iOS/Windows Runner 已生成；Windows 已验证，Android SDK 尚未安装，iOS 需 macOS CI/真机验证。
- DATA-003：已有 v0/v1 Fixture；需要在首次 v2 迁移时补充中断迁移和 N-1/N-2 升级演练。
- FEED-001：需要增加 gzip/deflate、更多非 UTF-8 编码和 DNS/私网安全策略测试。
- FEED-002：需要引入更大公开兼容语料并达到 PRD 规定的 99% 成功率，补强 RSS 1.0/RDF 扩展字段。
- FEED-004：暂停、恢复、删除、URL 去重已完成；文件夹 UI/仓储尚未完成。
- FEED-006：前台手动增量刷新及 304 已完成；并发限制、刷新状态、取消和任务恢复尚未完成。
- FEED-008：URL 直订、网站发现、多 Feed 选择和错误反馈已完成；离线提示尚未完成。

## 下一批

1. FEED-005：OPML 导入导出和文件夹层级。
2. FEED-006：并发限制、持久刷新任务、失败状态和恢复。
3. EXT-001/002：通用正文提取编排与微信公众号客户端 WebView 适配。
4. READ-001：文章状态、阅读页和离线闭环。
5. FEED-008：离线提示和断网重试体验。

## 最近验证

- Fast Lane：通过，静态分析 0 问题。
- `river_feed`：18 个测试通过。
- `river_data`：7 个测试通过。
- `river_app`：4 个测试通过。
- Harness：fixtures 4/4、feeds 3/3、extraction 1/1、AI replay 1/1、ranking 2/2。
- Windows：Debug 构建成功；Integration Test 1/1。
