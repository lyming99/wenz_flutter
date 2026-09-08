import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wenz_chatui/wenz_chatui.dart';

void main() => runApp(const ChatExampleApp());

class ChatExampleApp extends StatelessWidget {
  const ChatExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xff4f46e5),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xff818cf8),
        brightness: Brightness.dark,
      ),
      home: const ChatExamplePage(),
    );
  }
}

class ChatExamplePage extends StatefulWidget {
  const ChatExamplePage({super.key});

  @override
  State<ChatExamplePage> createState() => _ChatExamplePageState();
}

class _ChatExamplePageState extends State<ChatExamplePage> {
  late final WenzChatController _controller;
  final _composer = TextEditingController();
  var _nextId = 30;
  var _oldestId = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _controller = WenzChatController(
      initialMessages: List<WenzChatMessage>.generate(30, (index) {
        final outgoing = index.isEven;
        return WenzChatMessage(
          id: 'message-$index',
          authorId: outgoing ? 'me' : 'assistant',
          authorName: outgoing ? 'You' : 'Wenz',
          sentAt: now.subtract(Duration(minutes: 30 - index)),
          text: outgoing
              ? 'Message $index'
              : 'This timeline only builds visible rows. Message $index.',
          status: WenzChatMessageStatus.read,
        );
      }),
    );
  }

  Future<void> _loadOlder() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final now = _controller.messageAt(0).sentAt;
    final messages = List<WenzChatMessage>.generate(20, (index) {
      final id = _oldestId - 20 + index;
      return WenzChatMessage(
        id: 'history-$id',
        authorId: index.isEven ? 'me' : 'assistant',
        authorName: index.isEven ? 'You' : 'Wenz',
        sentAt: now.subtract(Duration(minutes: 20 - index)),
        text: 'Loaded history message $id',
        status: WenzChatMessageStatus.read,
      );
    });
    _oldestId -= 20;
    _controller.prependAll(messages);
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    final id = 'message-${_nextId++}';
    _controller.append(
      WenzChatMessage(
        id: id,
        authorId: 'me',
        authorName: 'You',
        sentAt: DateTime.now(),
        text: text,
        status: WenzChatMessageStatus.sending,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 550));
    _controller.update(
      id,
      (message) => message.copyWith(status: WenzChatMessageStatus.read),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wenz ChatUI')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: WenzChatView(
              controller: _controller,
              currentUserId: 'me',
              onLoadOlder: _loadOlder,
              onMessageLongPress: (message) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Long pressed ${message.id}')),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _composer.dispose();
    _controller.dispose();
    super.dispose();
  }
}
