import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/network/api_client.dart';

class AssetRepository {
  AssetRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<dynamic>> getInboxAssets({
    int limit = 50,
    int offset = 0,
  }) async {
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

  Future<Map<String, dynamic>> getInboxStats() async {
    final response = await _apiClient.get<dynamic>('/assets/inbox/stats');
    return response.data as Map<String, dynamic>;
  }

  Future<void> activateAsset(String id) async {
    await _apiClient.post<dynamic>('/assets/$id/activate');
  }

  Future<void> archiveAsset(String id) async {
    await _apiClient.post<dynamic>('/assets/$id/archive');
  }
}

final assetRepositoryProvider = Provider<AssetRepository>(
  (ref) => AssetRepository(ref.watch(apiClientProvider)),
);
