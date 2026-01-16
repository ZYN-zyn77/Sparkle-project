# Phase 9 Baseline

> **Generated**: 2026-01-16
> **Purpose**: 记录Phase 9实施前的现有基础设施状态

---

## 现有表结构

### event_outbox

事件溯源核心表，用于存储所有领域事件。

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| id | UUID | NOT NULL | PK, gen_random_uuid() |
| aggregate_type | VARCHAR(100) | NOT NULL | 聚合类型 (learning_asset, knowledge_node等) |
| aggregate_id | UUID | NOT NULL | 聚合ID |
| event_type | VARCHAR(100) | NOT NULL | 事件类型 (asset_created等) |
| event_version | INTEGER | NOT NULL | 默认1 |
| sequence_number | BIGINT | NOT NULL | 单聚合内单调递增 |
| payload | JSONB | NOT NULL | 事件数据 |
| metadata | JSONB | NULL | 附加元数据 |
| created_at | TIMESTAMPTZ | NOT NULL | 自动设置 |
| published_at | TIMESTAMPTZ | NULL | 发布时间 |

**索引**:
- `idx_outbox_unpublished` - 部分索引 (published_at IS NULL)
- `idx_outbox_aggregate` - (aggregate_type, aggregate_id)

---

### event_sequence_counters

保证单聚合sequence单调递增的计数器表。

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| aggregate_type | VARCHAR(100) | NOT NULL | PK组成部分 |
| aggregate_id | UUID | NOT NULL | PK组成部分 |
| next_sequence | BIGINT | NOT NULL | 下一个序列号，默认1 |

---

### learning_assets

学习资产核心表。

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| id | UUID | NOT NULL | PK |
| user_id | UUID | NOT NULL | FK users.id, ON DELETE CASCADE |
| status | VARCHAR(20) | NOT NULL | INBOX/ACTIVE/ARCHIVED |
| asset_kind | VARCHAR(20) | NOT NULL | WORD/SENTENCE/CONCEPT |
| headword | VARCHAR(255) | NOT NULL | 主词条 |
| definition | TEXT | NULL | 定义 |
| translation | TEXT | NULL | 翻译 |
| example | TEXT | NULL | 例句 |
| language_code | VARCHAR(10) | NOT NULL | 默认"en" |
| snapshot_json | JSONB | NULL | 原始上下文快照(不可变) |
| snapshot_schema_version | INTEGER | NOT NULL | 默认1 |
| provenance_json | JSONB | NULL | 溯源信息(可变) |
| provenance_updated_at | TIMESTAMPTZ | NULL | 溯源更新时间 |
| selection_fp | VARCHAR(64) | NULL | 选中文本指纹 |
| anchor_fp | VARCHAR(64) | NULL | 锚点指纹 |
| doc_fp | VARCHAR(64) | NULL | 文档指纹 |
| norm_version | VARCHAR(20) | NOT NULL | 默认"v1" |
| match_profile | VARCHAR(50) | NULL | 匹配策略 |
| review_due_at | TIMESTAMPTZ | NULL | 下次复习时间 |
| review_count | INTEGER | NOT NULL | 默认0 |
| review_success_rate | FLOAT | NOT NULL | 默认0.0 |
| last_seen_at | TIMESTAMPTZ | NULL | 最后查看时间 |
| embedding | VECTOR(1536) | NULL | pgvector嵌入向量 |
| embedding_updated_at | TIMESTAMPTZ | NULL | 嵌入更新时间 |
| lookup_count | INTEGER | NOT NULL | 默认1 |
| star_count | INTEGER | NOT NULL | 默认0 |
| ignored_count | INTEGER | NOT NULL | 默认0 |
| inbox_expires_at | TIMESTAMPTZ | NULL | 收件箱过期时间 |
| source_file_id | UUID | NULL | FK stored_files.id |
| created_at | TIMESTAMPTZ | NOT NULL | 创建时间 |
| updated_at | TIMESTAMPTZ | NOT NULL | 更新时间 |
| deleted_at | TIMESTAMPTZ | NULL | 软删除时间 |

**索引**:
- `idx_learning_assets_user_status` - (user_id, status)
- `idx_learning_assets_review_due` - (user_id, review_due_at) WHERE status='ACTIVE'
- `idx_learning_assets_selection_fp` - (user_id, selection_fp)
- `idx_learning_assets_inbox_expires` - WHERE status='INBOX'

---

### knowledge_nodes

知识图谱节点表。

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| id | UUID | NOT NULL | PK |
| subject_id | INTEGER | NULL | FK subjects.id |
| parent_id | UUID | NULL | FK self, 支持层级 |
| name | VARCHAR(255) | NOT NULL | 节点名称 |
| name_en | VARCHAR(255) | NULL | 英文名称 |
| description | TEXT | NULL | 描述 |
| keywords | JSONB | NULL | 关键词 |
| importance_level | INTEGER | NOT NULL | 1-5, 默认1 |
| is_seed | BOOLEAN | NOT NULL | 默认False |
| source_type | VARCHAR(20) | NOT NULL | seed/user_created/llm_expanded/document_import |
| source_task_id | UUID | NULL | 来源任务ID |
| source_file_id | UUID | NULL | FK stored_files.id |
| chunk_refs | JSONB | NULL | chunk引用列表 |
| status | VARCHAR(20) | NOT NULL | draft/published/needs_review |
| embedding | VECTOR(1536) | NULL | pgvector嵌入向量 |
| position_x | FLOAT | NULL | X坐标(视口查询) |
| position_y | FLOAT | NULL | Y坐标(视口查询) |
| global_spark_count | INTEGER | NOT NULL | 默认0 |
| created_at | TIMESTAMPTZ | NOT NULL | 创建时间 |
| updated_at | TIMESTAMPTZ | NOT NULL | 更新时间 |
| deleted_at | TIMESTAMPTZ | NULL | 软删除时间 |

---

### node_relations

知识图谱边表。

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| id | UUID | NOT NULL | PK |
| source_node_id | UUID | NOT NULL | FK knowledge_nodes.id |
| target_node_id | UUID | NOT NULL | FK knowledge_nodes.id |
| relation_type | VARCHAR(30) | NOT NULL | prerequisite/related/application/composition/evolution |
| strength | FLOAT | NOT NULL | 0-1, 默认0.5 |
| created_by | VARCHAR(20) | NOT NULL | seed/user/llm |
| created_at | TIMESTAMPTZ | NOT NULL | 创建时间 |
| updated_at | TIMESTAMPTZ | NOT NULL | 更新时间 |
| deleted_at | TIMESTAMPTZ | NULL | 软删除时间 |

> ⚠️ **注意**: 当前无user_id字段，是全局边

---

### user_node_status

用户-节点状态表（掌握度、复习等）。

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| user_id | UUID | NOT NULL | PK组成部分, FK users.id |
| node_id | UUID | NOT NULL | PK组成部分, FK knowledge_nodes.id |
| mastery_score | FLOAT | NOT NULL | 0-100, 默认0 |
| bkt_mastery_prob | FLOAT | NOT NULL | 0-1, 默认0.0 (BKT概率) |
| bkt_last_updated_at | TIMESTAMPTZ | NULL | BKT更新时间 |
| total_minutes | INTEGER | NOT NULL | 默认0 |
| total_study_minutes | INTEGER | NOT NULL | 默认0 |
| study_count | INTEGER | NOT NULL | 默认0 |
| is_unlocked | BOOLEAN | NOT NULL | 默认False |
| is_collapsed | BOOLEAN | NOT NULL | 默认False |
| is_favorite | BOOLEAN | NOT NULL | 默认False |
| last_study_at | TIMESTAMPTZ | NULL | 最后学习时间 |
| last_interacted_at | TIMESTAMPTZ | NOT NULL | 最后交互时间 |
| decay_paused | BOOLEAN | NOT NULL | 默认False |
| next_review_at | TIMESTAMPTZ | NULL | 下次复习时间 |
| revision | INTEGER | NOT NULL | 默认0 (逻辑时钟，冲突检测) |
| first_unlock_at | TIMESTAMPTZ | NULL | 首次解锁时间 |
| created_at | TIMESTAMPTZ | NOT NULL | 创建时间 |
| updated_at | TIMESTAMPTZ | NOT NULL | 更新时间 |

---

## 已有事件类型

| 事件类型 | aggregate_type | payload字段 |
|---------|----------------|-------------|
| asset_created | learning_asset | headword, kind, status, has_provenance |
| asset_status_changed | learning_asset | old_status, new_status, triggered_by |
| review_recorded | learning_asset | asset_id, difficulty, review_count, next_review_at, success_rate |

---

## Phase 9 新增事件类型

| 事件类型 | aggregate_type | payload最小字段 |
|---------|----------------|----------------|
| asset_concept_link.upserted | asset_concept_link | asset_id, concept_id, link_type, confidence |
| asset_concept_link.deleted | asset_concept_link | asset_id, concept_id |
| user_node_relation.upserted | user_node_relation | src_concept_id, dst_concept_id, relation_type, weight |
| review.calibrated | learning_asset | asset_id, difficulty, predicted_recall, actual_recall, brier_error |
| node_created | knowledge_node | name, source |

---

## 现有服务方法

### LearningAssetService (`backend/app/services/learning_asset_service.py`)

- `create_asset_from_selection()` - 从选中文本创建资产
- `get_asset_by_id()` - 获取资产
- `activate_asset()` - 激活资产（INBOX → ACTIVE）
- `archive_asset()` - 归档资产
- `record_review()` - 记录复习
- `_write_event_outbox()` - 写入事件到outbox（私有方法）

**事件写入模式**:
```python
# 1. 原子性获取并递增序列号
INSERT INTO event_sequence_counters
  (aggregate_type, aggregate_id, next_sequence) VALUES (..., 1)
ON CONFLICT DO UPDATE SET next_sequence = next_sequence + 1
RETURNING next_sequence

# 2. 写入事件
INSERT INTO event_outbox
  (aggregate_type, aggregate_id, event_type, event_version,
   sequence_number, payload, metadata)
VALUES (...)
```

---

## Flutter本地存储 (Isar)

### Collections

| Collection | 关键字段 | 用途 |
|------------|---------|------|
| LocalKnowledgeNode | serverId, name, mastery, revision, syncStatus | 本地节点缓存 |
| PendingUpdate | nodeId, newMastery, revision, syncStatus | 待同步更新 |
| LocalCRDTSnapshot | galaxyId, updateData(Yjs binary), synced | CRDT快照 |
| OutboxItem | type, payloadJson, retryCount, status | 离线操作队列 |

### SyncStatus枚举
- pending - 待同步
- synced - 已同步
- conflict - 冲突
- failed - 失败
- waitingAck - 等待确认

---

## 关键约束

1. **主键**: 全部使用UUID
2. **软删除**: 所有表继承BaseModel，使用deleted_at字段
3. **时间**: 统一使用datetime with timezone (UTC)
4. **JSONB限长**: metadata字段最大2KB
5. **事件单调性**: 同一聚合的sequence_number单调递增

---

## 验证命令

```sql
-- 验证event_outbox
SELECT aggregate_type, event_type, COUNT(*)
FROM event_outbox
GROUP BY aggregate_type, event_type;

-- 验证sequence_counters
SELECT * FROM event_sequence_counters LIMIT 10;

-- 验证learning_assets
SELECT status, COUNT(*) FROM learning_assets
WHERE deleted_at IS NULL
GROUP BY status;

-- 验证knowledge_nodes有position
SELECT COUNT(*) as total,
       COUNT(position_x) as with_position
FROM knowledge_nodes
WHERE deleted_at IS NULL;
```

---

## 待实现（Phase 9范围）

1. **asset_concept_links表** - 资产-概念关联
2. **node_relations.user_id** - 用户私有边支持
3. **review_calibration_logs表** - 复习校准日志
4. **Sync API** - Bootstrap + 增量事件流
5. **Flutter新Collections** - LocalLearningAsset, LocalAssetConceptLink, ProcessedEvent, SyncState, SyncConflict
