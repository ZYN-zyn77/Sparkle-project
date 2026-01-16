import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sparkle/core/design/design_system.dart';
import 'package:sparkle/features/knowledge/presentation/providers/inbox_provider.dart';

class InboxList extends ConsumerStatefulWidget {
  const InboxList({super.key});

  @override
  ConsumerState<InboxList> createState() => _InboxListState();
}

class _InboxListState extends ConsumerState<InboxList> {
  @override
  void initState() {
    super.initState();
    ref.read(inboxProvider.notifier).fetchInbox();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inboxProvider);

    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildHeader(state),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // Space for FAB if any
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index] as Map<String, dynamic>;
              return _InboxItemCard(
                item: item,
                onActivate: () => ref.read(inboxProvider.notifier).activate(item['id']),
                onArchive: () => ref.read(inboxProvider.notifier).archive(item['id']),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: DS.neutral300),
          const SizedBox(height: DS.lg),
          Text(
            '待办箱空空如也',
            style: TextStyle(color: DS.neutral500, fontSize: 16),
          ),
          const SizedBox(height: DS.sm),
          Text(
            '收藏的生词会先出现在这里',
            style: TextStyle(color: DS.neutral400, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(InboxState state) {
    if (state.expiringCount == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.all(DS.md),
      padding: const EdgeInsets.symmetric(horizontal: DS.lg, vertical: DS.sm),
      decoration: BoxDecoration(
        color: DS.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DS.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, size: 16, color: DS.warning),
          const SizedBox(width: DS.sm),
          Text(
            '${state.expiringCount} 个生词即将在24小时内自动归档',
            style: TextStyle(color: DS.warning, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _InboxItemCard extends StatelessWidget {
  const _InboxItemCard({
    required this.item,
    required this.onActivate,
    required this.onArchive,
  });

  final Map<String, dynamic> item;
  final VoidCallback onActivate;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final headword = item['headword'] ?? '';
    final translation = item['translation'] ?? item['definition'] ?? '';
    final expiresAt = item['inbox_expires_at'] as String?;
    
    String expiryText = '';
    Color expiryColor = DS.neutral500;
    
    if (expiresAt != null) {
      final days = DateTime.parse(expiresAt).difference(DateTime.now()).inDays;
      if (days < 1) {
        expiryText = '即将过期';
        expiryColor = DS.error;
      } else {
        expiryText = '$days天后自动归档';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: DS.md, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: DS.neutral200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DS.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    headword,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  expiryText,
                  style: TextStyle(fontSize: 12, color: expiryColor),
                ),
              ],
            ),
            if (translation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                translation,
                style: TextStyle(color: DS.neutral600, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: DS.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onArchive,
                  style: TextButton.styleFrom(
                    foregroundColor: DS.neutral500,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const Text('忽略'),
                ),
                const SizedBox(width: DS.sm),
                ElevatedButton.icon(
                  onPressed: onActivate,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('开始学习'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DS.brandPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
