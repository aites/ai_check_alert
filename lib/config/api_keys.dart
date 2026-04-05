class ApiKeys {
  static const String geminiApiKeyFromEnv = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
}
