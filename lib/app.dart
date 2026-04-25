import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'config/router.dart';
import 'features/news/data/datasources/local/news_local_datasource.dart';
import 'features/notification/services/notification_service.dart';
import 'features/scheduler/services/scheduler_service.dart';
import 'features/scheduler/services/scheduler_worker.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _notificationService = const NotificationService();
  final _newsLocalDataSource = IsarNewsLocalDataSource();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _notificationService.initialize(
      onDidReceiveNotificationResponse: (response) {
        // payload は後続で遷移に使用します。
      },
    );

    await Workmanager().initialize(newsWorkerDispatcher);
    await _purgeExpiredNewsOnAppStart();
    await const SchedulerService().restoreScheduleOnAppStart();
  }

  /// Deletes persisted news older than 14 days during app startup.
  Future<void> _purgeExpiredNewsOnAppStart() async {
    final threshold = DateTime.now().subtract(const Duration(days: 14));
    await _newsLocalDataSource.deleteExpired(threshold);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Gemini News Scheduler',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      routerConfig: AppRouter.router,
    );
  }
}
