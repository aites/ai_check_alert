import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../../../config/api_keys.dart';
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

      final decoded = jsonDecode(text);
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
      if (message.contains('api key not valid') ||
          message.contains('permission denied') ||
          message.contains('403')) {
        throw AppError(
          type: AppErrorType.authentication,
          message: 'Gemini APIキーが無効か権限不足の可能性があります。',
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
        message: 'Gemini APIの取得中にエラーが発生しました。',
        details: kDebugMode ? '$error\n$stack' : null,
      );
    }
  }

  String _buildPrompt(List<String> keywords, int maxCount) {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return '''
Role: プロフェッショナル・ニュースエディター
Task: ユーザー指定トピックについて、Google検索で24時間以内の最新ニュースを最大$maxCount件収集し要約する。
Rules:
1. 事実に基づかない生成をしない。
2. 信頼できるソースがない場合は articles を空配列にする。
3. 出力はJSONのみ。

Input:
- date=$date
- topic=${keywords.join(', ')}

JSON contract:
{
  "date": "YYYY-MM-DD",
  "articles": [
    {
      "id": "string",
      "title": "string",
      "summary": "string",
      "content": "string",
      "category": "string",
      "source_url": "string",
      "importance": 1
    }
  ]
}
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
        if (_isModelNotFound(error)) {
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

    final payload = <String, dynamic>{
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{'text': prompt},
          ],
        },
      ],
      'tools': <Map<String, dynamic>>[
        <String, dynamic>{'google_search': <String, dynamic>{}},
      ],
      'generationConfig': <String, dynamic>{
        'responseMimeType': 'application/json',
      },
    };

    final response = await http
        .post(
          uri,
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode >= 400) {
      final body = response.body;
      final lower = body.toLowerCase();
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw AppError(
          type: AppErrorType.authentication,
          message: 'Gemini APIキーが無効か権限不足の可能性があります。',
          details: body,
        );
      }
      if (response.statusCode == 429 || lower.contains('quota')) {
        throw AppError(
          type: AppErrorType.quota,
          message: 'Gemini APIの利用上限に達した可能性があります。',
          details: body,
        );
      }
      if (_isModelNotFound(body)) {
        throw StateError(body);
      }
      throw AppError(
        type: AppErrorType.network,
        message: 'Gemini APIの取得中にエラーが発生しました。',
        details: body,
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

  bool _isModelNotFound(Object error) {
    final lower = error.toString().toLowerCase();
    final notFound =
        lower.contains('not found for api version') && lower.contains('model');
    final notSupported =
        lower.contains('not supported for generatecontent') ||
        (lower.contains('model') && lower.contains('not supported'));
    return notFound || notSupported;
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
