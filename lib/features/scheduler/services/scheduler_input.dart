class NewsSchedulerInput {
  const NewsSchedulerInput({
    required this.apiKey,
    required this.keywords,
    required this.scheduledHour,
    required this.scheduledMinute,
    required this.notificationEnabled,
    this.failureCount = 0,
  });

  final String apiKey;
  final List<String> keywords;
  final int scheduledHour;
  final int scheduledMinute;
  final bool notificationEnabled;
  final int failureCount;

  static const defaults = NewsSchedulerInput(
    apiKey: '',
    keywords: <String>[],
    scheduledHour: 9,
    scheduledMinute: 0,
    notificationEnabled: true,
  );

  NewsSchedulerInput copyWith({
    String? apiKey,
    List<String>? keywords,
    int? scheduledHour,
    int? scheduledMinute,
    bool? notificationEnabled,
    int? failureCount,
  }) {
    return NewsSchedulerInput(
      apiKey: apiKey ?? this.apiKey,
      keywords: keywords ?? this.keywords,
      scheduledHour: scheduledHour ?? this.scheduledHour,
      scheduledMinute: scheduledMinute ?? this.scheduledMinute,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      failureCount: failureCount ?? this.failureCount,
    );
  }

  Map<String, dynamic> toPrefsMap() => {
        'apiKey': apiKey,
        'keywords': keywords.join('|'),
        'scheduledHour': scheduledHour,
        'scheduledMinute': scheduledMinute,
        'notificationEnabled': notificationEnabled ? 1 : 0,
        'failureCount': failureCount,
      };

  Map<String, dynamic> toWorkerInput() => {
        'apiKey': apiKey,
        'keywords': keywords.join('|'),
        'scheduledHour': scheduledHour,
        'scheduledMinute': scheduledMinute,
        'notificationEnabled': notificationEnabled ? 1 : 0,
        'failureCount': failureCount,
      };

  factory NewsSchedulerInput.fromMap(Map<String, dynamic> map) {
    final rawKeywords = map['keywords'];
    final parsedKeywords = rawKeywords is String
        ? rawKeywords
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    final hour = map['scheduledHour'];
    final minute = map['scheduledMinute'];

    return NewsSchedulerInput(
      apiKey: map['apiKey']?.toString() ?? '',
      keywords: parsedKeywords,
      scheduledHour: hour is int ? hour : int.tryParse(hour?.toString() ?? '') ?? 9,
      scheduledMinute: minute is int ? minute : int.tryParse(minute?.toString() ?? '') ?? 0,
      notificationEnabled:
          (map['notificationEnabled'] as int?) == 1 ||
          map['notificationEnabled'] == true,
      failureCount: map['failureCount'] is int ? map['failureCount'] as int : 0,
    );
  }
}
