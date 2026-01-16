import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/network/api_client.dart';
import 'package:sparkle/core/network/api_endpoints.dart';
import 'package:sparkle/core/services/demo_data_service.dart';
import 'package:sparkle/features/reviews/data/models/nightly_review_payload.dart';

abstract class INightlyReviewRepository {
  Future<NightlyReviewPayload?> getLatest();
  Future<NightlyReviewPayload> markReviewed(String reviewId);
}

final nightlyReviewRepositoryProvider =
    Provider<INightlyReviewRepository>((ref) {
  if (DemoDataService.isDemoMode) {
    return MockNightlyReviewRepository();
  }
  return NightlyReviewRepository(ref.watch(apiClientProvider));
});

class NightlyReviewRepository implements INightlyReviewRepository {
  NightlyReviewRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<NightlyReviewPayload?> getLatest() async {
    try {
      final response =
          await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.nightlyReviewLatest);
      final data = response.data;
      if (data == null) {
        return null;
      }
      return NightlyReviewPayload.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<NightlyReviewPayload> markReviewed(String reviewId) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.nightlyReviewFeedback(reviewId),
      data: {'action': 'reviewed', 'source': 'mobile'},
    );
    return NightlyReviewPayload.fromJson(
        response.data ?? <String, dynamic>{},);
  }
}

class MockNightlyReviewRepository implements INightlyReviewRepository {
  final DemoDataService _demoData = DemoDataService();

  @override
  Future<NightlyReviewPayload?> getLatest() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final demoData = _demoData.demoNightlyReview;
    return NightlyReviewPayload.fromJson(demoData);
  }

  @override
  Future<NightlyReviewPayload> markReviewed(String reviewId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final demoData = _demoData.demoNightlyReview;
    return NightlyReviewPayload.fromJson(demoData);
  }
}
