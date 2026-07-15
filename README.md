# River Native

River 是本地优先的 Android、iOS、Windows 智能 RSS、音频阅读与个人知识入口。本目录是正式 Flutter/Dart 工程。

## 工程原则

- 领域层不依赖 Flutter、数据库或厂商 SDK。
- 网络、时间、随机数、AI、音频、存储和连接器均通过端口注入。
- 默认使用 Fake 和固定 Fixture；PR 测试禁止访问真实网络。
- 线上问题必须沉淀为最小回归语料。
- AI Prompt、模型、解析器和数据库迁移全部版本化。

## 首次启动

要求 Flutter stable 与 Dart 3.10+。

```shell
flutter pub get
dart run tool/ci.dart fast
cd apps/river_app
flutter run -d windows
```

Windows Debug 构建：

```shell
cd apps/river_app
flutter build windows --debug
```

开发顺序见 [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md)，当前进度见 [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md)，质量门禁见 [docs/QUALITY_HARNESS.md](docs/QUALITY_HARNESS.md)。
