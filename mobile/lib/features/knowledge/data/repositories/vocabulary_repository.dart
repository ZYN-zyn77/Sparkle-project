import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/network/api_client.dart';
import 'package:sparkle/core/services/demo_data_service.dart';

/// Interface for vocabulary repository
abstract class VocabularyRepositoryInterface {
  Future<Map<String, dynamic>> lookup(String word);
  Future<void> addToWordbook(Map<String, dynamic> data);
  Future<List<dynamic>> getReviewList();
  Future<void> recordReview(String wordId, bool success);
  Future<List<String>> getAssociations(String word);
  Future<String> generateSentence(String word, {String? context});
}

final vocabularyRepositoryProvider = Provider<VocabularyRepositoryInterface>(
  (ref) {
    if (DemoDataService.isDemoMode) {
      return MockVocabularyRepository();
    }
    return VocabularyRepository(ref.watch(apiClientProvider));
  },
);

class VocabularyRepository implements VocabularyRepositoryInterface {
  VocabularyRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> lookup(String word) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final response = await _apiClient.get<dynamic>(
      '/vocabulary/lookup',
      queryParameters: {'word': word},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> addToWordbook(Map<String, dynamic> data) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _apiClient.post<dynamic>('/vocabulary/wordbook', data: data);
  }

  @override
  Future<List<dynamic>> getReviewList() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final response =
        await _apiClient.get<dynamic>('/vocabulary/wordbook/review');
    return response.data as List<dynamic>;
  }

  @override
  Future<void> recordReview(String wordId, bool success) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _apiClient.post<dynamic>(
      '/vocabulary/wordbook/review',
      data: {
        'word_id': wordId,
        'success': success,
      },
    );
  }

  @override
  Future<List<String>> getAssociations(String word) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final response = await _apiClient.get<dynamic>(
      '/vocabulary/llm/associate',
      queryParameters: {'word': word},
    );
    final data = response.data as Map<String, dynamic>;
    final associations = data['associations'] as List<dynamic>?;
    return List<String>.from(associations ?? const []);
  }

  @override
  Future<String> generateSentence(String word, {String? context}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final response = await _apiClient.get<dynamic>(
      '/vocabulary/llm/sentence',
      queryParameters: {
        'word': word,
        if (context != null) 'context': context,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return data['sentence'] as String;
  }
}

class MockVocabularyRepository implements VocabularyRepositoryInterface {
  @override
  Future<Map<String, dynamic>> lookup(String word) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final data = DemoDataService().demoVocabularyLookup;
    data['word'] = word;
    return data;
  }

  @override
  Future<void> addToWordbook(Map<String, dynamic> data) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // In demo mode, just return success
  }

  @override
  Future<List<dynamic>> getReviewList() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return DemoDataService().demoReviewList;
  }

  @override
  Future<void> recordReview(String wordId, bool success) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // In demo mode, just return success
  }

  @override
  Future<List<String>> getAssociations(String word) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final data = DemoDataService().demoAssociations;
    final associations = data['associations'] as List<dynamic>?;
    return associations
            ?.map((e) => (e as Map<String, dynamic>)['word'] as String)
            .toList() ??
        [];
  }

  @override
  Future<String> generateSentence(String word, {String? context}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return DemoDataService().demoGeneratedSentence;
  }
}
