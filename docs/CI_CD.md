# River GitHub CI/CD

River 使用 GitHub Actions 映射质量 Harness 的四条执行 Lane。所有工作流使用根目录 `pubspec.yaml` 锁定的 Flutter 版本，并只授予完成任务所需的最小 GitHub Token 权限。

Windows 开发机需要使用非默认 Flutter 入口时，可以设置 `RIVER_FLUTTER_EXECUTABLE`。依赖已经单独解析、且当前环境无法创建插件符号链接时，可设置 `RIVER_CI_SKIP_BOOTSTRAP=true`；GitHub 托管 Runner 不需要这两个变量。

| 工作流 | 触发 | 阻断/产物 |
|---|---|---|
| PR Fast | 面向 `master` 的 PR、手动 | 格式、静态分析、全部单元/Widget 测试、Fixture 与 Replay Harness |
| Merge | 推送 `master`、手动 | Fast Lane 后并行生成 Android、iOS、Windows Debug 构建，保留 7 天 |
| Nightly | 每日 02:23（Asia/Shanghai）、手动 | 确定性回归、Windows Integration Journey、三端 Release Candidate，保留 14 天 |
| Release | `v*` 标签、手动 | Fast Gate、三端打包、SHA-256 清单和草稿 GitHub Release |

## 发布方式

1. 合并并确认 `Merge` 与最近一次 `Nightly` 通过。
2. 创建符合语义化版本的标签，例如 `v0.1.0`，或从 Actions 手动输入该标签。
3. `Release` 会创建草稿 GitHub Release；负责人检查产物与校验和后再决定是否发布。

当前发布产物用于内部验证：Android 仍使用模板 Debug Signing，iOS 明确为无签名包，Windows 尚未代码签名。商店/TestFlight/MSIX 自动发布必须等正式应用 ID、证书、密钥托管和平台账号就绪后再启用。任何签名材料都不得提交到仓库。

## 分支保护建议

在 GitHub 仓库规则中将 `PR Fast / Fast lane` 设为 `master` 的必需状态检查，并禁止直接向 `master` 推送。域名解析、数据库迁移、AI Prompt、支付和平台通道改动仍需遵循 `docs/REVIEW_POLICY.md` 的领域评审要求。

## 当前边界

- PR 与 Widget 测试不访问真实网络。
- Nightly 当前只执行已落地的离线语料和平台构建；Live Canary、真机矩阵、AI Live Eval 与性能基线将在对应 Harness 能力实现后接入。
- iOS 构建只验证可编译性，不代表后台任务、TTS 或锁屏控制已通过真机验收。
