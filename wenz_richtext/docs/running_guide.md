# Running the Example (Web / Windows)

`wenz_richtext` 自身是纯 Flutter package（无原生插件），example 已配置 `web/` 和 `windows/` 平台目录，可在两端运行。

## 前置要求

- Flutter SDK `>=3.22.0`，Dart SDK `>=3.3.4`（见根 `pubspec.yaml`）。
- 无第三方依赖，`flutter pub get` 不会拉取除 Flutter SDK 外的包。

## 运行 example

example 工程位于 `example/`，进入该目录执行命令。

### Windows（桌面）

```bash
cd example
flutter run -d windows
```

首次运行会编译 `windows/` runner，耗时较长。之后增量构建很快。

### Web（Chrome）

```bash
cd example
flutter run -d chrome
```

或构建静态产物：

```bash
cd example
flutter build web
# 产物在 example/build/web，可用任意静态服务器托管
```

### 选择设备

`flutter devices` 列出当前可用目标。未指定 `-d` 时 Flutter 会提示选择。

## 已验证的交互（阶段 0）

两端均可：

- 点击文本/代码块任意位置定位 caret。
- 水平拖拽选中文本并显示高亮（垂直拖拽交给页面滚动）。
- 键盘输入字符、Enter 分段、Backspace/Delete 删除、左右方向键移动、Shift+方向键扩选。
- Undo/Redo（工具栏按钮）。
- 工具栏：加粗/斜体/清除样式、块类型切换、插入代码块/表格/图片。

## 已知平台差异（阶段 0 边界）

- **IME / 组合输入**：当前通过 `KeyEvent.character` 接收字符，未接入 `TextInputClient`。中文等 IME 输入在阶段 1 才完整支持，本阶段先保证直接键盘字符输入稳定。
- **剪贴板**：复制/剪切/粘贴在阶段 1 实现。
- **跨块拖拽选择**：阶段 0 的拖拽选择为单块水平方向；从一个段落拖到另一个段落的跨块选择属于阶段 2。
- **Web 焦点**：点击编辑器区域会显式请求焦点以显示 caret；如遇 caret 不出现，确认浏览器未拦截焦点（部分 iframe 嵌入场景需要 `tabindex`）。

## Debug overlay

example 右侧 Inspector 面板有 "Debug overlay" 开关。开启后，当前命中的 block 右上角叠加显示 `blockIndex`、`blockId`、`path`、`offset`，用于排查选区与定位问题。不影响布局与 offset 计算。

## 排查

- `flutter analyze` 在根目录应无问题。
- `flutter test` 在根目录运行全部单元 + widget 测试。
- example 单独分析：`cd example && flutter analyze`。
