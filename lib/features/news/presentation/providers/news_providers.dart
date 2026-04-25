import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/datasources/local/news_local_datasource.dart';
import '../../data/datasources/remote/gemini_news_datasource.dart';
import '../../data/repositories/news_repository_impl.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/repositories/news_repository.dart';
import '../../domain/usecases/fetch_news_by_schedule.dart';
import '../../../notification/services/notification_service.dart';
import '../../../scheduler/services/scheduler_input.dart';
import '../../../scheduler/services/scheduler_service.dart';

part 'news_providers.g.dart';

final newsRemoteDataSourceProvider = Provider<GeminiNewsDataSource>((ref) {
  return GeminiNewsDataSourceImpl();
});

final newsLocalDataSourceProvider = Provider<NewsLocalDataSource>((ref) {
  return IsarNewsLocalDataSource();
});

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepositoryImpl(
    remoteDataSource: ref.watch(newsRemoteDataSourceProvider),
    localDataSource: ref.watch(newsLocalDataSourceProvider),
  );
});

final fetchNewsByScheduleUseCaseProvider = Provider<FetchNewsByScheduleUseCase>((ref) {
  return FetchNewsByScheduleUseCase(repository: ref.watch(newsRepositoryProvider));
});

final schedulerServiceProvider = Provider<SchedulerService>((ref) {
  return const SchedulerService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return const NotificationService();
});

@riverpod
Future<NewsSchedulerInput> newsSchedulerSettings(NewsSchedulerSettingsRef ref) {
  final service = ref.watch(schedulerServiceProvider);
  return service.loadSettings();
}

@riverpod
Stream<List<NewsArticle>> newsList(NewsListRef ref) {
  final repository = ref.watch(newsRepositoryProvider);
  return repository.watchNews();
}
