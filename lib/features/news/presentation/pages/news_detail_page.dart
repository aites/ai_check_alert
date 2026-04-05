import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/news_article.dart';
import '../providers/news_providers.dart';

class NewsDetailPage extends ConsumerWidget {
  const NewsDetailPage({
    super.key,
    this.article,
    this.articleId,
  });

  final NewsArticle? article;
  final String? articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNews = ref.watch(newsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ニュース詳細')),
      body: asyncNews.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('取得中にエラー: $error')),
        data: (newsList) {
          var target = article;
          if (target == null && articleId != null) {
            target = _findById(newsList, articleId!);
          }

          if (target == null) {
            return const Center(child: Text('記事が見つかりませんでした。'));
          }

          return _NewsDetailBody(article: target);
        },
      ),
    );
  }

  NewsArticle? _findById(List<NewsArticle> newsList, String id) {
    for (final item in newsList) {
      if (item.id == id) return item;
    }
    return null;
  }
}

class _NewsDetailBody extends StatelessWidget {
  const _NewsDetailBody({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text('ソース: ${article.source}'),
          const SizedBox(height: 4),
          Text('公開日: ${article.displayDateText}'),
          const SizedBox(height: 16),
          Text(article.summary),
          const SizedBox(height: 20),
          Text('キーワード: ${article.keywords.join(', ')}'),
          const SizedBox(height: 20),
          if (article.url.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                // 将来的にはWebView/外部ブラウザへ遷移
              },
              child: const Text('記事を開く'),
            ),
        ],
      ),
    );
  }
}
