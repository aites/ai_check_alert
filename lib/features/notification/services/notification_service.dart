import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../news/domain/entities/news_article.dart';

class NotificationService {
  const NotificationService();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize({
    void Function(NotificationResponse)? onDidReceiveNotificationResponse,
  }) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(
      android: android,
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    const channel = AndroidNotificationChannel(
      'news_fetch_channel',
      'ニュース取得',
      description: 'ニュース取得結果の通知',
      importance: Importance.high,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
  }

  Future<void> showNewsSummary(int count, List<NewsArticle> latestArticles) async {
    final title = 'ニュース取得完了';
    final body =
        count > 0
            ? '$count件の新着ニュースを保存しました。'
            : '新着ニュースは見つかりませんでした。';
    await _showNotification(title: title, body: body, payload: latestArticles.firstOrNull?.url);
  }

  Future<void> showError(String message) async {
    await _showNotification(
      title: 'ニュース取得エラー',
      body: message,
    );
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'news_fetch_channel',
        'ニュース取得',
        channelDescription: 'ニュース取得結果の通知',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final id = Random().nextInt(1 << 30);
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
