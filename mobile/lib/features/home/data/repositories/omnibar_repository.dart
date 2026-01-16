import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/network/api_client.dart';
import 'package:sparkle/core/network/api_endpoints.dart';
import 'package:sparkle/core/services/demo_data_service.dart';

/// Interface for omni bar repository
abstract class OmniBarRepositoryInterface {
  Future<Map<String, dynamic>> dispatch(String text);
}

final omniBarRepositoryProvider = Provider<OmniBarRepositoryInterface>(
  (ref) {
    if (DemoDataService.isDemoMode) {
      return MockOmniBarRepository();
    }
    return OmniBarRepository(ref.read(apiClientProvider));
  },
);

class OmniBarRepository implements OmniBarRepositoryInterface {
  OmniBarRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> dispatch(String text) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final response = await _apiClient.post<dynamic>(
      ApiEndpoints.omnibarDispatch,
      data: {'text': text},
    );
    return response.data as Map<String, dynamic>;
  }
}

class MockOmniBarRepository implements OmniBarRepositoryInterface {
  @override
  Future<Map<String, dynamic>> dispatch(String text) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final data = DemoDataService().demoOmniBarDispatch;
    return data;
  }
}
