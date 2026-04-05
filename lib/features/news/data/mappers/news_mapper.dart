import '../../domain/entities/news_article.dart';
import '../models/news_article_model.dart';

extension NewsArticleMapper on NewsArticleModel {
  NewsArticle toDomain() => toEntity();
}

extension NewsArticleDomainToModel on NewsArticle {
  NewsArticleModel toModel() => NewsArticleModel.fromEntity(this);
}
