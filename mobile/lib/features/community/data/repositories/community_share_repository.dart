import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/network/api_client.dart';
import 'package:sparkle/core/network/api_endpoints.dart';
import 'package:sparkle/core/services/demo_data_service.dart';

/// Interface for community share repository
abstract class CommunityShareRepositoryInterface {
  Future<void> shareResource({
    required String resourceType,
    required String resourceId,
    String? targetGroupId,
    String? targetUserId,
    String permission = 'view',
    String? comment,
  });
}

final communityShareRepositoryProvider = Provider<CommunityShareRepositoryInterface>(
  (ref) {
    if (DemoDataService.isDemoMode) {
      return MockCommunityShareRepository();
    }
    final apiClient = ref.watch(apiClientProvider);
    return CommunityShareRepository(apiClient);
  },
);

class CommunityShareRepository implements CommunityShareRepositoryInterface {
  CommunityShareRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> shareResource({
    required String resourceType,
    required String resourceId,
    String? targetGroupId,
    String? targetUserId,
    String permission = 'view',
    String? comment,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final response = await _apiClient.post<dynamic>(
      ApiEndpoints.communityShare,
      data: {
        'resource_type': resourceType,
        'resource_id': resourceId,
        'target_group_id': targetGroupId,
        'target_user_id': targetUserId,
        'permission': permission,
        'comment': comment,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to share resource');
    }
  }
}

class MockCommunityShareRepository implements CommunityShareRepositoryInterface {
  @override
  Future<void> shareResource({
    required String resourceType,
    required String resourceId,
    String? targetGroupId,
    String? targetUserId,
    String permission = 'view',
    String? comment,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // In demo mode, just return success
  }
}
