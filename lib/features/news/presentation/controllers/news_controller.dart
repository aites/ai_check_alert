import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../scheduler/services/scheduler_input.dart';
import '../../domain/usecases/fetch_news_by_schedule.dart';
import '../providers/news_providers.dart';

part 'news_controller.g.dart';

@riverpod
class NewsActionController extends _$NewsActionController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> manualFetch() async {
    state = const AsyncLoading();
    final repository = ref.read(newsRepositoryProvider);
    final settings = await ref.read(newsSchedulerSettingsProvider.future);

    final useCase = FetchNewsByScheduleUseCase(repository: repository);

    try {
      await useCase.execute(
        FetchNewsByScheduleParams(
          apiKey: settings.apiKey,
          keywords: settings.keywords,
          maxCount: 5,
        ),
      );
      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  Future<void> updateSettings(NewsSchedulerInput settings) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(schedulerServiceProvider);
      await service.saveSettings(settings);
      await service.scheduleDaily(settings);
      ref.invalidate(newsSchedulerSettingsProvider);
      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }
}
