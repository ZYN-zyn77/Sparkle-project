import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/network/api_client.dart';

/// Translation service provider
final translationServiceProvider = Provider<TranslationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TranslationService(apiClient);
});

/// Translation segment data
class TranslationSegmentData {
  final String id;
  final String translation;
  final List<String> notes;

  TranslationSegmentData({
    required this.id,
    required this.translation,
    required this.notes,
  });

  factory TranslationSegmentData.fromJson(Map<String, dynamic> json) {
    return TranslationSegmentData(
      id: json['id'] as String,
      translation: json['translation'] as String,
      notes: (json['notes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// Translation recommendation data
class TranslationRecommendation {
  final bool shouldCreateCard;
  final String? reason;
  final int dailyQuotaRemaining;

  TranslationRecommendation({
    required this.shouldCreateCard,
    this.reason,
    required this.dailyQuotaRemaining,
  });

  factory TranslationRecommendation.fromJson(Map<String, dynamic> json) {
    return TranslationRecommendation(
      shouldCreateCard: json['should_create_card'] as bool? ?? false,
      reason: json['reason'] as String?,
      dailyQuotaRemaining: json['daily_quota_remaining'] as int? ?? 0,
    );
  }
}

/// Asset suggestion data with structured reason
class AssetSuggestion {
  final bool suggestAsset;
  final String? suggestionLogId;
  final String? selectionFp;
  final String? reason; // Legacy field for backward compatibility
  final String? reasonCode; // Structured reason code (e.g., "repeated_lookup")
  final Map<String, dynamic>? reasonParams; // Parameters for reason template

  AssetSuggestion({
    required this.suggestAsset,
    this.suggestionLogId,
    this.selectionFp,
    this.reason,
    this.reasonCode,
    this.reasonParams,
  });

  factory AssetSuggestion.fromJson(Map<String, dynamic> json) {
    return AssetSuggestion(
      suggestAsset: json['suggest_asset'] as bool? ?? false,
      suggestionLogId: json['suggestion_log_id'] as String?,
      selectionFp: json['selection_fp'] as String?,
      reason: json['reason'] as String?,
      reasonCode: json['reason_code'] as String?,
      reasonParams: json['reason_params'] as Map<String, dynamic>?,
    );
  }

  /// Format reason for display using structured templates
  String formatReason() {
    // Use structured reason if available
    if (reasonCode != null && reasonParams != null) {
      return _formatReasonFromTemplate(reasonCode!, reasonParams!);
    }
    // Fall back to legacy reason parsing
    return _formatLegacyReason(reason);
  }

  /// Format reason using template system
  static String _formatReasonFromTemplate(
    String code,
    Map<String, dynamic> params,
  ) {
    switch (code) {
      case 'repeated_lookup':
        final count = params['lookup_count'] ?? 2;
        return '在本次会话中查询了 $count 次';
      case 'from_same_doc':
        final page = params['page']?.toString() ?? '';
        return '来自同一篇文档${page.isNotEmpty ? "第$page页" : ""}';
      case 'dismissed_recently':
        final days = params['days']?.toString() ?? '';
        return '上次忽略是在 $days 天前';
      case 'lookup_count_below_threshold':
        return '查询次数不足，继续学习';
      case 'cooldown_active':
        return '建议冷却中，稍后再试';
      case 'already_exists':
        return '已存在于生词本中';
      default:
        return '建议加入生词本';
    }
  }

  /// Format legacy reason string (backward compatibility)
  static String _formatLegacyReason(String? backendReason) {
    if (backendReason == null) return '建议加入生词本';

    const reasonMap = {
      'repeated_lookup_2_times': '在本次会话中查询了 2 次',
      'repeated_lookup_3_times': '在本次会话中查询了 3 次',
      'lookup_count_below_threshold': '查询次数不足',
      'cooldown_active_until': '冷却中，稍后再试',
      'already_exists': '已存在于生词本',
    };

    for (final key in reasonMap.keys) {
      if (backendReason.contains(key)) {
        return reasonMap[key]!;
      }
    }

    // Fallback: use the original reason or default message
    if (backendReason.length > 50) {
      return '建议加入生词本';
    }
    return backendReason.replaceAll('_', ' ');
  }
}

/// Translation result
class TranslationResult {
  final bool success;
  final String translation;
  final List<TranslationSegmentData> segments;
  final TranslationRecommendation? recommendation;
  final AssetSuggestion? assetSuggestion;
  final Map<String, dynamic> meta;

  TranslationResult({
    required this.success,
    required this.translation,
    required this.segments,
    this.recommendation,
    this.assetSuggestion,
    required this.meta,
  });

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      success: json['success'] as bool,
      translation: json['translation'] as String,
      segments: (json['segments'] as List<dynamic>)
          .map((e) => TranslationSegmentData.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendation: json['recommendation'] != null
          ? TranslationRecommendation.fromJson(
              json['recommendation'] as Map<String, dynamic>)
          : null,
      assetSuggestion: json['asset_suggestion'] != null
          ? AssetSuggestion.fromJson(
              json['asset_suggestion'] as Map<String, dynamic>)
          : null,
      meta: json['meta'] as Map<String, dynamic>,
    );
  }

  /// Check if result was from cache
  bool get isCacheHit => meta['cache_hit'] == true;


  /// Get provider name
  String get provider => meta['provider'] as String? ?? 'unknown';

  /// Get latency in milliseconds
  int get latencyMs => meta['latency_ms'] as int? ?? 0;

  /// Get source language
  String get sourceLang => meta['source_lang'] as String? ?? 'en';

  /// Get target language
  String get targetLang => meta['target_lang'] as String? ?? 'zh-CN';
}

/// Translation service for API calls
class TranslationService {
  final ApiClient _apiClient;

  TranslationService(this._apiClient);

  /// Translate text from one language to another
  ///
  /// [text] - Text to translate
  /// [sourceLang] - Source language code (default: 'en')
  /// [targetLang] - Target language code (default: 'zh-CN')
  /// [domain] - Domain for terminology: 'cs', 'math', 'business', 'general'
  /// [style] - Translation style: 'concise', 'literal', 'natural'
  /// [glossaryId] - Optional glossary ID for terminology consistency
  /// [fingerprint] - Optional context fingerprint for signal tracking
  /// [contextBefore] - Text preceding selection
  /// [contextAfter] - Text following selection
  /// [pageNo] - Page number in document
  /// [sourceFileId] - Document identifier
  Future<TranslationResult> translate({
    required String text,
    String sourceLang = 'en',
    String targetLang = 'zh-CN',
    String domain = 'general',
    String style = 'natural',
    String? glossaryId,
    String? fingerprint,
    String? contextBefore,
    String? contextAfter,
    int? pageNo,
    String? sourceFileId,
  }) async {
    final response = await _apiClient.post(
      '/translation/translate',
      data: {
        'text': text,
        'source_lang': sourceLang,
        'target_lang': targetLang,
        'domain': domain,
        'style': style,
        if (glossaryId != null) 'glossary_id': glossaryId,
        // v2 Signals
        if (fingerprint != null) 'fingerprint': fingerprint,
        if (contextBefore != null) 'context_before': contextBefore,
        if (contextAfter != null) 'context_after': contextAfter,
        if (pageNo != null) 'page_no': pageNo,
        if (sourceFileId != null) 'source_file_id': sourceFileId,
      },
    );

    return TranslationResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get available glossaries
  Future<List<Map<String, dynamic>>> getGlossaries() async {
    final response = await _apiClient.get('/translation/glossaries');
    final data = response.data as Map<String, dynamic>;
    return (data['glossaries'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }
}
