import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

part 'local_database.g.dart';

enum SyncStatus {
  pending,
  synced,
  conflict,
  failed,
  waitingAck,
}

@collection
class LocalKnowledgeNode {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String serverId; // Corresponds to server node ID

  late String name;
  late int mastery;
  late DateTime lastUpdated;

  late int globalSparkCount; // New collaborative field

  int revision = 0; // Logical clock for conflict resolution

  @enumerated
  late SyncStatus syncStatus; // pending, synced, conflict

  String? error; // To store error messages
}

@collection
class PendingUpdate {
  Id id = Isar.autoIncrement;

  late String nodeId;
  late int newMastery;
  late DateTime timestamp;
  late bool synced;

  @Index()
  late DateTime createdAt;

  String? requestId; // UUID for ACK matching
  int revision = 0; // Logical clock at the time of update

  String? error; // To store error messages

  @enumerated
  SyncStatus syncStatus = SyncStatus.pending;
}

@collection
class LocalCRDTSnapshot {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String galaxyId;

  late List<int> updateData;
  late DateTime timestamp;
  late bool synced;
}

@collection
class OutboxItem {
  Id id = Isar.autoIncrement;

  @Index()
  late String type; // e.g. 'mastery_update', 'spark_creation'

  late String payloadJson; // Serialized JSON payload

  @Index()
  late DateTime createdAt;

  int retryCount = 0;

  @enumerated
  SyncStatus status = SyncStatus.pending;

  String? error;
}

// === Phase 9: New Collections for Asset-Concept Sync ===

/// Local cache of learning assets
@collection
class LocalLearningAsset {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String serverId;

  late String status; // INBOX, ACTIVE, ARCHIVED
  late String headword;
  String? translation;
  String? definition;

  DateTime? reviewDueAt;
  int reviewCount = 0;

  late DateTime updatedAt;

  @enumerated
  SyncStatus syncStatus = SyncStatus.synced;
}

/// Local cache of asset-concept links
@collection
class LocalAssetConceptLink {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String serverId;

  @Index()
  late String assetId;

  @Index()
  late String conceptId;

  late String linkType;
  double confidence = 1.0;

  late DateTime updatedAt;
}

/// Tracks processed events for idempotency
@collection
class ProcessedEvent {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String eventId; // Server event ID

  late String aggregateId;
  late int sequence;
  late DateTime occurredAt;
  late DateTime processedAt;
}

/// Singleton sync state storage
@collection
class SyncState {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String key = 'main'; // Singleton key

  String? cursor;
  DateTime? lastSyncAt;
  String schemaVersion = '1';
}

/// Conflict records for later resolution
@collection
class SyncConflict {
  Id id = Isar.autoIncrement;

  late String entityType; // asset, link, concept
  late String entityId;
  late String conflictType; // version_mismatch, deleted_on_server

  late String localData; // JSON
  late String serverData; // JSON

  late DateTime detectedAt;
  bool resolved = false;
}

class LocalDatabase {
  factory LocalDatabase() => _instance;

  LocalDatabase._internal();
  static final LocalDatabase _instance = LocalDatabase._internal();
  late Isar isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    // In production, you would fetch a secure key from SecureStorage
    // final secureStorage = const FlutterSecureStorage();
    // final encryptionKey = await secureStorage.read(key: 'db_key');

    isar = await Isar.open(
      [
        LocalKnowledgeNodeSchema,
        PendingUpdateSchema,
        LocalCRDTSnapshotSchema,
        OutboxItemSchema,
        // Phase 9 collections
        LocalLearningAssetSchema,
        LocalAssetConceptLinkSchema,
        ProcessedEventSchema,
        SyncStateSchema,
        SyncConflictSchema,
      ],
      directory: dir.path,
    );
  }
}
