class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.category,
    required this.sourceUrl,
    required this.importance,
    required this.date,
    required this.fetchedAt,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final String summary;
  final String content;
  final String category;
  final String sourceUrl;
  final int importance;
  final String date;
  final DateTime fetchedAt;
  final bool isPinned;

  // Temporary compatibility accessors for existing UI/read paths.
  String get source => category;
  String get url => sourceUrl;
  DateTime get publishedAt => DateTime.tryParse(date) ?? fetchedAt;
  List<String> get keywords => const <String>[];

  NewsArticle copyWith({
    String? id,
    String? title,
    String? summary,
    String? content,
    String? category,
    String? sourceUrl,
    int? importance,
    String? date,
    DateTime? fetchedAt,
    bool? isPinned,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      category: category ?? this.category,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      importance: importance ?? this.importance,
      date: date ?? this.date,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  String get displayDateText => date;
}
