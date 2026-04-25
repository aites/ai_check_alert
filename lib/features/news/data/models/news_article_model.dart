import 'package:isar/isar.dart';

import '../../domain/entities/news_article.dart';

part 'news_article_model.g.dart';

@Collection()
class NewsArticleModel {
  NewsArticleModel();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String sourceUrl;

  late String articleId;
  late String title;
  late String summary;
  late String content;
  late String category;
  late int importance;
  late String date;
  late DateTime fetchedAt;
  late bool isPinned;

  NewsArticle toEntity() {
    return NewsArticle(
      id: articleId,
      title: title,
      summary: summary,
      content: content,
      category: category,
      sourceUrl: sourceUrl,
      importance: importance,
      date: date,
      fetchedAt: fetchedAt,
      isPinned: isPinned,
    );
  }

  static NewsArticleModel fromEntity(NewsArticle article) {
    final model = NewsArticleModel();
    model.sourceUrl = article.sourceUrl;
    model.articleId = article.id;
    model.title = article.title;
    model.summary = article.summary;
    model.content = article.content;
    model.category = article.category;
    model.importance = article.importance;
    model.date = article.date;
    model.fetchedAt = article.fetchedAt;
    model.isPinned = article.isPinned;
    return model;
  }
}
