import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/network/api_client.dart';
import 'package:sparkle/core/services/demo_data_service.dart';

/// Interface for error repository
abstract class ErrorRepositoryInterface {
  Future<Map<String, dynamic>> createError({
    required int subjectId,
    required String topic,
    required String errorType,
    required String description,
    String? aiAnalysis,
    List<String>? imageUrls,
  });

  Future<List<Map<String, dynamic>>> getSubjects();
}

final errorRepositoryProvider = Provider<ErrorRepositoryInterface>(
  (ref) {
    if (DemoDataService.isDemoMode) {
      return MockErrorRepository();
    }
    return ErrorRepository(ref.watch(apiClientProvider));
  },
);

/// 错题记录仓库
class ErrorRepository implements ErrorRepositoryInterface {
  ErrorRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> createError({
    required int subjectId,
    required String topic,
    required String errorType,
    required String description,
    String? aiAnalysis,
    List<String>? imageUrls,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/errors',
      data: {
        'subject_id': subjectId,
        'topic': topic,
        'error_type': errorType,
        'description': description,
        if (aiAnalysis != null) 'ai_analysis': aiAnalysis,
        if (imageUrls != null && imageUrls.isNotEmpty) 'image_urls': imageUrls,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  @override
  Future<List<Map<String, dynamic>>> getSubjects() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final response = await _apiClient.get<dynamic>('/subjects');
    final data = response.data;
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    } else if (data is Map && data.containsKey('data')) {
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }
}

class MockErrorRepository implements ErrorRepositoryInterface {
  @override
  Future<Map<String, dynamic>> createError({
    required int subjectId,
    required String topic,
    required String errorType,
    required String description,
    String? aiAnalysis,
    List<String>? imageUrls,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return {
      'id': 'error_${DateTime.now().millisecondsSinceEpoch}',
      'subject_id': subjectId,
      'topic': topic,
      'error_type': errorType,
      'description': description,
      'ai_analysis': aiAnalysis,
      'image_urls': imageUrls,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getSubjects() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return [
      {'id': 1, 'name': '数据结构', 'code': 'DS'},
      {'id': 2, 'name': '离散数学', 'code': 'DM'},
      {'id': 3, 'name': '计算机系统', 'code': 'CS'},
      {'id': 4, 'name': '数字电路', 'code': 'DC'},
    ];
  }
}
