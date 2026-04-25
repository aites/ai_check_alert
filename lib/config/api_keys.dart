import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  /// Reads Gemini API key from supported environment variable names.
  ///
  /// Priority:
  /// 1. GEMINI_API_KEY
  /// 2. API_KEY (legacy compatibility)
  static String get geminiApiKeyFromEnv {
    final primary = dotenv.maybeGet('GEMINI_API_KEY')?.trim() ?? '';
    if (primary.isNotEmpty) {
      return primary;
    }

    return dotenv.maybeGet('API_KEY')?.trim() ?? '';
  }
}
