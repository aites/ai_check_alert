class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.url,
    required this.publishedAt,
    required this.keywords,
    required this.fetchedAt,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final String summary;
  final String source;
  final String url;
  final DateTime publishedAt;
  final List<String> keywords;
  final DateTime fetchedAt;
  final bool isPinned;

  NewsArticle copyWith({
    String? id,
    String? title,
    String? summary,
    String? source,
    String? url,
    DateTime? publishedAt,
    List<String>? keywords,
    DateTime? fetchedAt,
    bool? isPinned,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      source: source ?? this.source,
      url: url ?? this.url,
      publishedAt: publishedAt ?? this.publishedAt,
      keywords: keywords ?? this.keywords,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  String get displayDateText => '${publishedAt.year}/${publishedAt.month}/${publishedAt.day}';
}

