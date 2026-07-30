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

GitHub Actions 的工作流映射、产物保留和未签名发布边界见 `docs/CI_CD.md`。
