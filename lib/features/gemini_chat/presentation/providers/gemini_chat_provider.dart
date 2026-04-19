import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../../config/api_keys.dart';

final geminiApiKeyProvider = Provider<String>((ref) {
  return ApiKeys.geminiApiKeyFromEnv.trim();
});

final geminiModelProvider = Provider<GenerativeModel?>((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  if (apiKey.isEmpty) {
    return null;
  }
  return GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
});

final geminiChatControllerProvider =
    StateNotifierProvider.autoDispose<
      GeminiChatController,
      List<types.Message>
    >((ref) {
      final model = ref.watch(geminiModelProvider);
      return GeminiChatController(model: model);
    });

class GeminiChatController extends StateNotifier<List<types.Message>> {
  GeminiChatController({required GenerativeModel? model})
    : _model = model,
      super(const []) {
    _chat = _model?.startChat();
  }

  static const gemini = types.User(id: 'gemini');
  static const me = types.User(id: 'me');

  final GenerativeModel? _model;
  ChatSession? _chat;

  bool get canTalk => _model != null;

  void addMessage({required types.User author, required String text}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final message = types.TextMessage(
      author: author,
      id: timestamp,
      text: text,
    );
    state = [message, ...state];
  }

  Future<void> ask({required String question}) async {
    if (question.trim().isEmpty) return;

    if (!canTalk) {
      addMessage(author: gemini, text: 'API_KEY が未設定です。.env を確認してください。');
      return;
    }

    addMessage(author: me, text: question.trim());

    try {
      final response = await _chat!.sendMessage(Content.text(question.trim()));
      final message = response.text?.trim();
      addMessage(
        author: gemini,
        text: (message == null || message.isEmpty)
            ? 'No response text'
            : message,
      );
    } on Exception {
      addMessage(author: gemini, text: 'Retry later');
    }
  }
}
