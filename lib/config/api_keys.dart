import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  static String get geminiApiKeyFromEnv {
    return dotenv.maybeGet('GEMINI_API_KEY')?.trim() ?? '';
  }
}
