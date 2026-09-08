import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_chatui/wenz_chatui.dart';

void main() {
  testWidgets('virtualizes a ten-thousand-message timeline', (tester) async {
    final controller = WenzChatController(
      initialMessages: List<WenzChatMessage>.generate(
        10000,
        (index) => _message(index),
      ),
    );
    addTearDown(controller.dispose);
    var buildCount = 0;

    await tester.pumpWidget(
      _host(
        WenzChatView(
          controller: controller,
          currentUserId: 'me',
          cacheExtent: 200,
          messageBuilder: (context, message, itemContext) {
            buildCount++;
            return SizedBox(height: 44, child: Text(message.text));
          },
        ),
      ),
    );

    expect(find.text('message 9999'), findsOneWidget);
    expect(buildCount, lessThan(50));
  });

  testWidgets('a content update rebuilds only its message cell', (
    tester,
  ) async {
    final controller = WenzChatController(
      initialMessages: List<WenzChatMessage>.generate(30, _message),
    );
    addTearDown(controller.dispose);
    final builtIds = <String>[];

    await tester.pumpWidget(
      _host(
        WenzChatView(
          controller: controller,
          currentUserId: 'me',
          messageBuilder: (context, message, itemContext) {
            builtIds.add(message.id);
            return SizedBox(height: 40, child: Text(message.text));
          },
        ),
      ),
    );
    builtIds.clear();

    controller.update(
      'm-29',
      (message) => message.copyWith(text: 'streamed response'),
    );
    await tester.pump();

    expect(builtIds, <String>['m-29']);
    expect(find.text('streamed response'), findsOneWidget);
  });

  testWidgets('shows unread count instead of stealing the scroll position', (
    tester,
  ) async {
    final controller = WenzChatController(
      initialMessages: List<WenzChatMessage>.generate(80, _message),
    );
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      _host(
        WenzChatView(
          controller: controller,
          scrollController: scrollController,
          currentUserId: 'me',
          messageBuilder: (context, message, itemContext) =>
              SizedBox(height: 40, child: Text(message.text)),
        ),
      ),
    );
    scrollController.jumpTo(400);
    await tester.pump();
    final offsetBeforeAppend = scrollController.offset;

    controller.append(_message(80));
    await tester.pump();

    expect(find.text('1 new'), findsOneWidget);
    expect(scrollController.offset, closeTo(offsetBeforeAppend, 0.01));
  });

  testWidgets('prepending history preserves the reverse-list scroll anchor', (
    tester,
  ) async {
    final controller = WenzChatController(
      initialMessages: List<WenzChatMessage>.generate(
        80,
        (index) => _message(index + 20),
      ),
    );
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      _host(
        WenzChatView(
          controller: controller,
          scrollController: scrollController,
          currentUserId: 'me',
          messageBuilder: (context, message, itemContext) =>
              SizedBox(height: 40, child: Text(message.text)),
        ),
      ),
    );
    scrollController.jumpTo(300);
    await tester.pump();
    final offsetBeforePrepend = scrollController.offset;

    controller.prependAll(List<WenzChatMessage>.generate(20, _message));
    await tester.pump();

    expect(scrollController.offset, closeTo(offsetBeforePrepend, 0.01));
  });

  testWidgets('appending near the bottom follows the newest message', (
    tester,
  ) async {
    final controller = WenzChatController(
      initialMessages: List<WenzChatMessage>.generate(80, _message),
    );
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      _host(
        WenzChatView(
          controller: controller,
          scrollController: scrollController,
          currentUserId: 'me',
          messageBuilder: (context, message, itemContext) =>
              SizedBox(height: 40, child: Text(message.text)),
        ),
      ),
    );
    scrollController.jumpTo(50);
    await tester.pump();

    controller.append(_message(80));
    await tester.pumpAndSettle();

    expect(scrollController.offset, closeTo(0, 0.01));
    expect(find.text('1 new'), findsNothing);
    expect(find.text('message 80'), findsOneWidget);
  });

  testWidgets('requests older messages once near the top threshold', (
    tester,
  ) async {
    final controller = WenzChatController(
      initialMessages: List<WenzChatMessage>.generate(80, _message),
    );
    final scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);
    var calls = 0;
    await tester.pumpWidget(
      _host(
        WenzChatView(
          controller: controller,
          scrollController: scrollController,
          currentUserId: 'me',
          onLoadOlder: () async {
            calls++;
          },
          messageBuilder: (context, message, itemContext) =>
              SizedBox(height: 40, child: Text(message.text)),
        ),
      ),
    );

    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('default renderer groups messages and creates date separators', (
    tester,
  ) async {
    final contexts = <String, WenzChatItemContext>{};
    final controller = WenzChatController(
      initialMessages: <WenzChatMessage>[
        _message(0, authorId: 'other'),
        _message(1, authorId: 'other'),
        _message(2, authorId: 'me'),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        WenzChatView(
          controller: controller,
          currentUserId: 'me',
          messageBuilder: (context, message, itemContext) {
            contexts[message.id] = itemContext;
            return SizedBox(height: 30, child: Text(message.text));
          },
        ),
      ),
    );

    expect(contexts['m-0']!.groupPosition, WenzChatGroupPosition.first);
    expect(contexts['m-1']!.groupPosition, WenzChatGroupPosition.last);
    expect(contexts['m-2']!.groupPosition, WenzChatGroupPosition.single);
    expect(contexts['m-0']!.isFirstMessageOfDay, isTrue);
    expect(contexts['m-1']!.isFirstMessageOfDay, isFalse);
  });

  testWidgets('removing and clearing visible messages release cell listeners', (
    tester,
  ) async {
    final controller = WenzChatController(
      initialMessages: List<WenzChatMessage>.generate(20, _message),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(WenzChatView(controller: controller, currentUserId: 'me')),
    );

    controller.remove('m-19');
    await tester.pump();
    controller.clear();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('No messages'), findsOneWidget);
  });
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 400, height: 700, child: child)),
  );
}

WenzChatMessage _message(int index, {String? authorId}) {
  return WenzChatMessage(
    id: 'm-$index',
    authorId: authorId ?? (index.isEven ? 'me' : 'other'),
    authorName: authorId == 'other' ? 'Taylor' : null,
    sentAt: DateTime.utc(2026, 1, 1, 12).add(Duration(minutes: index)),
    text: 'message $index',
  );
}
