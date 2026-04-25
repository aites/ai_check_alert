import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../../domain/entities/news_article.dart';
import '../../models/news_article_model.dart';
import '../../mappers/news_mapper.dart';

abstract class NewsLocalDataSource {
  Stream<List<NewsArticleModel>> watchNews();

  Future<void> saveNews(List<NewsArticle> articles);

  Future<void> deleteExpired(DateTime threshold);

  Future<NewsArticleModel?> findBySourceUrl(String sourceUrl);

  Future<List<NewsArticleModel>> getAllNews();

  Future<void> clearAll();
}

class IsarNewsLocalDataSource implements NewsLocalDataSource {
  IsarNewsLocalDataSource() {
    _isarFuture = _getOrOpenDb();
  }

  late final Future<Isar> _isarFuture;
  static const _dbName = 'news_db';
  static Future<Isar>? _sharedIsarFuture;

  Future<Isar> _getOrOpenDb() {
    final existing = Isar.getInstance(_dbName);
    if (existing != null) {
      return Future<Isar>.value(existing);
    }

    final inFlight = _sharedIsarFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final opening = _openDbInternal();
    _sharedIsarFuture = opening;
    return opening;
  }

  Future<Isar> _openDbInternal() async {
    final existing = Isar.getInstance(_dbName);
    if (existing != null) {
      return existing;
    }

    final dir = await getApplicationDocumentsDirectory();
    try {
      return await Isar.open(
        [NewsArticleModelSchema],
        directory: dir.path,
        name: _dbName,
      );
    } catch (_) {
      _sharedIsarFuture = null;
      rethrow;
    }
  }

  @override
  Future<void> saveNews(List<NewsArticle> articles) async {
    final isar = await _isarFuture;
    final models = articles.map((article) => article.toModel()).toList();

    await isar.writeTxn(() async {
      await isar.newsArticleModels.putAll(models);
    });
  }

  @override
  Stream<List<NewsArticleModel>> watchNews() async* {
    final isar = await _isarFuture;
    yield* isar.newsArticleModels.where().sortByFetchedAtDesc().watch(
      fireImmediately: true,
    );
  }

  @override
  Future<void> deleteExpired(DateTime threshold) async {
    final isar = await _isarFuture;
    final ids = await isar.newsArticleModels
        .filter()
        .fetchedAtLessThan(threshold)
        .idProperty()
        .findAll();

    if (ids.isEmpty) {
      return;
    }

    await isar.writeTxn(() async {
      await isar.newsArticleModels.deleteAll(ids);
    });
  }

  @override
  Future<NewsArticleModel?> findBySourceUrl(String sourceUrl) async {
    final isar = await _isarFuture;
    return isar.newsArticleModels
        .filter()
        .sourceUrlEqualTo(sourceUrl)
        .findFirst();
  }

  @override
  Future<List<NewsArticleModel>> getAllNews() async {
    final isar = await _isarFuture;
    return isar.newsArticleModels.where().sortByFetchedAtDesc().findAll();
  }

  @override
  Future<void> clearAll() async {
    final isar = await _isarFuture;
    await isar.writeTxn(() async {
      await isar.newsArticleModels.clear();
    });
  }
}
