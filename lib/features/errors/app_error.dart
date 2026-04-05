enum AppErrorType {
  network,
  authentication,
  quota,
  parse,
  storage,
  unknown,
}

class AppError implements Exception {
  AppError({
    required this.type,
    required this.message,
    this.details,
  });

  final AppErrorType type;
  final String message;
  final String? details;

  bool get isRetryable {
    return switch (type) {
      AppErrorType.network => true,
      AppErrorType.quota => true,
      AppErrorType.storage => true,
      AppErrorType.authentication => false,
      AppErrorType.parse => false,
      AppErrorType.unknown => true,
    };
  }

  String get userMessage {
    return switch (type) {
      AppErrorType.network => 'ネットワーク接続に問題があります。',
      AppErrorType.authentication => 'Gemini APIキーが無効または未設定です。',
      AppErrorType.quota => 'Gemini APIの利用制限に到達しました。時間をあけて再試行してください。',
      AppErrorType.parse => 'ニュース形式の解析に失敗しました。',
      AppErrorType.storage => '保存処理でエラーが発生しました。',
      AppErrorType.unknown => '予期しないエラーが発生しました。',
    };
  }

  @override
  String toString() => '$message${details == null ? '' : ' ($details)'}';
}
