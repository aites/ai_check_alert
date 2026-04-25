import 'package:workmanager/workmanager.dart';

import '../../news/data/datasources/local/news_local_datasource.dart';
import '../../news/data/datasources/remote/gemini_news_datasource.dart';
import '../../news/data/repositories/news_repository_impl.dart';
import '../../news/domain/usecases/fetch_news_by_schedule.dart';
import '../../notification/services/notification_service.dart';
import '../../errors/app_error.dart';
import 'scheduler_input.dart';
import 'scheduler_service.dart';

@pragma('vm:entry-point')
void newsWorkerDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final input = inputData ?? <String, dynamic>{};
    final settings = NewsSchedulerInput.fromMap(
      input.map((key, value) => MapEntry(key.toString(), value)),
    );

    final repository = NewsRepositoryImpl(
      remoteDataSource: GeminiNewsDataSourceImpl(),
      localDataSource: IsarNewsLocalDataSource(),
    );
    final usecase = FetchNewsByScheduleUseCase(repository: repository);
    final notificationService = const NotificationService();
    final scheduler = const SchedulerService();

    await notificationService.initialize();

    try {
      final articles = await usecase.execute(
        FetchNewsByScheduleParams(
          apiKey: settings.apiKey,
          keywords: settings.keywords,
          maxCount: 5,
        ),
      );

      if (settings.notificationEnabled) {
        await notificationService.showNewsSummary(articles.length, articles);
      }

      await scheduler.saveSettings(settings.copyWith(failureCount: 0));
      await scheduler.scheduleDaily(settings);
      return true;
    } catch (error) {
      final message = error is AppError
          ? error.userMessage
          : 'ニュース取得中に予期しないエラーが発生しました。';

      final failureCount = settings.failureCount + 1;
      final canRetry = error is AppError ? error.isRetryable : true;

      if (canRetry && failureCount <= 3) {
        final delay = scheduler.retryDelay(failureCount);
        final retryInput = settings.copyWith(failureCount: failureCount);
        await scheduler.scheduleRetry(retryInput, delay);
      }

      if (canRetry && failureCount <= 3) {
        await notificationService.showError('$message (再試行回数: $failureCount)');
      } else {
        await notificationService.showError('ニュース取得が失敗しました。再設定を確認してください。');
      }

      return true;
    }
  });
}
