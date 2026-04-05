import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';

import '../../../../../config/api_keys.dart';
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
    int maxCount = 10,
  }) async {
    final effectiveKey = apiKey.isNotEmpty ? apiKey : ApiKeys.geminiApiKeyFromEnv;
    if (effectiveKey.isEmpty) {
      throw AppError(
        type: AppErrorType.authentication,
        message: 'Gemini APIキーが空です。設定画面で設定してください。',
      );
    }

    final cleanedKeywords = _cleanupKeywords(keywords);
    if (cleanedKeywords.isEmpty) {
      throw AppError(
        type: AppErrorType.parse,
        message: 'キーワードが未設定です。',
      );
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: effectiveKey,
        tools: const [],
        generationConfig: GenerationConfig(
          temperature: 0.2,
          responseMimeType: 'application/json',
          maxOutputTokens: 2048,
        ),
      );

      final prompt = _buildPrompt(cleanedKeywords, maxCount);
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        throw AppError(
          type: AppErrorType.parse,
          message: 'Geminiからの応答が空です。',
        );
      }

      final decoded = _extractJson(text);
      final records = switch (decoded) {
        Map() when decoded['articles'] is List => decoded['articles'],
        List() => decoded,
        _ => <dynamic>[],
      };

      if (records.isEmpty) {
        return <NewsArticle>[];
      }

      final parsed = <NewsArticle>[];
      for (final record in records) {
        if (record is! Map<String, dynamic>) continue;
        final rawUrl = record['url']?.toString().trim();
        if (rawUrl == null || rawUrl.isEmpty) {
          continue;
        }

        final publishedAt = _parseDate(record['publishedAt']?.toString())
            ?? DateTime.now();

        final keywordsList = _normalizeKeywordString(
          record['keywords']?.toString() ?? '',
        );

        parsed.add(
          NewsArticle(
            id: '$rawUrl|${publishedAt.toIso8601String()}',
            title: record['title']?.toString().trim() ?? 'タイトルなし',
            summary: record['summary']?.toString().trim() ?? '要約なし',
            source: record['source']?.toString().trim() ?? '取得元不明',
            url: rawUrl,
            publishedAt: publishedAt,
            keywords: [...cleanedKeywords, ...keywordsList],
            fetchedAt: DateTime.now(),
          ),
        );
      }

      parsed.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      return parsed;
    } on AppError {
      rethrow;
    } catch (error, stack) {
      final message = error.toString().toLowerCase();
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
あなたはニュース要約アシスタントです。
ユーザーが指定したキーワードに基づいて、最新ニュースを検索してください。

条件:
- date=${date}
- keywords=${keywords.join(', ')}
- 最大件数=${maxCount}

出力は厳密に次のJSONのみ返してください。
{
  "articles": [
    {
      "title": "ニュースタイトル",
      "summary": "要約 (100文字以内)",
      "source": "公開元",
      "url": "記事URL",
      "publishedAt": "ISO 8601形式",
      "keywords": ",で区切り"
    }
  ]
}
''';
  }

  List<String> _cleanupKeywords(List<String> keywords) {
    return keywords
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _normalizeKeywordString(String value) {
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  dynamic _extractJson(String rawText) {
    final start = rawText.indexOf('[');
    final startObj = rawText.indexOf('{');

    if (startObj >= 0 && (start < 0 || startObj < start)) {
      final jsonText = _trimJsonBlock(rawText, startObj, '{', '}');
      if (jsonText != null) {
        return jsonDecode(jsonText);
      }
    }

    if (start >= 0) {
      final jsonText = _trimJsonBlock(rawText, start, '[', ']');
      if (jsonText != null) {
        return jsonDecode(jsonText);
      }
    }

    return jsonDecode(rawText);
  }

  String? _trimJsonBlock(String rawText, int startIndex, String startToken, String endToken) {
    int level = 0;
    for (var i = startIndex; i < rawText.length; i++) {
      final char = rawText[i];
      if (char == startToken) {
        level++;
      } else if (char == endToken) {
        level--;
        if (level == 0) {
          return rawText.substring(startIndex, i + 1);
        }
      }
    }
    return null;
  }
}
