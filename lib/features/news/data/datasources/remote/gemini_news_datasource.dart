import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../../../config/api_keys.dart';
import '../../../../../config/news_prompt_defaults.dart';
import '../../../../../config/gemini_models.dart';
import '../../../../errors/app_error.dart';
import '../../../domain/entities/news_article.dart';

abstract class GeminiNewsDataSource {
  Future<List<NewsArticle>> fetchLatestNews({
    required String apiKey,
    required List<String> keywords,
    int maxCount,
  });
}

class GeminiNewsDataSourceImpl implements GeminiNewsDataSource {
  @override
  Future<List<NewsArticle>> fetchLatestNews({
    required String apiKey,
    required List<String> keywords,
    int maxCount = 5,
  }) async {
    final effectiveKey = apiKey.isNotEmpty
        ? apiKey
        : ApiKeys.geminiApiKeyFromEnv;
    if (effectiveKey.isEmpty) {
      throw AppError(
        type: AppErrorType.authentication,
        message: 'Gemini APIキーが空です。設定画面で設定してください。',
      );
    }

    final cleanedKeywords = _cleanupKeywords(keywords);
    if (cleanedKeywords.isEmpty) {
      throw AppError(type: AppErrorType.parse, message: 'キーワードが未設定です。');
    }

    try {
      final prompt = _buildPrompt(cleanedKeywords, maxCount);
      final text = await _generateWithModelFallback(
        apiKey: effectiveKey,
        prompt: prompt,
      );
      if (text.isEmpty) {
        throw AppError(type: AppErrorType.parse, message: 'Geminiからの応答が空です。');
      }

      final normalizedJsonText = _extractJsonPayload(text);

      final decoded = jsonDecode(normalizedJsonText);
      if (decoded is! Map<String, dynamic>) {
        throw AppError(
          type: AppErrorType.parse,
          message: 'JSON形式が不正です。',
          details: 'Top level must be an object',
        );
      }

      final date = _validateDate(decoded['date']?.toString());
      final records = decoded['articles'];
      if (records is! List) {
        throw AppError(
          type: AppErrorType.parse,
          message: 'JSON形式が不正です。',
          details: 'articles must be a list',
        );
      }

      final parsed = <NewsArticle>[];
      for (final record in records) {
        if (record is! Map<String, dynamic>) continue;
        final rawUrl = record['source_url']?.toString().trim();
        if (rawUrl == null || rawUrl.isEmpty) {
          continue;
        }

        final articleId = record['id']?.toString().trim();
        final title = record['title']?.toString().trim();
        final summary = record['summary']?.toString().trim();
        final content = record['content']?.toString().trim();
        final category = record['category']?.toString().trim();
        final importance = int.tryParse(record['importance']?.toString() ?? '');

        if (articleId == null ||
            articleId.isEmpty ||
            title == null ||
            title.isEmpty ||
            summary == null ||
            summary.isEmpty ||
            content == null ||
            content.isEmpty ||
            category == null ||
            category.isEmpty ||
            importance == null) {
          continue;
        }

        final boundedImportance = importance.clamp(1, 5);

        parsed.add(
          NewsArticle(
            id: articleId,
            title: title,
            summary: summary,
            content: content,
            category: category,
            sourceUrl: rawUrl,
            importance: boundedImportance,
            date: date,
            fetchedAt: DateTime.now(),
          ),
        );
      }

      parsed.sort((a, b) => b.importance.compareTo(a.importance));
      return parsed;
    } on AppError {
      rethrow;
    } catch (error, stack) {
      final message = error.toString().toLowerCase();
      if (message.contains('failed host lookup') ||
          message.contains('socketexception') ||
          message.contains('timed out') ||
          message.contains('timeoutexception')) {
        throw AppError(
          type: AppErrorType.network,
          message:
              'ネットワーク到達性またはGemini応答遅延の可能性があります。回線・VPN・DNS設定を確認して再試行してください。',
          details: error.toString(),
        );
      }
      if (message.contains('failed_precondition') ||
          message.contains('free tier is not available') ||
          message.contains('billing')) {
        throw AppError(
          type: AppErrorType.unknown,
          message: 'Gemini APIの前提条件エラーです。課金設定または利用リージョンを確認してください。',
          details: error.toString(),
        );
      }
      if (message.contains('api key not valid') ||
          message.contains('permission denied') ||
          message.contains('reported as leaked') ||
          message.contains('403')) {
        throw AppError(
          type: AppErrorType.authentication,
          message: 'Gemini APIキーが無効・権限不足・または漏洩により無効化された可能性があります。',
          details: error.toString(),
        );
      }
      if (message.contains('429') || message.contains('quota')) {
        throw AppError(
          type: AppErrorType.quota,
          message: 'Gemini APIの利用上限に達した可能性があります。',
          details: error.toString(),
        );
      }
      throw AppError(
        type: AppErrorType.network,
        message: 'Gemini API呼び出しで未分類エラーが発生しました。',
        details: kDebugMode ? '$error\n$stack' : null,
      );
    }
  }

  String _buildPrompt(List<String> keywords, int maxCount) {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final defaultTopics = kDefaultNewsKeywords.join(', ');
    return '''
あなたはAI技術ニュースの編集者です。
対象トピックは「$defaultTopics, ${keywords.join(', ')}」。
date=$date の時点で、過去24時間の信頼できる最新情報を最大$maxCount件、Google検索ベースで選定してください。
一次ソース（GitHub公式、公式ドキュメント、Arxiv、公式ブログ）を優先し、検証不能な情報は除外してください。
信頼できる情報が無ければ articles は空配列で返してください。
出力はJSONのみ。説明文やMarkdownは禁止。
title/summary/content/category は自然な日本語。
titleは日本語化するが、企業名・製品名・人名・OSS名・API名など固有名詞は原文維持。
summary または content に、src/agents または src/tools への設計影響を必ず含めること。
importance は 1-5 の整数。

返却JSONスキーマ:
{"date":"YYYY-MM-DD","articles":[{"id":"string","title":"string","summary":"string","content":"string","category":"string","source_url":"string","importance":1}]}
''';
  }

  Future<String> _generateWithModelFallback({
    required String apiKey,
    required String prompt,
  }) async {
    Object? lastError;

    for (final modelName in geminiModelCandidates) {
      try {
        return await _generateViaRest(
          apiKey: apiKey,
          modelName: modelName,
          prompt: prompt,
        );
      } catch (error) {
        lastError = error;
        if (_isModelNotFound(error) || _isQuotaError(error)) {
          continue;
        }
        rethrow;
      }
    }

    throw AppError(
      type: AppErrorType.parse,
      message: '利用可能なGeminiモデルが見つかりませんでした。',
      details:
          'Tried: ${geminiModelCandidates.join(', ')}; lastError: $lastError',
    );
  }

  Future<String> _generateViaRest({
    required String apiKey,
    required String modelName,
    required String prompt,
  }) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$modelName:generateContent',
      <String, String>{'key': apiKey},
    );

    http.Response response;
    try {
      response = await _postGenerateContent(
        uri: uri,
        prompt: prompt,
        useJsonMimeType: true,
        useSearchTool: true,
      );
    } on TimeoutException {
      // Fallback path: retry once without search tool to reduce latency spikes.
      response = await _postGenerateContent(
        uri: uri,
        prompt: prompt,
        useJsonMimeType: false,
        useSearchTool: false,
      );
    }

    if (_isToolJsonMimeUnsupported(response)) {
      response = await _postGenerateContent(
        uri: uri,
        prompt: prompt,
        useJsonMimeType: false,
        useSearchTool: true,
      );
    }

    if (response.statusCode >= 400) {
      final body = response.body;
      final lower = body.toLowerCase();
      final summary = _summarizeErrorBody(body);
      final details = 'HTTP ${response.statusCode}: $summary';
      if (response.statusCode == 400 &&
          (lower.contains('failed_precondition') ||
              lower.contains('free tier is not available') ||
              lower.contains('billing'))) {
        throw AppError(
          type: AppErrorType.unknown,
          message: 'Gemini APIの前提条件エラーです。課金設定または利用リージョンを確認してください。',
          details: details,
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw AppError(
          type: AppErrorType.authentication,
          message: 'Gemini APIキーが無効か権限不足の可能性があります。',
          details: details,
        );
      }
      if (lower.contains('reported as leaked')) {
        throw AppError(
          type: AppErrorType.authentication,
          message: 'このAPIキーは漏洩扱いでブロックされた可能性があります。AI Studioで新しいキーを作成してください。',
          details: details,
        );
      }
      if (response.statusCode == 429 || lower.contains('quota')) {
        throw AppError(
          type: AppErrorType.quota,
          message: 'Gemini APIの利用上限に達した可能性があります。',
          details: details,
        );
      }
      if (_isModelNotFound(body)) {
        throw StateError(body);
      }
      if (response.statusCode == 500 ||
          response.statusCode == 503 ||
          response.statusCode == 504) {
        throw AppError(
          type: AppErrorType.network,
          message: 'Gemini APIサーバー側の一時エラーの可能性があります。時間をおいて再試行してください。',
          details: details,
        );
      }
      throw AppError(
        type: AppErrorType.network,
        message: 'Gemini API呼び出しに失敗しました。HTTPステータスを確認してください。',
        details: details,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw AppError(type: AppErrorType.parse, message: 'Gemini応答の解析に失敗しました。');
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw AppError(type: AppErrorType.parse, message: 'Gemini応答に候補がありません。');
    }

    final first = candidates.first;
    if (first is! Map<String, dynamic>) {
      throw AppError(type: AppErrorType.parse, message: '候補形式が不正です。');
    }
    final content = first['content'];
    if (content is! Map<String, dynamic>) {
      throw AppError(type: AppErrorType.parse, message: 'content形式が不正です。');
    }
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw AppError(type: AppErrorType.parse, message: 'parts形式が不正です。');
    }
    final part0 = parts.first;
    if (part0 is! Map<String, dynamic>) {
      throw AppError(type: AppErrorType.parse, message: 'part形式が不正です。');
    }
    final text = part0['text']?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw AppError(type: AppErrorType.parse, message: '応答テキストが空です。');
    }
    return text;
  }

  /// Sends generateContent request with optional JSON response MIME type.
  Future<http.Response> _postGenerateContent({
    required Uri uri,
    required String prompt,
    required bool useJsonMimeType,
    required bool useSearchTool,
  }) async {
    final payload = <String, dynamic>{
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{'text': prompt},
          ],
        },
      ],
      if (useSearchTool)
        'tools': <Map<String, dynamic>>[
          <String, dynamic>{'google_search': <String, dynamic>{}},
        ],
    };

    if (useJsonMimeType) {
      payload['generationConfig'] = <String, dynamic>{
        'responseMimeType': 'application/json',
      };
    }

    final timeouts = <Duration>[
      const Duration(seconds: 45),
      const Duration(seconds: 75),
    ];

    TimeoutException? lastTimeout;
    for (var i = 0; i < timeouts.length; i++) {
      try {
        return await http
            .post(
              uri,
              headers: const <String, String>{
                'Content-Type': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(timeouts[i]);
      } on TimeoutException catch (error) {
        lastTimeout = error;
        if (i == timeouts.length - 1) {
          rethrow;
        }
      }
    }

    throw lastTimeout ??
        TimeoutException('Gemini request timed out without response.');
  }

  /// Returns true when Gemini rejects tool use with JSON MIME type.
  bool _isToolJsonMimeUnsupported(http.Response response) {
    if (response.statusCode != 400) {
      return false;
    }
    final lower = response.body.toLowerCase();
    return lower.contains('invalid_argument') &&
        lower.contains('tool use') &&
        lower.contains('response mime type') &&
        lower.contains('application/json') &&
        lower.contains('unsupported');
  }

  bool _isModelNotFound(Object error) {
    final lower = error.toString().toLowerCase();
    final notFound =
        lower.contains('not found for api version') && lower.contains('model');
    final notSupported =
        lower.contains('not supported for generatecontent') ||
        (lower.contains('model') && lower.contains('not supported'));
    return notFound || notSupported;
  }

  bool _isQuotaError(Object error) {
    if (error is AppError && error.type == AppErrorType.quota) {
      return true;
    }

    final lower = error.toString().toLowerCase();
    return lower.contains('429') ||
        lower.contains('quota') ||
        lower.contains('resource_exhausted');
  }

  /// Extracts JSON object text from raw model output.
  String _extractJsonPayload(String rawText) {
    final trimmed = rawText.trim();

    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final fencedMatch = fencePattern.firstMatch(trimmed);
    if (fencedMatch != null) {
      final candidate = fencedMatch.group(1)?.trim() ?? '';
      if (candidate.startsWith('{') && candidate.endsWith('}')) {
        return candidate;
      }
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return trimmed.substring(start, end + 1);
    }

    return trimmed;
  }

  /// Extracts a short error summary from Gemini HTTP error response body.
  String _summarizeErrorBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final status = error['status']?.toString().trim();
          final message = error['message']?.toString().trim();
          final parts = <String>[];
          if (status != null && status.isNotEmpty) {
            parts.add(status);
          }
          if (message != null && message.isNotEmpty) {
            parts.add(message);
          }
          if (parts.isNotEmpty) {
            return parts.join(' - ');
          }
        }
      }
    } catch (_) {
      // Falls back to raw body snippet when JSON decoding fails.
    }

    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return 'No response body';
    }
    const maxLength = 220;
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength)}...';
  }

  List<String> _cleanupKeywords(List<String> keywords) {
    return keywords
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  String _validateDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
    return DateFormat('yyyy-MM-dd').format(parsed);
  }
}
