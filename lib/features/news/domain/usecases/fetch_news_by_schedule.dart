import 'package:flutter/foundation.dart';

import '../entities/news_article.dart';
import '../repositories/news_repository.dart';

/// Parameters used for scheduled news fetching.
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

/// Fetches latest news and persists them for scheduled background execution.
class FetchNewsByScheduleUseCase {
  FetchNewsByScheduleUseCase({required NewsRepository repository})
    : _repository = repository;

  final NewsRepository _repository;

  Future<List<NewsArticle>> execute(FetchNewsByScheduleParams params) {
    return _repository.fetchAndStoreNews(
      apiKey: params.apiKey,
      keywords: params.keywords,
      maxCount: params.maxCount,
    );
  }
}
