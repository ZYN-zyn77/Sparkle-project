import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:isar/isar.dart';
import 'package:logger/logger.dart';
import 'package:sparkle/core/offline/local_database.dart';

/// Phase 9 Sync Engine
///
/// Handles:
/// - Bootstrap sync for new devices
/// - Incremental event pulling
/// - Idempotent event application
/// - Conflict detection
class Phase9SyncEngine {
  Phase9SyncEngine(this._localDb, this._dio);

  final LocalDatabase _localDb;
  final Dio _dio;
  final Logger _logger = Logger();

  Timer? _incrementalSyncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isProcessing = false;
  bool _isBootstrapped = false;

  // === Lifecycle ===

  /// Initialize the sync engine
  Future<void> initialize() async {
    // Check if already bootstrapped
    final state = await _getSyncState();
    _isBootstrapped = state?.cursor != null;

    if (!_isBootstrapped) {
      await _performBootstrap();
    }

    // Start incremental sync
    _startIncrementalSync();
  }

  /// Stop the sync engine
  void stop() {
    _incrementalSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

  // === Bootstrap ===

  Future<SyncState?> _getSyncState() async {
    return await _localDb.isar.syncStates
        .filter()
        .keyEqualTo('main')
        .findFirst();
  }

  Future<void> _performBootstrap() async {
    _logger.i('Starting bootstrap sync...');

    try {
      final response = await _dio.get('/api/v1/sync/bootstrap');
      final data = response.data as Map<String, dynamic>;

      await _localDb.isar.writeTxn(() async {
        final snapshot = data['snapshot'] as Map<String, dynamic>;

        // 1. Store assets
        final assets = snapshot['assets'] as List<dynamic>? ?? [];
        for (final asset in assets) {
          final local = LocalLearningAsset()
            ..serverId = asset['id'] as String
            ..status = asset['status'] as String
            ..headword = asset['headword'] as String
            ..translation = asset['translation'] as String?
            ..definition = asset['definition'] as String?
            ..reviewDueAt = asset['review_due_at'] != null
                ? DateTime.parse(asset['review_due_at'] as String)
                : null
            ..reviewCount = asset['review_count'] as int? ?? 0
            ..updatedAt = DateTime.parse(asset['updated_at'] as String)
            ..syncStatus = SyncStatus.synced;
          await _localDb.isar.localLearningAssets.put(local);
        }

        // 2. Store links
        final links = snapshot['links'] as List<dynamic>? ?? [];
        for (final link in links) {
          final local = LocalAssetConceptLink()
            ..serverId = link['id'] as String
            ..assetId = link['asset_id'] as String
            ..conceptId = link['concept_id'] as String
            ..linkType = link['link_type'] as String
            ..confidence = (link['confidence'] as num?)?.toDouble() ?? 1.0
            ..updatedAt = DateTime.now();
          await _localDb.isar.localAssetConceptLinks.put(local);
        }

        // 3. Store concepts as LocalKnowledgeNode
        final concepts = snapshot['concepts'] as List<dynamic>? ?? [];
        for (final concept in concepts) {
          // Check if node already exists
          final existing = await _localDb.isar.localKnowledgeNodes
              .filter()
              .serverIdEqualTo(concept['id'] as String)
              .findFirst();

          if (existing == null) {
            final local = LocalKnowledgeNode()
              ..serverId = concept['id'] as String
              ..name = concept['name'] as String
              ..mastery = 0
              ..lastUpdated = DateTime.parse(concept['updated_at'] as String)
              ..globalSparkCount = 0
              ..syncStatus = SyncStatus.synced;
            await _localDb.isar.localKnowledgeNodes.put(local);
          }
        }

        // 4. Update node statuses
        final statuses = snapshot['statuses'] as List<dynamic>? ?? [];
        for (final status in statuses) {
          final nodeId = status['node_id'] as String;
          final node = await _localDb.isar.localKnowledgeNodes
              .filter()
              .serverIdEqualTo(nodeId)
              .findFirst();

          if (node != null) {
            node.mastery = ((status['mastery_score'] as num?) ?? 0).toInt();
            node.revision = (status['revision'] as int?) ?? 0;
            await _localDb.isar.localKnowledgeNodes.put(node);
          }
        }

        // 5. Update sync state
        final state = SyncState()
          ..key = 'main'
          ..cursor = data['cursor'] as String?
          ..lastSyncAt = DateTime.now()
          ..schemaVersion = '1';
        await _localDb.isar.syncStates.put(state);
      });

      _isBootstrapped = true;
      _logger.i('Bootstrap complete, cursor: ${data['cursor']}');
    } catch (e, st) {
      _logger.e('Bootstrap failed: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  // === Incremental Sync ===

  void _startIncrementalSync() {
    // Poll every 30 seconds
    _incrementalSyncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _pullEvents(),
    );

    // Also sync on connectivity restore
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none) && _isBootstrapped) {
        _pullEvents();
      }
    });
  }

  /// Manually trigger a sync
  Future<void> syncNow() async {
    if (!_isBootstrapped) {
      await _performBootstrap();
    } else {
      await _pullEvents();
    }
  }

  Future<void> _pullEvents() async {
    if (_isProcessing || !_isBootstrapped) return;
    _isProcessing = true;

    try {
      final state = await _getSyncState();
      if (state == null) return;

      var cursor = state.cursor;
      var hasMore = true;

      while (hasMore) {
        final response = await _dio.get(
          '/api/v1/sync/events',
          queryParameters: {'cursor': cursor, 'limit': 100},
        );

        final data = response.data as Map<String, dynamic>;
        final events = data['events'] as List<dynamic>? ?? [];

        for (final event in events) {
          await _applyEventIdempotent(event as Map<String, dynamic>);
        }

        cursor = data['next_cursor'] as String?;
        hasMore = data['has_more'] as bool? ?? false;

        // Update cursor after each batch
        await _localDb.isar.writeTxn(() async {
          final currentState = await _localDb.isar.syncStates
              .filter()
              .keyEqualTo('main')
              .findFirst();
          if (currentState != null) {
            currentState.cursor = cursor;
            currentState.lastSyncAt = DateTime.now();
            await _localDb.isar.syncStates.put(currentState);
          }
        });
      }

      _logger.d('Pull events completed');
    } catch (e, st) {
      _logger.e('Pull events failed: $e', error: e, stackTrace: st);
    } finally {
      _isProcessing = false;
    }
  }

  // === Idempotent Event Application ===

  Future<void> _applyEventIdempotent(Map<String, dynamic> event) async {
    final eventId = event['id'] as String;

    // 1. Check if already processed
    final existing = await _localDb.isar.processedEvents
        .filter()
        .eventIdEqualTo(eventId)
        .findFirst();

    if (existing != null) {
      _logger.d('Skipping already processed event: $eventId');
      return;
    }

    // 2. Apply event based on type
    final type = event['type'] as String;
    final payload = event['payload'];

    // Parse payload if it's a string
    Map<String, dynamic> payloadMap;
    if (payload is String) {
      payloadMap = jsonDecode(payload) as Map<String, dynamic>;
    } else if (payload is Map) {
      payloadMap = Map<String, dynamic>.from(payload);
    } else {
      payloadMap = {};
    }

    await _localDb.isar.writeTxn(() async {
      switch (type) {
        case 'learning_asset.created':
        case 'learning_asset.updated':
          await _applyAssetEvent(payloadMap);
        case 'learning_asset.status_changed':
          await _applyAssetStatusChange(payloadMap);
        case 'asset_concept_link.link_upserted':
          await _applyLinkUpsert(payloadMap);
        case 'asset_concept_link.link_deleted':
          await _applyLinkDelete(payloadMap);
        case 'knowledge_node.node_created':
        case 'knowledge_node.updated':
          await _applyConceptEvent(payloadMap);
        default:
          _logger.w('Unknown event type: $type');
      }

      // 3. Record as processed
      final processed = ProcessedEvent()
        ..eventId = eventId
        ..aggregateId = event['aggregate_id'] as String
        ..sequence = event['sequence'] as int
        ..occurredAt = DateTime.parse(event['occurred_at'] as String)
        ..processedAt = DateTime.now();
      await _localDb.isar.processedEvents.put(processed);
    });
  }

  Future<void> _applyAssetEvent(Map<String, dynamic> payload) async {
    final serverId = (payload['asset_id'] ?? payload['id']) as String?;
    if (serverId == null) return;

    final existing = await _localDb.isar.localLearningAssets
        .filter()
        .serverIdEqualTo(serverId)
        .findFirst();

    if (existing != null) {
      // LWW: Update existing
      if (payload.containsKey('status')) {
        existing.status = payload['status'] as String;
      }
      if (payload.containsKey('headword')) {
        existing.headword = payload['headword'] as String;
      }
      existing.updatedAt = DateTime.now();
      await _localDb.isar.localLearningAssets.put(existing);
    } else {
      // Create new
      final local = LocalLearningAsset()
        ..serverId = serverId
        ..status = payload['status'] as String? ?? 'INBOX'
        ..headword = payload['headword'] as String? ?? ''
        ..updatedAt = DateTime.now()
        ..syncStatus = SyncStatus.synced;
      await _localDb.isar.localLearningAssets.put(local);
    }
  }

  Future<void> _applyAssetStatusChange(Map<String, dynamic> payload) async {
    final serverId = payload['asset_id'] as String?;
    if (serverId == null) return;

    final existing = await _localDb.isar.localLearningAssets
        .filter()
        .serverIdEqualTo(serverId)
        .findFirst();

    if (existing != null) {
      existing.status = payload['new_status'] as String? ?? existing.status;
      existing.updatedAt = DateTime.now();
      await _localDb.isar.localLearningAssets.put(existing);
    }
  }

  Future<void> _applyLinkUpsert(Map<String, dynamic> payload) async {
    final assetId = payload['asset_id'] as String?;
    final conceptId = payload['concept_id'] as String?;
    if (assetId == null || conceptId == null) return;

    final linkType = payload['link_type'] as String? ?? 'provenance';
    final confidence = (payload['confidence'] as num?)?.toDouble() ?? 1.0;

    // Check if link exists
    final existing = await _localDb.isar.localAssetConceptLinks
        .filter()
        .assetIdEqualTo(assetId)
        .and()
        .conceptIdEqualTo(conceptId)
        .and()
        .linkTypeEqualTo(linkType)
        .findFirst();

    if (existing != null) {
      existing.confidence = confidence;
      existing.updatedAt = DateTime.now();
      await _localDb.isar.localAssetConceptLinks.put(existing);
    } else {
      final local = LocalAssetConceptLink()
        ..serverId = '${assetId}_${conceptId}_$linkType'
        ..assetId = assetId
        ..conceptId = conceptId
        ..linkType = linkType
        ..confidence = confidence
        ..updatedAt = DateTime.now();
      await _localDb.isar.localAssetConceptLinks.put(local);
    }
  }

  Future<void> _applyLinkDelete(Map<String, dynamic> payload) async {
    final assetId = payload['asset_id'] as String?;
    final conceptId = payload['concept_id'] as String?;
    if (assetId == null || conceptId == null) return;

    final link = await _localDb.isar.localAssetConceptLinks
        .filter()
        .assetIdEqualTo(assetId)
        .and()
        .conceptIdEqualTo(conceptId)
        .findFirst();

    if (link != null) {
      await _localDb.isar.localAssetConceptLinks.delete(link.id);
    }
  }

  Future<void> _applyConceptEvent(Map<String, dynamic> payload) async {
    final serverId = (payload['node_id'] ?? payload['id']) as String?;
    if (serverId == null) return;

    final existing = await _localDb.isar.localKnowledgeNodes
        .filter()
        .serverIdEqualTo(serverId)
        .findFirst();

    if (existing != null) {
      if (payload.containsKey('name')) {
        existing.name = payload['name'] as String;
      }
      existing.lastUpdated = DateTime.now();
      await _localDb.isar.localKnowledgeNodes.put(existing);
    } else {
      final local = LocalKnowledgeNode()
        ..serverId = serverId
        ..name = payload['name'] as String? ?? 'Unknown'
        ..mastery = 0
        ..lastUpdated = DateTime.now()
        ..globalSparkCount = 0
        ..syncStatus = SyncStatus.synced;
      await _localDb.isar.localKnowledgeNodes.put(local);
    }
  }

  // === Conflict Detection ===

  Future<void> recordConflict({
    required String entityType,
    required String entityId,
    required String conflictType,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> serverData,
  }) async {
    await _localDb.isar.writeTxn(() async {
      final conflict = SyncConflict()
        ..entityType = entityType
        ..entityId = entityId
        ..conflictType = conflictType
        ..localData = jsonEncode(localData)
        ..serverData = jsonEncode(serverData)
        ..detectedAt = DateTime.now()
        ..resolved = false;
      await _localDb.isar.syncConflicts.put(conflict);
    });
  }

  /// Get unresolved conflicts
  Future<List<SyncConflict>> getUnresolvedConflicts() async {
    return await _localDb.isar.syncConflicts
        .filter()
        .resolvedEqualTo(false)
        .findAll();
  }

  /// Mark conflict as resolved
  Future<void> resolveConflict(int conflictId) async {
    await _localDb.isar.writeTxn(() async {
      final conflict = await _localDb.isar.syncConflicts.get(conflictId);
      if (conflict != null) {
        conflict.resolved = true;
        await _localDb.isar.syncConflicts.put(conflict);
      }
    });
  }
}
