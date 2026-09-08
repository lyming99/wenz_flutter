import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_chatui/wenz_chatui.dart';

void main() {
  group('WenzChatController', () {
    test('keeps chronological order across prepend and append', () {
      final controller = WenzChatController(
        initialMessages: <WenzChatMessage>[_message('middle', minute: 1)],
      );
      addTearDown(controller.dispose);

      controller.prepend(_message('oldest'));
      controller.append(_message('newest', minute: 2));

      expect(controller.messages.map((message) => message.id), <String>[
        'oldest',
        'middle',
        'newest',
      ]);
      expect(controller.indexOf('middle'), 1);
    });

    test('content updates notify only the affected message signal', () {
      final controller = WenzChatController(
        initialMessages: <WenzChatMessage>[
          _message('a'),
          _message('b', minute: 1),
        ],
      );
      addTearDown(controller.dispose);
      var structureNotifications = 0;
      var controllerNotifications = 0;
      var firstMessageNotifications = 0;
      var secondMessageNotifications = 0;
      controller.structureListenable.addListener(() {
        structureNotifications++;
      });
      controller.addListener(() => controllerNotifications++);
      controller.messageListenableAt(0).addListener(() {
        firstMessageNotifications++;
      });
      controller.messageListenableAt(1).addListener(() {
        secondMessageNotifications++;
      });

      controller.update(
        'b',
        (message) => message.copyWith(text: 'streamed token'),
      );

      expect(structureNotifications, 0);
      expect(controllerNotifications, 1);
      expect(firstMessageNotifications, 0);
      expect(secondMessageNotifications, 1);
      expect(controller.messageById('b')!.text, 'streamed token');
    });

    test('layout identity changes invalidate the structure', () {
      final controller = WenzChatController(
        initialMessages: <WenzChatMessage>[_message('a')],
      );
      addTearDown(controller.dispose);
      var structureNotifications = 0;
      controller.structureListenable.addListener(() {
        structureNotifications++;
      });

      controller.update(
        'a',
        (message) => message.copyWith(authorId: 'another-user'),
      );

      expect(structureNotifications, 1);
      expect(controller.lastMutation!.type, WenzChatMutationType.update);
    });

    test('rejects duplicate ids atomically', () {
      final controller = WenzChatController(
        initialMessages: <WenzChatMessage>[_message('a')],
      );
      addTearDown(controller.dispose);

      expect(
        () => controller.appendAll(<WenzChatMessage>[
          _message('b'),
          _message('b', minute: 1),
        ]),
        throwsArgumentError,
      );
      expect(controller.length, 1);
    });

    test('replaceAll reuses retained per-message listenables', () {
      final controller = WenzChatController(
        initialMessages: <WenzChatMessage>[_message('a')],
      );
      addTearDown(controller.dispose);
      final ValueListenable<WenzChatMessage> original = controller
          .messageListenableAt(0);

      controller.replaceAll(<WenzChatMessage>[
        _message('a').copyWith(text: 'updated'),
        _message('b', minute: 1),
      ]);

      expect(identical(original, controller.messageListenableAt(0)), isTrue);
      expect(original.value.text, 'updated');
    });

    test('copyWith can explicitly clear nullable presentation data', () {
      final message = _message(
        'a',
      ).copyWith(authorName: 'Author', payload: 'payload');

      final cleared = message.copyWith(authorName: null, payload: null);

      expect(cleared.authorName, isNull);
      expect(cleared.payload, isNull);
    });
  });
}

WenzChatMessage _message(String id, {int minute = 0}) {
  return WenzChatMessage(
    id: id,
    authorId: 'user',
    sentAt: DateTime.utc(2026, 1, 1, 12, minute),
    text: id,
  );
}
