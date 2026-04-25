import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../errors/app_error.dart';
import '../../domain/entities/news_article.dart';
import '../controllers/news_controller.dart';
import '../providers/news_providers.dart';

/// Home page that displays persisted news grouped by date.
class NewsHomePage extends ConsumerStatefulWidget {
  const NewsHomePage({super.key});

  @override
  ConsumerState<NewsHomePage> createState() => _NewsHomePageState();
}

class _NewsHomePageState extends ConsumerState<NewsHomePage> {
  static const _prefsPrefix = 'news_home';
  static const _prefsSortMode = '$_prefsPrefix.sortMode';
  _NewsSortMode _sortMode = _NewsSortMode.newest;

  @override
  void initState() {
    super.initState();
    _restorePreferences();
  }

  @override
  Widget build(BuildContext context) {
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
            _NewsErrorBanner(message: _errorMessage(actionState.error)),
          Expanded(
            child: newsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('まだ保存済みニュースはありません。'));
                }

                final visible = _sortNews(items);

                final grouped = _NewsDateGroup.from(visible);

                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(newsActionControllerProvider.notifier)
                      .manualFetch(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: _NewsListControls(
                            totalCount: visible.length,
                            sortMode: _sortMode,
                            onSortModeChanged: (value) {
                              setState(() {
                                _sortMode = value;
                              });
                              _savePreferences();
                            },
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.builder(
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final section = grouped[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index == grouped.length - 1 ? 24 : 14,
                              ),
                              child: _NewsDateSection(group: section),
                            );
                          },
                        ),
                      ),
                    ],
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
      final details = error.details?.trim();
      if (details == null || details.isEmpty) {
        return error.message;
      }
      final compact = details.replaceAll(RegExp(r'\s+'), ' ').trim();
      const maxLength = 180;
      final snippet = compact.length <= maxLength
          ? compact
          : '${compact.substring(0, maxLength)}...';
      return '${error.message} ($snippet)';
    }
    if (error is Exception) {
      return error.toString();
    }
    return '通信エラーが発生しました。';
  }

  List<NewsArticle> _sortNews(List<NewsArticle> source) {
    final sorted = [...source];
    sorted.sort((a, b) {
      switch (_sortMode) {
        case _NewsSortMode.newest:
          return _dateValueOf(b).compareTo(_dateValueOf(a));
        case _NewsSortMode.importance:
          return b.importance.compareTo(a.importance);
      }
    });
    return sorted;
  }

  DateTime _dateValueOf(NewsArticle article) {
    return DateTime.tryParse(article.date) ?? article.fetchedAt;
  }

  Future<void> _restorePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final restoredSort = prefs.getString(_prefsSortMode);

    final sortMode = _NewsSortMode.values.firstWhere(
      (mode) => mode.name == restoredSort,
      orElse: () => _NewsSortMode.newest,
    );

    if (!mounted) return;
    setState(() {
      _sortMode = sortMode;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsSortMode, _sortMode.name);
  }
}

enum _NewsSortMode { newest, importance }

/// Control area for category filtering and list sorting.
class _NewsListControls extends StatelessWidget {
  const _NewsListControls({
    required this.totalCount,
    required this.sortMode,
    required this.onSortModeChanged,
  });

  final int totalCount;
  final _NewsSortMode sortMode;
  final ValueChanged<_NewsSortMode> onSortModeChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.newspaper_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('表示中 $totalCount 件'),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<_NewsSortMode>(
              segments: const [
                ButtonSegment<_NewsSortMode>(
                  value: _NewsSortMode.newest,
                  icon: Icon(Icons.schedule),
                  label: Text('新着順'),
                ),
                ButtonSegment<_NewsSortMode>(
                  value: _NewsSortMode.importance,
                  icon: Icon(Icons.local_fire_department_outlined),
                  label: Text('重要度順'),
                ),
              ],
              selected: {sortMode},
              onSelectionChanged: (value) {
                onSortModeChanged(value.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A dismissible top-level error banner for fetch actions.
class _NewsErrorBanner extends StatelessWidget {
  const _NewsErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.errorContainer,
      padding: const EdgeInsets.all(12),
      child: Text(
        message,
        style: TextStyle(color: colorScheme.onErrorContainer),
      ),
    );
  }
}

/// Date section wrapper for grouped news cards.
class _NewsDateSection extends StatelessWidget {
  const _NewsDateSection({required this.group});

  final _NewsDateGroup group;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  group.headerLabel,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${group.articles.length}件',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...group.articles.map(_NewsCard.new),
      ],
    );
  }
}

/// Individual news card used in date-grouped sections.
class _NewsCard extends StatelessWidget {
  const _NewsCard(this.article, {super.key});

  final NewsArticle article;

  /// Selects a badge color from article importance.
  Color _importanceColor(ColorScheme colorScheme) {
    if (article.importance >= 5) {
      return colorScheme.errorContainer;
    }
    if (article.importance >= 3) {
      return colorScheme.tertiaryContainer;
    }
    return colorScheme.primaryContainer;
  }

  /// Picks readable badge foreground color paired with [_importanceColor].
  Color _importanceOnColor(ColorScheme colorScheme) {
    if (article.importance >= 5) {
      return colorScheme.onErrorContainer;
    }
    if (article.importance >= 3) {
      return colorScheme.onTertiaryContainer;
    }
    return colorScheme.onPrimaryContainer;
  }

  /// Returns a compact source label from URL host.
  String _sourceLabel() {
    final uri = Uri.tryParse(article.sourceUrl);
    final host = uri?.host.trim();
    if (host == null || host.isEmpty) {
      return '参考リンク';
    }
    return host.replaceFirst('www.', '');
  }

  /// Opens source URL with the default browser.
  Future<void> _openSource(BuildContext context) async {
    final uri = Uri.tryParse(article.sourceUrl);
    if (uri == null) {
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('参考リンクを開けませんでした。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final importanceColor = _importanceColor(colorScheme);
    final onImportanceColor = _importanceOnColor(colorScheme);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.pushNamed('newsDetail', extra: article);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: importanceColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '重要度 ${article.importance}',
                        style: textTheme.labelMedium?.copyWith(
                          color: onImportanceColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  article.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.language,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _sourceLabel(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: article.sourceUrl.isEmpty
                          ? null
                          : () => _openSource(context),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('参考リンク'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Immutable grouped view model for date-based news rendering.
class _NewsDateGroup {
  const _NewsDateGroup({required this.dateLabel, required this.articles});

  final String dateLabel;
  final List<NewsArticle> articles;

  /// Human-readable date heading used in the Home list.
  String get headerLabel {
    final parsed = DateTime.tryParse(dateLabel);
    if (parsed == null) {
      return dateLabel;
    }

    final today = DateTime.now();
    final current = DateTime(today.year, today.month, today.day);
    final target = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = current.difference(target).inDays;

    if (diff == 0) {
      return '今日';
    }
    if (diff == 1) {
      return '昨日';
    }
    return dateLabel;
  }

  /// Builds grouped date sections while preserving insertion order.
  static List<_NewsDateGroup> from(List<NewsArticle> source) {
    final grouped = <String, List<NewsArticle>>{};
    for (final article in source) {
      grouped.putIfAbsent(article.displayDateText, () => <NewsArticle>[]);
      grouped[article.displayDateText]!.add(article);
    }

    return grouped.entries
        .map(
          (entry) => _NewsDateGroup(
            dateLabel: entry.key,
            articles: List<NewsArticle>.unmodifiable(entry.value),
          ),
        )
        .toList(growable: false);
  }
}
