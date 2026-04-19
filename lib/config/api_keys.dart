import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  static const String geminiApiKeyFromDefine = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static String get geminiApiKeyFromEnv {
    final fromDotenv = dotenv.maybeGet('API_KEY')?.trim() ?? '';
    if (fromDotenv.isNotEmpty) {
      return fromDotenv;
    }
    return geminiApiKeyFromDefine;
  }
}
