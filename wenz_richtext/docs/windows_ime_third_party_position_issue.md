# Windows 第三方输入法候选框位置问题记录

## 现象

在 Windows 上，微软默认中文输入法在 Flutter 应用中候选框位置基本正常；但切换到第三方输入法，例如搜狗输入法时，候选框位置可能偏移、遮挡输入内容，或没有贴合当前 caret / composing 文本位置。

同一台机器上观察到：

- Google Chrome 搜索输入框中，搜狗输入法候选框位置正常。
- Flutter 应用内，即使使用原生 `TextField`，搜狗输入法候选框位置也异常。
- Flutter 应用内使用微软默认输入法时位置正常。

这说明该问题不是 `wenz_richtext` 自定义编辑器单独造成的；如果 Flutter 自带 `TextField` 也复现，根因在 Flutter Windows 文本输入通道与第三方 IME 的兼容层。

## 原因判断

Flutter Windows 文本输入不是原生 Win32 `EDIT` 控件。文本由 Flutter/Skia 自绘，平台输入法候选框位置依赖下面的链路：

```text
EditableText / 自定义 TextInputClient
  -> TextInputConnection.setEditableSizeAndTransform
  -> TextInputConnection.setCaretRect
  -> TextInputConnection.setComposingRect
  -> Flutter Windows engine
  -> Windows TSF / IMM / 第三方 IME
```

Flutter framework 侧的 `EditableText` 会在布局后上报：

- 整个可编辑区域的 `size + transform`
- 当前 caret 的本地矩形
- 当前 composing 区域的本地矩形

`wenz_richtext` 已按这个模式上报几何信息，避免把一个 1px caret rect 错当成整个 editable box。

但第三方输入法并不总是完全按同一条 TSF 路径处理位置。一些输入法可能：

- 对 Flutter 这种“虚拟文本控件”兼容不足。
- 对 `caretRect` / `composingRect` 的窗口坐标、屏幕坐标或 DPI 缩放解释不一致。
- 在组合输入首字符、候选窗更新时机、候选窗避让策略上使用自己的逻辑。
- 更依赖传统 Win32 原生输入控件行为，而不是 Flutter engine 提供的文本几何信息。

Chrome 不是一个好的对照基准，因为 Chromium 有自己的 Windows IME 适配层，并长期维护大量第三方输入法兼容逻辑。Chrome 中正常，不代表 Flutter Windows engine 对同一第三方 IME 也能正常。

## 当前结论

该问题属于 Flutter Windows engine / 第三方输入法兼容问题。

如果 Flutter `TextField + 搜狗输入法` 本身候选框就不正确，那么 `wenz_richtext` 最多只能做到：

- 几何上报方式与 `EditableText/TextField` 对齐。
- 保证自定义编辑器不额外引入错误，例如 editable box、caret rect、composing rect 上报错误。
- 在组合输入期间避免主动重置平台 editing state，减少输入法状态错乱。

但无法在 package 层完全修复第三方 IME 对 Flutter Windows 输入通道的兼容问题。

## 已做的本地修复

`wenz_richtext` 已做以下防护：

- 输入桥按 `EditableText` 模式上报完整 editable surface 的 `size + transform`。
- 单独上报本地 `caretRect` 和 `composingRect`。
- IME 组合态期间不反向 `setEditingState` 重置平台输入 buffer。
- composition 下划线只渲染正在组合的文本片段，不再误装饰整行或整个 `TextRun`。
- 针对 stale offset、拼音提交、非 delta IME fallback 增加回归测试。

## 后续可选方案

短期：

- 在 Windows 上优先建议用户使用微软默认输入法。
- 保持自定义编辑器的 TextInput 几何上报与 Flutter `EditableText` 行为一致。
- 避免在 composition 期间频繁重置平台 editing state。

中期：

- 跟踪 Flutter upstream Windows IME 相关 issue。
- 升级 Flutter SDK 后回归验证搜狗输入法、QQ 输入法、微信输入法等第三方 IME。

长期：

- 如果业务必须支持特定第三方输入法，可考虑 patch Flutter Windows engine 的 IME / TSF 实现。
- 或实现自绘候选辅助层，但这只能覆盖特定交互，不能真正替代系统 IME 候选窗。

## 相关链接

- Flutter issue: [Windows third-party IME candidate window position issue](https://github.com/flutter/flutter/issues/152729)
- Flutter duplicate issue: [Chinese IME candidate window position problem](https://github.com/flutter/flutter/issues/173526)
- Microsoft: [Third-party input method editors](https://learn.microsoft.com/en-us/windows/win32/w8cookbook/third-party-input-method-editors)
