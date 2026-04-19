import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/gemini_chat_provider.dart';

class GeminiChatPage extends ConsumerWidget {
  const GeminiChatPage({super.key});

  static const me = types.User(id: 'me');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(geminiChatControllerProvider);
    final notifier = ref.read(geminiChatControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Gemini Chat Sample')),
      body: Chat(
        user: me,
        messages: messages,
        onSendPressed: (partial) {
          notifier.ask(question: partial.text);
        },
      ),
    );
  }
}
