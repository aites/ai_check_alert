import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'scheduler_input.dart';

class SchedulerService {
  static const _taskName = 'news.fetch';
  static const _taskUniqueName = 'news_fetch_worker';
  static const _prefsPrefix = 'news_app';
  static const _prefsApiKey = '$_prefsPrefix.apiKey';
  static const _prefsKeywords = '$_prefsPrefix.keywords';
  static const _prefsHour = '$_prefsPrefix.hour';
  static const _prefsMinute = '$_prefsPrefix.minute';
  static const _prefsNotificationEnabled = '$_prefsPrefix.notifications';
  static const _prefsFailureCount = '$_prefsPrefix.failureCount';

  const SchedulerService();

  Future<NewsSchedulerInput> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rawKeywords = prefs.getString(_prefsKeywords) ?? '';
    final parsedKeywords = rawKeywords
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return NewsSchedulerInput(
      apiKey: prefs.getString(_prefsApiKey) ?? '',
      keywords: parsedKeywords,
      scheduledHour: prefs.getInt(_prefsHour) ?? NewsSchedulerInput.defaults.scheduledHour,
      scheduledMinute: prefs.getInt(_prefsMinute) ?? NewsSchedulerInput.defaults.scheduledMinute,
      notificationEnabled:
          prefs.getBool(_prefsNotificationEnabled) ?? NewsSchedulerInput.defaults.notificationEnabled,
      failureCount: prefs.getInt(_prefsFailureCount) ?? 0,
    );
  }

  Future<void> saveSettings(NewsSchedulerInput input) async {
    final prefs = await SharedPreferences.getInstance();
    final data = input.toPrefsMap();
    await prefs.setString(_prefsApiKey, data['apiKey'] as String);
    await prefs.setString(_prefsKeywords, data['keywords'] as String);
    await prefs.setInt(_prefsHour, data['scheduledHour'] as int);
    await prefs.setInt(_prefsMinute, data['scheduledMinute'] as int);
    await prefs.setBool(_prefsNotificationEnabled, data['notificationEnabled'] == 1);
    await prefs.setInt(_prefsFailureCount, data['failureCount'] as int);
  }

  Future<void> scheduleDaily(NewsSchedulerInput input) async {
    if (!input.notificationEnabled || input.apiKey.isEmpty) {
      await cancel();
      return;
    }

    final now = DateTime.now();
    var target = DateTime(
      now.year,
      now.month,
      now.day,
      input.scheduledHour,
      input.scheduledMinute,
    );

    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }

    final initialDelay = target.difference(now);
    await Workmanager().registerOneOffTask(
      _taskUniqueName,
      _taskName,
      initialDelay: initialDelay,
      inputData: input.toWorkerInput(),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  Future<void> scheduleRetry(NewsSchedulerInput input, Duration delay) async {
    final retryInput = input.copyWith(failureCount: input.failureCount + 1);
    await saveSettings(retryInput);
    await Workmanager().registerOneOffTask(
      '${_taskUniqueName}_retry_${retryInput.failureCount}',
      _taskName,
      initialDelay: delay,
      inputData: retryInput.toWorkerInput(),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  Future<void> restoreScheduleOnAppStart() async {
    final settings = await loadSettings();
    await scheduleDaily(settings);
  }

  Duration retryDelay(int failureCount) {
    if (failureCount <= 1) return const Duration(minutes: 2);
    if (failureCount == 2) return const Duration(minutes: 10);
    return const Duration(minutes: 30);
  }

  Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(_taskUniqueName);
  }
}
