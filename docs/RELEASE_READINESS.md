# River 发布准备

`dart run tool/release_audit.dart --mode=candidate` 是内部候选包的确定性配置门禁；`--mode=store` 会把所有外部发布警告提升为失败。Release workflow 会保存 JSON 审计结果、Dart 依赖清单、三端产物和 SHA-256 校验和，并始终只创建 Draft Release。

## 当前结论

主体产品和可离线自动验证的工程任务已完成。内部 Android/iOS/Windows 候选包可由 CI 生成；正式商店发布仍被以下证据阻塞：

| 项目 | 自动化证据 | 正式发布仍需 |
| --- | --- | --- |
| REL-001 RC 配置 | 版本、锁文件、远程能力默认边界、Draft 发布与三端矩阵自动审计 | 确认永久应用 ID、产品名与 Feature Flag 清单 |
| REL-002 真机 | Windows Integration/Nightly 与三端构建 | Android/iOS/Windows 干净设备安装、升级、卸载、权限、后台、锁屏、蓝牙与中断记录 |
| REL-003 升级 | v0～v17→v18 Fixture、迁移中断恢复、同步和缓存回归 | 使用已发布 N-1/N-2 候选数据做签字演练 |
| REL-004 压测 | 10,000 篇文章 P95 门禁、长文/长音频有界策略与故障 Replay | 真机低内存、弱网、系统清理和磁盘不足报告 |
| REL-005 安全 | HTML/SSRF/OAuth/密钥/密文/依赖规则进入 Fast Lane；安全报告入口已定义 | 对真实云端、代理、OAuth 和签名设施做外部审计 |
| REL-006 隐私 | 数据处理说明与应用内删除/导出边界已有实现 | 法务主体、地区文本、商店 Data Safety/Privacy Labels 和真实删除 SLA 签字 |
| REL-007 供应链 | 锁文件、依赖 JSON、SHA-256、Draft Release | Android/iOS/Windows 正式签名、符号归档、密钥托管和恢复演练 |
| REL-008 灰度 | Kill Switch、费用熔断、旧客户端协议兼容已有测试 | 真实监控、1%→10%→100%灰度账号与回滚值班 |
| REL-009 验收 | PRD 能力和 Harness 证据持续记录于 `IMPLEMENTATION_STATUS.md` | 产品、工程、测试、安全、法务共同签署正式验收 |

支付渠道继续按产品决策延期，不纳入当前候选包，也不阻塞付费入口关闭的永久免费版本发布；恢复支付工作时必须重新执行 COM-003～005 和对应商店/服务端验收。
