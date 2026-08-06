# River Quality Harness

## Test lanes

| Lane | Trigger | Blocking scope |
|---|---|---|
| Fast | Every PR | format, analyze, unit/widget, fixtures, replay evals |
| Merge | Main branch | Windows integration, Android smoke, migrations, build |
| Nightly | Schedule | full corpus, live canary, AI live eval, performance |
| Release | Candidate | physical devices, N-2 upgrade, signing, rollback |

## Non-negotiable contracts

- No real network in unit or widget tests.
- Every platform-channel feature has Dart contract tests, native unit tests and one platform integration test.
- Every parser incident adds a minimized fixture.
- Every database release keeps its migration fixture forever.
- AI changes include quality, latency and cost deltas.
- Reading behavior events use explicit wire versions; exact replays are
  idempotent and identity collisions fail closed.
- Logs never contain article bodies, credentials or provider keys.

## Initial gates

| Gate | Threshold |
|---|---:|
| RSS corpus parse success | >=99% |
| WeChat extraction corpus success | >=95% |
| Unsafe HTML nodes/attributes | 0 |
| AI replay schema success | 100% |
| Required fact coverage | >=90% |
| Forbidden AI claim hit rate | 0% |
| Crash-free sessions after launch | >=99.5% |

Live canaries are advisory for PRs and blocking only after a confirmed regression. Copyrighted full pages must not be committed; use synthetic or minimized fixtures.

AI 摘要黄金集的每个样例必须声明语言、内容类型、风险等级、源证据、允许的输出表达和禁用声明。Fast Lane 至少覆盖中英文、八类内容和四个高风险样例；`ai-replay` 输出必要事实覆盖率、禁用声明命中率及语料分布。增加样例可以提高门槛，不得通过删除难例、减少必需事实或缩小禁用声明集合来“修复”回归。模型或 Prompt 变更还必须在 PR 中报告相同黄金集上的质量差异；静态 Replay 不调用 Provider，因此该 Lane 的延迟和成本差异为零，真实模型延迟与成本由 Nightly live eval 记录。

阅读行为 Schema 变更必须覆盖全部稳定事件类型的往返、旧版/未来版本行为和事件专属载荷边界。重复事件测试同时覆盖顺序重放与并发重放；相同 ID 但不同内容必须失败且不得覆盖原始证据。事件 Fixture、日志和快照不得包含正文、标题、笔记或 AI 输出。

有效阅读计时变更必须使用 FakeClock 覆盖前台、分屏、后台、锁屏、页面不可见和无交互超时。后台、锁屏、不可见与超时后的时长增量必须为零；跳到文末不得单独产生完成事件，生产默认完成门槛同时要求 30 秒有效阅读和 90% 最大滚动深度。重复 flush 只允许上报新增整秒，长会话不得超出行为 Schema 的单事件上限。

行为隐私设置必须使用真实 SQLite 覆盖“无选择即关闭”、首次选择、重启持久化和“关闭后零新增”。保留期测试必须覆盖边界时间；清空测试必须同时验证事件表为空、`secure_delete` 开启和 WAL 截断后的文件不残留测试事件标识。导出只允许包含版本化行为信封与设置，禁止通过文章关联带入标题、URL、正文、笔记或 AI 输出。设置表迁移必须保留 v14 Fixture，并覆盖建表后中断恢复和禁用选择不丢失。

首次行为采集提示必须在新增事件前要求明确选择，退出或返回按关闭处理；说明必须同时列出采集用途、本机范围及正文、标题、URL、笔记和 AI 内容等排除项。三端必须保留可发现的隐私入口，开关状态应有屏幕阅读器语义，清空需要二次确认且不得误删订阅、文章、收藏、笔记或知识库。该页面不得依赖网络端口、分析 SDK 或上传接口。

偏好画像模型变更必须提升模型版本并使用固定会话 Replay 比较旧/新行为。属性测试至少覆盖 1,000 组有效信号，保证单次点击始终弱于有效阅读和明确正向操作，负反馈强于所有正向信号；同文章重复点击只能贡献一次。时间衰减必须验证半衰期、负分和未来时间拒绝；多主题分摊前后总分守恒，重复事件不重复计分，同 ID 冲突失败关闭。画像输入及诊断不得包含正文、标题、URL、笔记或 AI 输出。

排序模型变更必须提升排序模型版本，并用乱序输入重放同一固定候选集。Replay 必须断言最终顺序、分数和六因子解释，解释贡献之和必须与实际排序分数一致。属性测试至少覆盖 1,000 个候选，验证 `[0,1]` 分数边界、降序和输入顺序无关；完全同分必须依次使用发布时间和稳定文章 ID。非法概率、未来文章、重复候选和不兼容画像版本必须失败关闭，重复主题不得放大分数。

排序护栏变更必须提升独立护栏版本，固定 Replay 同时断言单一来源占比、探索配额、强负反馈、主题屏蔽、过滤计数和最终顺序。候选乱序不得改变结果；来源不足时必须显式报告未填满，不能静默突破严格上限。恶意输入覆盖重复候选、超过 10,000 候选、超过 500 返回项、非法比例和超过 64 个屏蔽主题；选择原因不得重写或伪造 RANK-002 分数解释。

排序对照实验必须默认关闭并明确本地报名；同一实验版本的设备分组不可漂移。固定 Replay 必须覆盖 `ship`、`hold` 和样本不足三种判定：每组至少 100 次打开与 20 次可见列表曝光，个性化组完成率提升的 95% 区间下界必须大于 0，快速退出增量上界不得超过 2 个百分点，来源多样性增量下界不得低于 -5 个百分点。后台刷新不得计为列表曝光。导出只允许按天/实验组聚合计数、比率、延迟和成本，禁止文章/来源 ID、标题、URL、正文、笔记、Prompt 或 AI 输出；样本不足必须拒绝导出，且不存在自动上传路径。

托管 AI 路由变更必须固定重放 Provider 故障、超时、并发重复请求和质量回退。客户端请求不得包含或选择 Provider 密钥、端点、具体上游模型、价格或回退顺序；可信套餐与能力只能映射到服务端版本化路由。同一账户、幂等键和完全相同输入必须合并并重放同一结果，不得重复调用或重复消耗限流额度；相同键不同输入必须失败关闭。无效请求与取消不得触发备用 Provider。超时必须同时受总预算和单路由预算约束；熔断必须覆盖打开、跳过、单次半开探测和恢复。质量回退前必须通过能力级 Schema/语言校验，已发生但被拒绝的调用仍计入精确成本。诊断只允许操作哈希、能力、路由、尝试次数、稳定结果码、延迟和成本，禁止账户、文章/来源 ID、标题、URL、正文、Prompt、输出、凭据和远端错误正文。

云端全文救援必须使用注入式 DNS 和固定地址 Transport，验证所选公网 IP 与实际连接 IP 一致，同时保留原域名用于 Host、TLS SNI 和证书校验；Transport 禁止自动重定向和二次 DNS。初始 URL 及每次重定向都必须重新验证协议、凭据、默认端口、主机、全部 DNS 结果和 HTTPS 降级；任一私网/环回/链路本地/保留/混合地址均失败关闭。固定 Replay 至少覆盖私网字面量、私网重定向、同主机 DNS 重绑定、超大响应和恶意 HTML。DNS 数量、响应头、单响应字节、重定向累计字节、每跳超时、总超时和重定向次数必须独立有界，且 DNS 耗时从后续连接预算扣除。只有允许的 HTML 媒体类型与编码进入现有 Sanitizer；诊断禁止主机、路径、查询、IP、HTML、文章元数据、Cookie、凭据和底层错误。

云 TTS 必须以正文 revision、分段文本摘要、完整声音设置、服务端 Profile 版本和格式生成内容寻址键；键和诊断不得含文章 ID、标题、URL、原始 revision、文本、音频或凭据。缓存命中不得访问网络或重复计费；缓存未命中必须通过权益和保守网络策略，默认仅 Wi-Fi，未知链路失败关闭。并发同键只允许一次 Provider 调用和一次用量记录；最后等待者取消必须向 Provider 传播，取消后的晚结果若已产生实际成本仍需精确记账，但不得缓存或返回。固定 Replay 至少覆盖计费时长、重复生成、取消、内容变化和计费网络拒绝。字符、音频字节、播放/计费时长、Provider 超时、TTL、缓存总量和条目数必须独立有界；损坏缓存必须删除重建，清理按确定性 LRU 执行，云失败不得阻断 Free 系统 TTS。

播客转录必须将上传 ID 或远程 URI、声明媒体元数据、输出语言和章节/摘要选项绑定到稳定任务指纹；同任务不同指纹失败关闭，并发同指纹只运行一次。远程拉取适配器必须执行公网 DNS 全答案校验、IP 固定、逐跳重定向复验、TLS 主机校验和流式字节上限；上传适配器必须做账户绑定与实际媒体复验。摄取和转录完成后分别写耐久检查点，中断恢复不得重复已完成阶段；转录与智能分析分别以稳定操作 ID 精确记录计费时长和整数微成本。固定 Replay 至少覆盖六小时音频、格式错误、中断恢复、并发重复和隐私删除。媒体字节/时长、分段数/字符、时间轴、章节、摘要、阶段超时和成本必须独立有界。删除必须取消任务并清除资产、检查点、最终产物和任务用量；诊断禁止 URI、上传 ID、节目身份、文字稿、章节、摘要、凭据和远端错误正文。

云治理 Span 只允许稳定 Span ID、操作哈希、云能力、服务端路由/模型、UTC 起止、稳定结果、整数微成本和有界单位数；同 Span ID 的不同证据必须冲突，成本按能力/模型精确聚合。每个云能力必须同时配置单次和滚动窗口上限，任一超限只熔断该能力并要求显式复位。远程 Kill Switch 快照必须验签、版本单调、同版本不可变、发行/过期时间有界，且只能关闭不能授予权益；缺失或过期策略对云能力失败关闭。固定 Replay 至少覆盖成本异常、选择性关闭、伪造快照和本地降级。关闭任何或全部云能力不得阻断订阅、阅读、缓存全文、离线、系统 TTS、播客播放、高亮笔记和本地知识；诊断禁止账户/内容标识、URL、正文、音频、Prompt、输出、凭据、签名和远端错误。

权益变更必须通过语义 `EntitlementKey` 和统一 Gate，应用 UI 不得读取商品 ID、SKU、收据或价格判断功能。Free 矩阵永久包含订阅、本地/全文/离线阅读、系统 TTS、播客播放、本地知识、完整导出和 BYOK，并在未登录、缓存缺失/损坏、试用结束、Pro 降级、权益服务不可用时逐项回归。付费快照必须绑定账户哈希，使用规范排序载荷与客户端内置公钥验签，版本单调且同版本不可变，发行、刷新和最长七天硬过期时间有界；伪造、错账户、未来时间、回滚和突变不得覆盖最后可信缓存。刷新时间后仅允许显式离线且未到硬过期的缓存访问，在线付费工作必须刷新。安全缓存损坏或未来 Schema 不得静默删除，诊断不得包含账户哈希、签名、收据或商品标识。

用量变更必须先以稳定操作 ID、请求哈希、语义能力和整数单位预留，再按是否产生可用结果结算；失败和取消必须释放全部预留，已提交用量的返还必须保留独立终态。相同操作 ID 的完全相同重试只允许一条记录，不同证据必须冲突；并发预留必须将其他预留计入可用余额，任何时刻不得透支。80% 和 100% 提醒按 Grant 与阈值形成稳定唯一事件，一次跨越两个阈值应各产生一次，重复结算、退款和重新消费不得重复通知。固定 Replay 至少覆盖重试、失败、取消/返还、并发和重复通知；日志与记录禁止正文、音频、Prompt、AI 输出、凭据、收据和商品标识。

永久 Free 回归不得只断言权益枚举；必须在未登录、试用结束和 Pro 降级三种状态分别真实执行微信全文静态提取、离线正文复用、系统 TTS 分段、Podcast 可播放源解析、本地知识对象生成和完整 Markdown ZIP 导出。18 个“状态×能力”检查必须全部通过且网络调用为零。支付、账户、云服务或高级知识功能的变更不得删除、跳过、改为 Mock 成功或缩减这一组；平台真机测试是补充证据，不能替代该确定性 Fast Lane。

GitHub Actions 的工作流映射、产物保留和未签名发布边界见 `docs/CI_CD.md`。

Knowledge vector changes must preserve deterministic, versioned chunk IDs and bounded Unicode-safe chunking. The embedding profile must identify model, revision, dimensions, and execution location; changing the content hash, profile, or chunker version requires a complete atomic replacement, while unchanged input must not call the Provider. Concurrent identical builds coalesce, conflicting mutations fail closed, deletion removes the complete document, corrupt indexes rebuild from canonical knowledge content, and invalid Provider output must leave the previous index untouched. Fast Lane replays build/skip, model upgrade, content change, deletion, and corruption recovery without network access. Cloud index implementations remain behind the same port and cannot weaken these contracts.

Semantic knowledge search changes must run the fixed golden query set and report Recall@K and Precision@K; both are blocking below 0.90. Results are grouped by knowledge item, deterministically ordered, and include bounded source chunks with exact offsets. Similar-item lookup must exclude the source item and reuse stored vectors. Profile mismatches cannot return stale results. Source kind, source ID, tag, topic, saved-time, and exclusion filters execute before scoring, and changes to filterable metadata invalidate the indexed document even when body text is unchanged. Query text and evidence must not enter diagnostics or aggregate metrics.

Knowledge question answering must refuse before the answer Provider when retrieval yields no evidence above the fixed score gate. Every returned statement requires one to five unique citations drawn only from evidence sent in that request; unknown, duplicate, missing, or excessive citation IDs fail closed. A Provider refusal cannot carry statements. Citation title, quote, item identity, and exact source offsets are always materialized from trusted retrieval results rather than Provider output. Replays must cover grounded answers, retrieval refusal with zero answer calls, Provider refusal, forged citations, and uncited claims. Diagnostics may expose only question length, language, evidence count, and stable result codes.

Portable knowledge connectors must keep internal knowledge available independently of destination health. Obsidian writes stay below one configured relative directory, use atomic store operations, preserve stable paths across title changes, compare exact bytes for idempotency, and reject stale revisions without overwriting. WebDAV uses HTTPS by default, one safe object path segment, `If-None-Match: *` for creates, and ETag `If-Match` for updates and deletes. Authentication, precondition conflicts, rate limits, capacity, offline, timeout, and unavailable transport states map to stable failures; retry delays are bounded. Fixed replays cover idempotency, conflict, conditional writes, rate limits, offline retry, and diagnostic privacy. Documents, credentials, response bodies, and complete remote URIs must not enter logs or metrics.

IMA interoperability must remain user-assisted until a stable public API is documented. One item exports as canonical UTF-8 Markdown; multiple items or assets export as one deterministic ZIP. System share and file save require an explicit user action, cap the package at 200 MiB, use a safe leaf filename, preserve dismissal separately from failure, and leave local knowledge unchanged. The only launch target is the fixed public HTTPS IMA entry. Custom schemes, credentials, query/fragment payloads, alternate hosts, private paths, tokens, cookies, undocumented endpoints, and UI automation are forbidden. Replays cover Markdown, ZIP, dismissal, public launch, private URI rejection, and diagnostic privacy.

Podcast transcript questions must select evidence before the answer Provider and refuse with zero Provider calls when no segment matches. Every accepted statement cites one to five unique segment indexes from that request; River materializes quote, speaker, and exact start/end time from the trusted transcript. Daily audio briefs bind UTC day, language, style, source hashes, and cost budget. Narration has no speaker label; dialogue strictly alternates `host` and `guest`; every turn cites trusted sources. Source text and generated script pass separate safety gates before rendering. Script and audio use separate stable usage keys and the remaining integer-micro budget; invalid output and cancellation-late results still record incurred cost. Replays cover grounded/no-evidence/forged QA, grounded dialogue, source safety, late cancellation accounting, and diagnostic privacy.

Feed server account changes must replay both FreshRSS Google Reader and Miniflux `/v1` public API contracts. Account base URIs require credential-free HTTPS and credentials must be redacted from objects, failures, logs, and metrics. A pull returns a complete subscription set, a bounded provider-appropriate state reconciliation set, and a monotonic cursor; FreshRSS rechecks its bounded stream window while Miniflux uses `changed_after`. Cursor regression fails before repository mutation, and an older entry state cannot replace a newer one. Canonically identical feed URLs reuse one local source across accounts while retaining separate remote mappings and states. Account removal deletes only its own state and removes a local source only after its final mapping is gone. Replays cover both adapters, duplicate mapping, cursor regression, state ordering, safe removal, and credential privacy without network access.
