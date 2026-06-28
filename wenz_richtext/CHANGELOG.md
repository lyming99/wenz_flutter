# Changelog

## Unreleased

- 代码块语法高亮改用 [highlight](https://pub.dev/packages/highlight)（highlight.js 的 Dart 移植）库：`CodeSyntaxHighlighter` 不再使用手写分词器，改为调用 `highlight.parse` 解析并遍历 `Node` 树生成 `TextSpan`，公共 API（`CodeSyntaxHighlighter` / `CodeSyntaxPalette`）的类名、字段与构造签名保持不变，composition 合成下划线行为保留。
- 新增依赖 `highlight: ^0.7.0`（仅传递依赖 `collection`，纯 Dart，无原生插件）。
- 支持 20+ 种常见语言（dart / javascript / typescript / python / java / kotlin / swift / go / rust / sql / json / yaml / html / css / markdown / bash，以及 cpp / c# / php / ruby / scala / shell / ini(toml) 等，共 24 种），并通过别名归一化覆盖 `js`/`ts`/`sh`/`md`/`c#`/`html`/`toml` 等常见写法。
- 未知或未注册语言、解析为空或解析异常时统一降级为等宽纯文本（不抛异常），与改造前一致。

## 0.1.0 - 2026-06-24

- 建立 alpha 发布文档入口：根 `README.md`、`docs/release_checklist.md` 与消费者 `migration_guide` 已串联安装、初始化、命令、序列化、扩展和 FAQ。
- 固定 public API 稳定性口径：stable core、stabilising、experimental 三层以 `lib/wenz_richtext.dart` 和 `docs/api_reference.md` 为准。
- 完成进阶能力主线：Markdown / HTML import-export、文件块、callout、mention / formula inline embed、评论线程、协作 adapter、插件 API、Golden 与 benchmark 矩阵。
- 补齐深浅主题适配：编辑器默认背景按 light/dark 使用白/黑，内置块、浮层、辅助面板和 example 主题切换均从 `ThemeData` / `ColorScheme` 派生颜色，并补充双主题 golden / 回归覆盖。
- 已知 alpha 边界：屏幕阅读器抽样手验、移动端 selection handles、三端 IME 手验和部分 PDF / DOCX app-owned adapter 仍需发布前确认。
