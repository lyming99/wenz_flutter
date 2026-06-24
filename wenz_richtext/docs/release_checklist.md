# Release checklist

本清单用于 `0.1.0` 内部 alpha 或后续 tagged release 的发布前复核。功能边界以 `README.md`、`docs/api_reference.md`、`docs/migration_guide.md` 和 `docs/advanced_feature_matrix.md` 为准。

## 自动化门禁

在 PowerShell 中执行：

```powershell
flutter analyze
flutter test
flutter test test\benchmarks\editor_benchmarks.dart
cd example
flutter analyze
flutter test
```

发布记录需要写明 Flutter / Dart 版本、测试总数、benchmark 场景数和是否有已知失败。若只做文档增量，可至少执行相关文档链接和拼写扫描，并说明未跑全量 Flutter 门禁的原因。

## 文档门禁

- `README.md` 覆盖安装、初始化、命令入口、序列化、扩展点和 FAQ。
- `CHANGELOG.md` 记录面向消费者的变更、稳定性口径和 alpha 边界。
- `docs/migration_guide.md` 说明 rich JSON、legacy JSON、schema migration、Markdown / HTML、0.1.0 升级边界。
- `docs/api_reference.md` 与 `lib/wenz_richtext.dart` 的 API tier 保持一致。
- `docs/running_guide.md` 能指导 Web / Windows example 主流程演示。

## 手动门禁

- Web、Windows、Android 至少各完成一次中文 IME 输入、选区、剪贴板和表格 cell 输入手验。
- 合并单元格视觉横跨、selection highlight、caret、媒体占位和高级 block golden 有最新证据。
- Narrator / TalkBack 或等效屏幕阅读器抽样验证语义标签；未完成时必须列入 known limitations。
- Windows 第三方 IME 候选框偏移需区分本库问题和 Flutter engine 层问题。

## 发布物

- 版本号与 `pubspec.yaml`、`CHANGELOG.md`、发布说明一致。
- 包内不应包含临时文件、平台本地构建产物或误生成的 Windows `nul` 文件。
- 运行 `git status --short` 只应剩余本次发布文档、代码或测试的预期改动。
