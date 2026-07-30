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

GitHub Actions 的工作流映射、产物保留和未签名发布边界见 `docs/CI_CD.md`。
