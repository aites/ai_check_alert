import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../../config/api_keys.dart';
import '../../../../config/gemini_models.dart';

final geminiApiKeyProvider = Provider<String>((ref) {
  return ApiKeys.geminiApiKeyFromEnv.trim();
});

final geminiModelProvider = Provider<GenerativeModel?>((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  if (apiKey.isEmpty) {
    return null;
  }
  return GenerativeModel(model: geminiModelCandidates.first, apiKey: apiKey);
});

final geminiChatControllerProvider =
    StateNotifierProvider.autoDispose<
      GeminiChatController,
      List<types.Message>
    >((ref) {
      final apiKey = ref.watch(geminiApiKeyProvider);
      return GeminiChatController(apiKey: apiKey);
    });

class GeminiChatController extends StateNotifier<List<types.Message>> {
  GeminiChatController({required String apiKey})
    : _apiKey = apiKey,
      super(const []);

  static const gemini = types.User(id: 'gemini');
  static const me = types.User(id: 'me');

  final String _apiKey;
  String? _activeModel;
  ChatSession? _chat;

  bool get canTalk => _apiKey.trim().isNotEmpty;

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
      addMessage(author: gemini, text: 'GEMINI_API_KEY が未設定です。.env を確認してください。');
      return;
    }

    addMessage(author: me, text: question.trim());

    try {
      final response = await _sendWithModelFallback(question.trim());
      final message = response.text?.trim();
      addMessage(
        author: gemini,
        text: (message == null || message.isEmpty)
            ? 'No response text'
            : message,
      );
    } catch (error) {
      addMessage(author: gemini, text: _toUserReadableError(error));
    }
  }

  Future<GenerateContentResponse> _sendWithModelFallback(
    String question,
  ) async {
    Object? lastError;

    for (final modelName in geminiModelCandidates) {
      try {
        if (_activeModel != modelName || _chat == null) {
          final model = GenerativeModel(model: modelName, apiKey: _apiKey);
          _chat = model.startChat();
          _activeModel = modelName;
        }

        final response = await _chat!
            .sendMessage(Content.text(question))
            .timeout(const Duration(seconds: 25));
        return response;
      } catch (error) {
        lastError = error;
        if (_isModelNotFound(error)) {
          _chat = null;
          _activeModel = null;
          continue;
        }
        rethrow;
      }
    }

    throw StateError(
      'No supported Gemini model found. Tried: ${geminiModelCandidates.join(', ')}. Last error: $lastError',
    );
  }

  bool _isModelNotFound(Object error) {
    final lower = error.toString().toLowerCase();
    return lower.contains('not found for api version') &&
        lower.contains('model');
  }

  String _toUserReadableError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();

    if (lower.contains('api key not valid') ||
        lower.contains('permission denied') ||
        lower.contains('403')) {
      return '接続失敗: APIキーが無効か権限不足です。Google AI Studio のキー設定を確認してください。\n詳細: $raw';
    }

    if (lower.contains('429') || lower.contains('quota')) {
      return '接続失敗: 利用上限(Quota)の可能性があります。しばらく待って再試行してください。\n詳細: $raw';
    }

    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('timed out') ||
        lower.contains('timeoutexception')) {
      return '接続失敗: ネットワーク到達性に問題があります。回線またはVPN設定を確認してください。\n詳細: $raw';
    }

    if ((lower.contains('404') && lower.contains('model')) ||
        (lower.contains('not found for api version') &&
            lower.contains('model'))) {
      return '接続失敗: 指定モデルが利用できません。モデル名やAPIバージョンを確認してください。\n詳細: $raw';
    }

    return '接続失敗: 原因を特定できませんでした。\n詳細: $raw';
  }
}
