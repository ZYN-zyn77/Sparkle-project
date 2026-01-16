import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/network/api_client.dart';
import 'package:sparkle/core/network/api_endpoints.dart';
import 'package:sparkle/core/services/demo_data_service.dart';
import 'package:sparkle/features/focus/data/models/focus_session_model.dart';

/// Repository for focus session operations (P0.3)
class FocusRepository implements IFocusRepository {
  FocusRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Log a completed focus session and receive flame rewards
  ///
  /// P0.3: Called when user exits focus mode to persist session data
  /// and update user flame level
  Future<FocusSessionResponse> logFocusSession({
    required DateTime startTime,
    required DateTime endTime,
    required int durationMinutes,
    String? taskId,
    String focusType = 'pomodoro',
    String status = 'completed',
    String? whiteNoiseType,
  }) async {
    try {
      final request = FocusSessionRequest(
        taskId: taskId,
        startTime: startTime,
        endTime: endTime,
        durationMinutes: durationMinutes,
        focusType: focusType,
        status: status,
        whiteNoiseType: whiteNoiseType,
      );

      debugPrint('📤 Logging focus session: ${request.toJson()}');

      final response = await _apiClient.post<dynamic>(
        ApiEndpoints.focusSessions,
        data: request.toJson(),
      );

      debugPrint('📥 Focus session logged: ${response.data}');

      return FocusSessionResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      debugPrint('❌ Failed to log focus session: ${e.message}');
      debugPrint('Response: ${e.response?.data}');
      rethrow;
    }
  }

  /// Get today's focus statistics
  Future<FocusStatsResponse> getFocusStats() async {
    try {
      final response =
          await _apiClient.get<dynamic>(ApiEndpoints.focusStats);

      return FocusStatsResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      debugPrint('❌ Failed to get focus stats: ${e.message}');
      rethrow;
    }
  }

  /// Get LLM methodological guidance during focus
  Future<String> getLLMGuidance({
    required String taskTitle,
    required String context,
  }) async {
    try {
      final response = await _apiClient.post<dynamic>(
        ApiEndpoints.focusLlmGuide,
        data: {
          'task_title': taskTitle,
          'context': context,
        },
      );

      final data = response.data as Map<String, dynamic>;
      return data['guidance'] as String;
    } on DioException catch (e) {
      debugPrint('❌ Failed to get LLM guidance: ${e.message}');
      rethrow;
    }
  }

  /// Break down a task using LLM
  Future<List<String>> breakdownTask({
    required String taskTitle,
    required String taskType,
  }) async {
    try {
      final response = await _apiClient.post<dynamic>(
        ApiEndpoints.focusLlmBreakdown,
        data: {
          'task_title': taskTitle,
          'task_type': taskType,
        },
      );

      final data = response.data as Map<String, dynamic>;
      return (data['subtasks'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    } on DioException catch (e) {
      debugPrint('❌ Failed to breakdown task: ${e.message}');
      rethrow;
    }
  }
}

/// Focus repository provider (P0.3)
final focusRepositoryProvider = Provider<IFocusRepository>((ref) {
  if (DemoDataService.isDemoMode) {
    return MockFocusRepository();
  }
  final apiClient = ref.watch(apiClientProvider);
  return FocusRepository(apiClient);
});

/// Interface for focus repository
abstract class IFocusRepository {
  Future<FocusSessionResponse> logFocusSession({
    required DateTime startTime,
    required DateTime endTime,
    required int durationMinutes,
    String? taskId,
    String focusType,
    String status,
    String? whiteNoiseType,
  });

  Future<FocusStatsResponse> getFocusStats();

  Future<String> getLLMGuidance({
    required String taskTitle,
    required String context,
  });

  Future<List<String>> breakdownTask({
    required String taskTitle,
    required String taskType,
  });
}

class MockFocusRepository implements IFocusRepository {
  final DemoDataService _demoData = DemoDataService();

  Future<FocusSessionResponse> logFocusSession({
    required DateTime startTime,
    required DateTime endTime,
    required int durationMinutes,
    String? taskId,
    String focusType = 'pomodoro',
    String status = 'completed',
    String? whiteNoiseType,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return FocusSessionResponse(
      success: true,
      id: 'focus_${DateTime.now().millisecondsSinceEpoch}',
      rewards: FocusSessionRewards(
        flameEarned: durationMinutes ~/ 10,
        leveledUp: false,
        newLevel: 15,
      ),
    );
  }

  Future<FocusStatsResponse> getFocusStats() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final demoData = _demoData.demoFocusStats;
    return FocusStatsResponse.fromJson(demoData);
  }

  Future<String> getLLMGuidance({
    required String taskTitle,
    required String context,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final demoData = _demoData.demoLLMGuidance;
    return demoData['guidance'] as String;
  }

  Future<List<String>> breakdownTask({
    required String taskTitle,
    required String taskType,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _demoData.demoTaskBreakdown;
  }
}
