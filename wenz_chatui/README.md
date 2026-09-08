# wenz_chatui

`wenz_chatui` 是一个面向长会话、流式 AI 回复和自定义消息卡片的 Flutter
聊天渲染组件。模块只依赖 Flutter SDK，不绑定网络、数据库、图片缓存或状态管理方案。

## 特性

- 基于反向 `SliverList` 的按需构建，万级消息不会一次性创建 Widget。
- 消息结构和单条内容分开通知；流式更新一条消息时只重建对应 cell。
- 稳定消息 Key 与 `findChildIndexCallback`，追加、删除或加载历史消息时复用元素状态。
- 在底部自动跟随新消息；用户阅读历史时保持位置并显示未读数量。
- 支持上拉加载历史、发送者分组、日期分隔、消息状态、明暗 Material 主题。
- 消息、头像、日期、空状态、加载状态和未读提示均可替换。

## 快速开始

```dart
import 'package:wenz_chatui/wenz_chatui.dart';

final controller = WenzChatController(
  initialMessages: [
    WenzChatMessage(
      id: '1',
      authorId: 'alice',
      authorName: 'Alice',
      sentAt: DateTime.now(),
      text: 'Hello',
    ),
  ],
);

WenzChatView(
  controller: controller,
  currentUserId: 'me',
  onLoadOlder: () async {
    final history = await repository.loadOlder();
    controller.prependAll(history); // 参数保持从旧到新的顺序
  },
);
```

发送新消息和更新状态：

```dart
controller.append(message);

controller.update(message.id, (current) {
  return current.copyWith(status: WenzChatMessageStatus.read);
});
```

流式 AI 回复应重复更新同一个消息 id。此路径不会触发列表结构重建：

```dart
controller.update('assistant-response', (current) {
  return current.copyWith(text: current.text + token);
});
```

## 自定义消息

业务数据可放在 `payload` 或 `metadata` 中，通过 `messageBuilder` 渲染。构建器会收到
出入方向、分组位置、头像和时间显示建议等上下文：

```dart
WenzChatView(
  controller: controller,
  currentUserId: currentUser.id,
  messageBuilder: (context, message, item) {
    if (message.kind == WenzChatMessageKind.custom) {
      return ProductCard(data: message.payload as ProductData);
    }
    return MyBubble(message: message, outgoing: item.isOutgoing);
  },
);
```

默认气泡可单独通过 `WenzChatBubble` 复用。整体主题使用 `WenzChatTheme` 注入，或直接把
`WenzChatThemeData` 传给某一个 `WenzChatView`。

## 数据和滚动约定

- 控制器始终保存“旧 → 新”的时间线，消息 id 必须唯一且稳定。
- `append/appendAll` 用于新消息；`prepend/prependAll` 用于更早的历史消息。
- 列表内部反向渲染，因此 offset `0` 是会话底部，加载历史不会改变当前 offset。
- 用户离开底部后，新消息不会抢走阅读位置；点击未读提示会返回底部。
- `WenzChatController`、外部传入的 `ScrollController` 均由创建方负责释放。

## 性能建议

- 流式文本使用 `update`，不要为每个 token 调用 `replaceAll`。
- 自定义 cell 内的大图或复杂画布应自行设置尺寸，并使用合适的缓存方案。
- 默认关闭 `addAutomaticKeepAlives`，避免长会话保留离屏状态；确实需要时可开启。
- `cacheExtent` 默认 600 logical pixels，可按 cell 复杂度和目标设备调节。

运行示例：

```sh
cd example
flutter run
```

运行检查：

```sh
flutter analyze
flutter test
```
