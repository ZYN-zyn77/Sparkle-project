import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/features/knowledge/data/repositories/asset_repository.dart';

class InboxState {
  const InboxState({
    this.items = const [],
    this.totalCount = 0,
    this.expiringCount = 0,
    this.isLoading = false,
    this.error,
  });

  final List<dynamic> items;
  final int totalCount;
  final int expiringCount;
  final bool isLoading;
  final String? error;

  InboxState copyWith({
    List<dynamic>? items,
    int? totalCount,
    int? expiringCount,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      InboxState(
        items: items ?? this.items,
        totalCount: totalCount ?? this.totalCount,
        expiringCount: expiringCount ?? this.expiringCount,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class InboxNotifier extends StateNotifier<InboxState> {
  InboxNotifier(this._repository) : super(const InboxState());
  final AssetRepository _repository;

  Future<void> fetchInbox() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Parallel fetch
      final results = await Future.wait([
        _repository.getInboxAssets(),
        _repository.getInboxStats(),
      ]);
      
      final items = results[0] as List<dynamic>;
      final stats = results[1] as Map<String, dynamic>;

      state = state.copyWith(
        items: items,
        totalCount: stats['total_count'] as int,
        expiringCount: stats['expiring_soon_count'] as int,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> activate(String id) async {
    try {
      await _repository.activateAsset(id);
      // Optimistic update
      state = state.copyWith(
        items: state.items.where((i) => i['id'] != id).toList(),
        totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
      );
      // Re-fetch stats in background to keep count accurate
      _refreshStats();
    } catch (e) {
      state = state.copyWith(error: '激活失败: $e');
    }
  }

  Future<void> archive(String id) async {
    try {
      await _repository.archiveAsset(id);
      state = state.copyWith(
        items: state.items.where((i) => i['id'] != id).toList(),
        totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
      );
      _refreshStats();
    } catch (e) {
      state = state.copyWith(error: '归档失败: $e');
    }
  }
  
  Future<void> _refreshStats() async {
    try {
      final stats = await _repository.getInboxStats();
      state = state.copyWith(
        totalCount: stats['total_count'] as int,
        expiringCount: stats['expiring_soon_count'] as int,
      );
    } catch (e) {
      // Ignore background refresh errors
    }
  }
}

final inboxProvider = StateNotifierProvider<InboxNotifier, InboxState>(
  (ref) => InboxNotifier(ref.watch(assetRepositoryProvider)),
);
