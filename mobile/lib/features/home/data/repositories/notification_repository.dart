import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/network/api_client.dart';
import 'package:sparkle/core/services/demo_data_service.dart';
import 'package:sparkle/features/home/data/models/notification_model.dart';

/// Interface for notification repository
abstract class NotificationRepositoryInterface {
  Future<List<NotificationModel>> getNotifications({
    int skip = 0,
    int limit = 50,
    bool unreadOnly = false,
  });

  Future<void> markAsRead(String id);
}

final notificationRepositoryProvider = Provider<NotificationRepositoryInterface>(
  (ref) {
    if (DemoDataService.isDemoMode) {
      return MockNotificationRepository();
    }
    return NotificationRepository(ref.read(apiClientProvider));
  },
);

class NotificationRepository implements NotificationRepositoryInterface {
  NotificationRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<List<NotificationModel>> getNotifications({
    int skip = 0,
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final response = await _apiClient.get<dynamic>(
      '/notifications/',
      queryParameters: {
        'skip': skip,
        'limit': limit,
        'unread_only': unreadOnly,
      },
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markAsRead(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _apiClient.put<dynamic>('/notifications/$id/read');
  }
}

class MockNotificationRepository implements NotificationRepositoryInterface {
  @override
  Future<List<NotificationModel>> getNotifications({
    int skip = 0,
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final data = DemoDataService().demoNotifications;
    final filtered = unreadOnly
        ? data.where((notif) => notif['read'] == false).toList()
        : data;
    return filtered
        .map(NotificationModel.fromJson)
        .toList();
  }

  @override
  Future<void> markAsRead(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // In demo mode, just return success
  }
}
