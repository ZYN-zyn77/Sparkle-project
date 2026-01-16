import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/network/api_client.dart';
import 'package:sparkle/core/services/demo_data_service.dart';
import 'package:sparkle/features/cognitive/data/models/curiosity_capsule_model.dart';

abstract class ICapsuleRepository {
  Future<List<CuriosityCapsuleModel>> getTodayCapsules();
  Future<void> markAsRead(String id);
}

class CapsuleRepository implements ICapsuleRepository {
  CapsuleRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<List<CuriosityCapsuleModel>> getTodayCapsules() async {
    final response = await _apiClient.get<dynamic>('/capsules/today');
    return (response.data as List)
        .map((e) => CuriosityCapsuleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markAsRead(String id) async {
    await _apiClient.post<dynamic>('/capsules/$id/read');
  }
}

class MockCapsuleRepository implements ICapsuleRepository {
  final DemoDataService _demoData = DemoDataService();

  @override
  Future<List<CuriosityCapsuleModel>> getTodayCapsules() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final demoData = _demoData.demoTodayCapsules;
    return demoData
        .map(CuriosityCapsuleModel.fromJson)
        .toList();
  }

  @override
  Future<void> markAsRead(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return;
  }
}

final capsuleRepositoryProvider = Provider<ICapsuleRepository>(
    (ref) {
  if (DemoDataService.isDemoMode) {
    return MockCapsuleRepository();
  }
  return CapsuleRepository(ref.watch(apiClientProvider));
},);
