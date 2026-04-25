import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/news_article.dart';
import '../providers/news_providers.dart';

/// Displays details of a selected news article.
class NewsDetailPage extends ConsumerWidget {
  const NewsDetailPage({super.key, this.article, this.articleId});

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

/// Content section for an article detail.
class _NewsDetailBody extends StatelessWidget {
  const _NewsDetailBody({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(article.title, style: textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(article.category)),
              Chip(label: Text('重要度 ${article.importance}')),
              Chip(label: Text(article.displayDateText)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('要約', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(article.summary),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('本文', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(article.content),
          const SizedBox(height: 24),
          Text('ソースURL', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          SelectableText(article.sourceUrl),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: article.sourceUrl));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('URLをコピーしました。')));
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('URLをコピー'),
          ),
          if (article.sourceUrl.isEmpty)
            Text(
              '参照元URLがありません。',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
