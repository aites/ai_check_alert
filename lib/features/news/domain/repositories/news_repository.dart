import '../entities/news_article.dart';

abstract class NewsRepository {
  Future<List<NewsArticle>> fetchAndStoreNews({
    required String apiKey,
    required List<String> keywords,
    int maxCount = 10,
  });

  Stream<List<NewsArticle>> watchNews();

  Future<void> deleteExpiredNews(Duration keepFor);

  Future<NewsArticle?> findByUrl(String url);
}
