// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$newsSchedulerSettingsHash() =>
    r'fbb1782aabd808e712323647ba792e1cb8050348';

/// See also [newsSchedulerSettings].
@ProviderFor(newsSchedulerSettings)
final newsSchedulerSettingsProvider =
    AutoDisposeFutureProvider<NewsSchedulerInput>.internal(
  newsSchedulerSettings,
  name: r'newsSchedulerSettingsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$newsSchedulerSettingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef NewsSchedulerSettingsRef
    = AutoDisposeFutureProviderRef<NewsSchedulerInput>;
String _$newsListHash() => r'92a408615871f7ad5befdf9b393330477a77fb12';

/// See also [newsList].
@ProviderFor(newsList)
final newsListProvider = AutoDisposeStreamProvider<List<NewsArticle>>.internal(
  newsList,
  name: r'newsListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$newsListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef NewsListRef = AutoDisposeStreamProviderRef<List<NewsArticle>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
