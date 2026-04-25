import 'package:collection/collection.dart';

import '../../domain/entities/news_article.dart';
import '../../domain/repositories/news_repository.dart';
import '../datasources/local/news_local_datasource.dart';
import '../datasources/remote/gemini_news_datasource.dart';
import '../mappers/news_mapper.dart';

/// Remote/local data synchronization repository for news articles.
class NewsRepositoryImpl implements NewsRepository {
  NewsRepositoryImpl({
    required GeminiNewsDataSource remoteDataSource,
    required NewsLocalDataSource localDataSource,
    this.retention = const Duration(days: 14),
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  final GeminiNewsDataSource _remoteDataSource;
  final NewsLocalDataSource _localDataSource;
  final Duration retention;

  @override
  Future<List<NewsArticle>> fetchAndStoreNews({
    required String apiKey,
    required List<String> keywords,
    int maxCount = 10,
  }) async {
    final normalizedKeywords = keywords
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final fetched = await _remoteDataSource.fetchLatestNews(
      apiKey: apiKey,
      keywords: normalizedKeywords,
      maxCount: maxCount,
    );

    final deduped = _dedupeByUrl(fetched);
    final now = DateTime.now();
    final toSave = deduped
        .map((article) => article.copyWith(fetchedAt: now))
        .toList(growable: false);

    await _localDataSource.saveNews(toSave);
    await deleteExpiredNews(retention);
    return toSave;
  }

  @override
  Stream<List<NewsArticle>> watchNews() {
    return _localDataSource.watchNews().map(
      (models) =>
          models.map((model) => model.toDomain()).toList(growable: false),
    );
  }

  @override
  Future<void> deleteExpiredNews(Duration keepFor) async {
    final threshold = DateTime.now().subtract(keepFor);
    await _localDataSource.deleteExpired(threshold);
  }

  @override
  Future<NewsArticle?> findByUrl(String url) async {
    final all = await _localDataSource.getAllNews();
    final found = all.firstWhereOrNull((item) => item.sourceUrl == url);
    return found?.toDomain();
  }

  List<NewsArticle> _dedupeByUrl(List<NewsArticle> source) {
    final seen = <String>{};
    final result = <NewsArticle>[];
    for (final article in source) {
      final key = article.sourceUrl.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(article);
    }
    return result;
  }
}
