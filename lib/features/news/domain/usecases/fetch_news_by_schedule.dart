import 'package:flutter/foundation.dart';

import '../entities/news_article.dart';
import '../repositories/news_repository.dart';

@immutable
class FetchNewsByScheduleParams {
  const FetchNewsByScheduleParams({
    required this.apiKey,
    required this.keywords,
    this.maxCount = 10,
  });

  final String apiKey;
  final List<String> keywords;
  final int maxCount;
}

class FetchNewsByScheduleUseCase {
  FetchNewsByScheduleUseCase({
    required NewsRepository repository,
    this.retention = const Duration(days: 7),
  }) : _repository = repository;

  final NewsRepository _repository;
  final Duration retention;

  Future<List<NewsArticle>> execute(FetchNewsByScheduleParams params) {
    return _repository.fetchAndStoreNews(
      apiKey: params.apiKey,
      keywords: params.keywords,
      maxCount: params.maxCount,
    ).then((articles) async {
      await _repository.deleteExpiredNews(retention);
      return articles;
    });
  }
}
