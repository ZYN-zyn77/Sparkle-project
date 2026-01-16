import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/network/api_client.dart';
import 'package:sparkle/core/services/demo_data_service.dart';

/// Interface for asset repository
abstract class AssetRepositoryInterface {
  Future<List<dynamic>> getInboxAssets({
    int limit = 50,
    int offset = 0,
  });

  Future<Map<String, dynamic>> getInboxStats();

  Future<void> activateAsset(String id);

  Future<void> archiveAsset(String id);
}

final assetRepositoryProvider = Provider<AssetRepositoryInterface>(
  (ref) {
    if (DemoDataService.isDemoMode) {
      return MockAssetRepository();
    }
    return AssetRepository(ref.watch(apiClientProvider));
  },
);

class AssetRepository implements AssetRepositoryInterface {
  AssetRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<List<dynamic>> getInboxAssets({
    int limit = 50,
    int offset = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final response = await _apiClient.get<dynamic>(
      '/assets',
      queryParameters: {
        'status': 'INBOX',
        'limit': limit,
        'offset': offset,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return data['assets'] as List<dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getInboxStats() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final response = await _apiClient.get<dynamic>('/assets/inbox/stats');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> activateAsset(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _apiClient.post<dynamic>('/assets/$id/activate');
  }

  @override
  Future<void> archiveAsset(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _apiClient.post<dynamic>('/assets/$id/archive');
  }
}

class MockAssetRepository implements AssetRepositoryInterface {
  @override
  Future<List<dynamic>> getInboxAssets({
    int limit = 50,
    int offset = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return DemoDataService().demoInboxAssets;
  }

  @override
  Future<Map<String, dynamic>> getInboxStats() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return DemoDataService().demoInboxStats;
  }

  @override
  Future<void> activateAsset(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // In demo mode, just return success
  }

  @override
  Future<void> archiveAsset(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // In demo mode, just return success
  }
}
