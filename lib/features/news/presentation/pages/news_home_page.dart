import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../errors/app_error.dart';
import '../../domain/entities/news_article.dart';
import '../controllers/news_controller.dart';
import '../providers/news_providers.dart';

class NewsHomePage extends ConsumerWidget {
  const NewsHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsListProvider);
    final actionState = ref.watch(newsActionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geminiニュース取得'),
        actions: [
          IconButton(
            onPressed: () => context.pushNamed('geminiChat'),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            onPressed: () => context.pushNamed('settings'),
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            onPressed: () async {
              await ref
                  .read(newsActionControllerProvider.notifier)
                  .manualFetch();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (actionState is AsyncError)
            Container(
              width: double.infinity,
              color: Colors.red.withOpacity(0.08),
              padding: const EdgeInsets.all(12),
              child: Text(
                _errorMessage(actionState.error),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: newsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('まだ保存済みニュースはありません。'));
                }

                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(newsActionControllerProvider.notifier)
                      .manualFetch(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final article = items[index];
                      return _NewsListTile(article: article);
                    },
                  ),
                );
              },
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('データ取得エラー: ${error.toString()}'),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is AppError) {
      return error.userMessage;
    }
    if (error is Exception) {
      return error.toString();
    }
    return '通信エラーが発生しました。';
  }
}

class _NewsListTile extends ConsumerWidget {
  const _NewsListTile({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(
          article.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          article.source.isEmpty
              ? '不明'
              : '${article.source} · ${article.displayDateText}',
        ),
        onTap: () {
          context.pushNamed('newsDetail', extra: article);
        },
      ),
    );
  }
}
