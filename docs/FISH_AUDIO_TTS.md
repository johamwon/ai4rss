# Fish Audio 云端 TTS 配置

River 通过用户自有 API Key 直连 Fish Audio，不代理、不上传或记录 Key。

## 客户端配置

1. 登录 `https://fish.audio/app/api-keys` 创建 API Key。
2. 在 River 打开“设置 → AI 与音频供应商 → 云端 TTS”。
3. 将“TTS 服务商类型”切换为“Fish Audio”。
4. 选择模型：
   - `s2.1-pro`：默认，适合正式使用。
   - `s2.1-pro-free`：开发者免费层，适合试用和开发验证，不应依赖生产级保障。
   - `s2-pro`、`s1`：兼容旧模型。
5. 可留空 Voice 字段以使用默认音色；如需指定音色，填写 Fish Audio 的 Voice Model ID。
6. 填入 API Key，先点“测试连接”，再保存。

Fish Audio 的服务地址固定为 `https://api.fish.audio`，不可改成其他域名。连接测试读取账户 API 额度状态，不生成语音。正式合成使用 `POST /v1/tts`，默认 MP3，并根据 River 当前倍速传递 prosody speed。

## 隐私与费用

- Key 只保存到 Android Keystore、iOS Keychain 或 Windows DPAPI 安全仓库。
- 仅在用户主动使用云端 TTS 时，将对应文章分段文本发送给 Fish Audio。
- River 日志和诊断不记录 Key、正文、远端错误正文或生成音频。
- Fish Audio 的调用费用由用户与 Fish Audio 直接结算；River 的 BYOK 台账不重复计价。

## 回退

删除 Fish Audio 凭据或停止使用云端 TTS，即可回到免费的本地系统 TTS。Fish Audio 不可用时不得阻断阅读、离线内容或系统 TTS。
