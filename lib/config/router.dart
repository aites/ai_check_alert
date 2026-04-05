import 'package:go_router/go_router.dart';

import '../features/news/domain/entities/news_article.dart';
import '../features/news/presentation/pages/news_detail_page.dart';
import '../features/news/presentation/pages/news_home_page.dart';
import '../features/news/presentation/pages/settings_page.dart';

class AppRouter {
  static final router = GoRouter(
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        name: 'newsHome',
        path: '/',
        builder: (context, state) => const NewsHomePage(),
      ),
      GoRoute(
        name: 'settings',
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        name: 'newsDetail',
        path: '/news/detail',
        builder: (context, state) {
          final article = state.extra is NewsArticle
              ? state.extra as NewsArticle
              : null;
          final articleId = state.uri.queryParameters['id'];
          return NewsDetailPage(article: article, articleId: articleId);
        },
      ),
    ],
  );
}
