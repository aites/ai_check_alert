import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _prefsCategory = '$_prefsPrefix.category';
  static const _prefsSortMode = '$_prefsPrefix.sortMode';
  static const _allCategory = 'すべて';
  String _selectedCategory = _allCategory;
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

                final categories = <String>{
                  _allCategory,
                  ...items.map((e) => e.category),
                }.toList(growable: false);
                final activeCategory = categories.contains(_selectedCategory)
                    ? _selectedCategory
                    : _allCategory;
                final visible = _filterAndSortNews(items, activeCategory);

                final grouped = _NewsDateGroup.from(visible);

                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(newsActionControllerProvider.notifier)
                      .manualFetch(),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _NewsListControls(
                        categories: categories,
                        selectedCategory: activeCategory,
                        sortMode: _sortMode,
                        onCategoryChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                          _savePreferences();
                        },
                        onSortModeChanged: (value) {
                          setState(() {
                            _sortMode = value;
                          });
                          _savePreferences();
                        },
                      ),
                      const SizedBox(height: 12),
                      if (grouped.isEmpty)
                        _NoResultsCard(
                          onReset: () {
                            setState(() {
                              _selectedCategory = _allCategory;
                              _sortMode = _NewsSortMode.newest;
                            });
                            _savePreferences();
                          },
                        )
                      else
                        ...List.generate(grouped.length, (index) {
                          final section = grouped[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == grouped.length - 1 ? 0 : 12,
                            ),
                            child: _NewsDateSection(group: section),
                          );
                        }),
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
      return error.userMessage;
    }
    if (error is Exception) {
      return error.toString();
    }
    return '通信エラーが発生しました。';
  }

  List<NewsArticle> _filterAndSortNews(
    List<NewsArticle> source,
    String selectedCategory,
  ) {
    final filtered = source
        .where((article) {
          if (selectedCategory == _allCategory) {
            return true;
          }
          return article.category == selectedCategory;
        })
        .toList(growable: false);

    final sorted = [...filtered];
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
    final restoredCategory = prefs.getString(_prefsCategory) ?? _allCategory;
    final restoredSort = prefs.getString(_prefsSortMode);

    final sortMode = _NewsSortMode.values.firstWhere(
      (mode) => mode.name == restoredSort,
      orElse: () => _NewsSortMode.newest,
    );

    if (!mounted) return;
    setState(() {
      _selectedCategory = restoredCategory;
      _sortMode = sortMode;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCategory, _selectedCategory);
    await prefs.setString(_prefsSortMode, _sortMode.name);
  }
}

enum _NewsSortMode { newest, importance }

/// Control area for category filtering and list sorting.
class _NewsListControls extends StatelessWidget {
  const _NewsListControls({
    required this.categories,
    required this.selectedCategory,
    required this.sortMode,
    required this.onCategoryChanged,
    required this.onSortModeChanged,
  });

  final List<String> categories;
  final String selectedCategory;
  final _NewsSortMode sortMode;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<_NewsSortMode> onSortModeChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories
                    .map((category) {
                      final selected = category == selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: selected,
                          onSelected: (_) => onCategoryChanged(category),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
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

/// Empty-state card for filtered result sets.
class _NoResultsCard extends StatelessWidget {
  const _NoResultsCard({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('条件に一致する記事がありません。'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onReset, child: const Text('絞り込みを解除')),
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
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(group.headerLabel, style: textTheme.titleMedium),
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            context.pushNamed('newsDetail', extra: article);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(
                      label: Text(article.category),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text('重要度 ${article.importance}'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  article.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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
