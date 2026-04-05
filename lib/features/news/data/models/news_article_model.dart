import 'package:isar/isar.dart';

import '../../domain/entities/news_article.dart';

part 'news_article_model.g.dart';

@Collection()
class NewsArticleModel {
  NewsArticleModel();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String stableId;

  late String title;
  late String summary;
  late String source;
  @Index()
  late String url;

  late DateTime publishedAt;
  late String keywords;
  late DateTime fetchedAt;
  late bool isPinned;

  NewsArticle toEntity() {
    return NewsArticle(
      id: stableId,
      title: title,
      summary: summary,
      source: source,
      url: url,
      publishedAt: publishedAt,
      keywords: keywords.split(',').where((e) => e.isNotEmpty).toList(),
      fetchedAt: fetchedAt,
      isPinned: isPinned,
    );
  }

  static NewsArticleModel fromEntity(NewsArticle article) {
    final model = NewsArticleModel();
    model.stableId = article.id;
    model.title = article.title;
    model.summary = article.summary;
    model.source = article.source;
    model.url = article.url;
    model.publishedAt = article.publishedAt;
    model.keywords = article.keywords.join(',');
    model.fetchedAt = article.fetchedAt;
    model.isPinned = article.isPinned;
    return model;
  }
}
