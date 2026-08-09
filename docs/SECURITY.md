# River 安全说明与漏洞报告

## 支持边界

River 的安全边界包括不可信 Feed/XML/HTML、远程资源与重定向、动态 WebView、AI 输出、OAuth/Token、系统安全存储、端到端加密同步、下载文件、外部连接器和发布供应链。安全相关变更必须遵循 `QUALITY_HARNESS.md` 与 `REVIEW_POLICY.md`，且不得把正文、笔记、音频、密钥或完整私有 URL 写入日志和诊断。

## 报告漏洞

请使用 GitHub 仓库的 Private vulnerability reporting / Security Advisory 私下提交复现条件、受影响版本、平台和最小证明。不要在公开 Issue 中发布凭据、用户内容、可利用细节或未修复漏洞。维护者完成分级后会在私有渠道协调修复、回归和披露。

## 发布要求

- PR Fast、Merge、Nightly 与 Release 门禁必须通过；发布只创建 Draft Release，并附带 SHA-256 校验和与依赖清单。
- 商店发布前必须替换模板应用标识，使用受管签名证书/密钥，完成三端真机、升级、低存储、弱网和后台矩阵。
- 图片代理、AI、TTS、转录、同步、Notion OAuth 与权益服务必须在各自服务端实施鉴权、限额、超时、SSRF、防重放、删除与成本熔断；客户端配置不能替代服务端边界。
- 支付渠道当前按产品决策延期；恢复时必须重新启用商店交易事实源、服务端验签、退款/撤销和跨设备一致性审计。
