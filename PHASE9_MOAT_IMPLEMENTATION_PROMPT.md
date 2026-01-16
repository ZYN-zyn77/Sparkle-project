# Phase 9 护城河工程 - 执行Agent实施Prompt

> **目标**：构建三飞轮闭环体验护城河（资产→图谱、复习→个性化、多端一致）
> **执行方式**：按Milestone顺序执行，每个Milestone独立可验收可回滚

---

## 🧠 架构理解前置（必读）

执行前必须理解现有架构：

### 已有基础设施
```
事件系统:
├── event_outbox表 (aggregate_type, aggregate_id, event_type, sequence_number, payload)
├── event_sequence_counters表 (保证单聚合sequence单调递增)
└── Redis EventBus (实时发布订阅)

学习资产:
├── learning_assets表 (status, headword, snapshot_json, provenance_json, SRS字段)
├── LearningAssetService (backend/app/services/learning_asset_service.py)
└── 已有事件: asset_created, asset_status_changed, review_recorded

知识图谱:
├── knowledge_nodes表 (name, embedding, position_x/y, status)
├── node_relations表 (source_node_id, target_node_id, relation_type, strength, created_by)
│   ⚠️ 注意: 是全局边，没有user_id
├── user_node_status表 (user_id, node_id, mastery_score, bkt_mastery_prob, revision, next_review_at)
└── GalaxyService (backend/app/services/galaxy_service.py)

Flutter本地存储:
├── 使用 Isar (不是SQLite!)
├── LocalKnowledgeNode, PendingUpdate, OutboxItem, LocalCRDTSnapshot
└── SyncEngine (mobile/lib/core/offline/sync_engine.dart)
```

### 关键文件路径
```
Python Models:
- /backend/app/models/learning_assets.py (LearningAsset, AssetSuggestionLog)
- /backend/app/models/galaxy.py (KnowledgeNode, NodeRelation, UserNodeStatus)
- /backend/app/models/base.py (BaseModel with soft delete)

Python Services:
- /backend/app/services/learning_asset_service.py (1042行，已有SRS/事件写入)
- /backend/app/services/galaxy_service.py
- /backend/app/services/galaxy_grpc_service.py

Alembic Migrations:
- /backend/alembic/versions/

Flutter Offline:
- /mobile/lib/core/offline/local_database.dart (Isar schema)
- /mobile/lib/core/offline/sync_engine.dart

Proto:
- /proto/galaxy_service.proto (已有UpdateNodeMastery, SyncCollaborativeGalaxy)
```

---

## M0：现状验证与基线对齐（4小时）

### M0.1 验证基础设施可用性

```bash
# 1. 验证事件outbox写入
# 在Python中测试:
from sqlalchemy import text
await db.execute(text("SELECT * FROM event_outbox LIMIT 5"))
await db.execute(text("SELECT * FROM event_sequence_counters LIMIT 5"))

# 2. 验证fingerprint生成
from app.core.fingerprint import generate_fingerprints
fp = generate_fingerprints("polymorphism")
assert fp.selection_fp is not None

# 3. 验证provenance匹配
from app.models.learning_assets import MatchStrength
assert MatchStrength.STRONG.value == "STRONG"
```

### M0.2 输出基线文档

创建文件 `/docs/PHASE9_BASELINE.md`:

```markdown
# Phase 9 Baseline

## 现有表结构

### event_outbox
- id, aggregate_type, aggregate_id, event_type, event_version, sequence_number, payload, metadata, created_at, processed_at

### event_sequence_counters
- aggregate_type, aggregate_id, next_sequence

### learning_assets
- [列出所有字段]

### knowledge_nodes
- [列出所有字段，特别标注 position_x/y]

### node_relations
- ⚠️ 无user_id，是全局边

### user_node_status
- 有revision字段用于冲突检测
- 有bkt_mastery_prob用于BKT

## Phase 9 事件类型集合

| 事件类型 | aggregate_type | payload最小字段 |
|---------|----------------|----------------|
| asset_concept_link.upserted | asset_concept_link | asset_id, concept_id, link_type, confidence |
| asset_concept_link.deleted | asset_concept_link | asset_id, concept_id |
| user_node_relation.upserted | user_node_relation | src_concept_id, dst_concept_id, relation_type, weight |
| review.calibrated | learning_asset | asset_id, difficulty, predicted_recall, actual_recall, brier_error |
```

### M0.3 验收标准
- [ ] 能查询event_outbox并看到历史事件
- [ ] fingerprint生成链路可用
- [ ] 输出PHASE9_BASELINE.md

---

## M1：数据模型扩展（1天）

### M1.1 新表：asset_concept_links

**文件**: `/backend/alembic/versions/p20_add_asset_concept_links.py`

```python
"""add asset_concept_links table

Revision ID: p20
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

def upgrade():
    op.create_table(
        'asset_concept_links',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('asset_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('learning_assets.id', ondelete='CASCADE'), nullable=False),
        sa.Column('concept_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('knowledge_nodes.id', ondelete='CASCADE'), nullable=False),
        sa.Column('link_type', sa.String(32), nullable=False),  # provenance | co_activation | manual
        sa.Column('confidence', sa.Float, nullable=False, server_default='1.0'),
        sa.Column('metadata', postgresql.JSONB, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
    )

    # 部分唯一索引（软删除友好）
    op.create_index(
        'uix_asset_concept_link_unique',
        'asset_concept_links',
        ['user_id', 'asset_id', 'concept_id', 'link_type'],
        unique=True,
        postgresql_where=sa.text('deleted_at IS NULL')
    )

    op.create_index('idx_acl_user_asset', 'asset_concept_links', ['user_id', 'asset_id'], postgresql_where=sa.text('deleted_at IS NULL'))
    op.create_index('idx_acl_user_concept', 'asset_concept_links', ['user_id', 'concept_id'], postgresql_where=sa.text('deleted_at IS NULL'))

def downgrade():
    op.drop_table('asset_concept_links')
```

**ORM Model**: `/backend/app/models/asset_concept_link.py`

```python
"""Asset-Concept Link Model"""
import enum
from sqlalchemy import Column, String, Float, ForeignKey, DateTime
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from app.models.base import BaseModel, GUID


class LinkType(str, enum.Enum):
    PROVENANCE = "provenance"       # 来自文档溯源
    CO_ACTIVATION = "co_activation"  # 同会话激活
    MANUAL = "manual"               # 用户手动关联


class AssetConceptLink(BaseModel):
    """
    资产-概念关联表

    连接LearningAsset（用户收集的词汇/句子）与KnowledgeNode（知识图谱概念）
    """
    __tablename__ = "asset_concept_links"

    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    asset_id = Column(GUID(), ForeignKey("learning_assets.id", ondelete="CASCADE"), nullable=False, index=True)
    concept_id = Column(GUID(), ForeignKey("knowledge_nodes.id", ondelete="CASCADE"), nullable=False, index=True)
    link_type = Column(String(32), nullable=False)
    confidence = Column(Float, nullable=False, default=1.0)
    metadata = Column(JSONB, nullable=True)

    # Relationships
    asset = relationship("LearningAsset")
    concept = relationship("KnowledgeNode")
```

### M1.2 扩展node_relations支持用户私有边

**方案A（推荐）**: 给现有`node_relations`表添加`user_id`字段

```python
# Migration: p21_add_user_id_to_node_relations.py

def upgrade():
    op.add_column('node_relations', sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=True))
    op.create_foreign_key('fk_node_relations_user', 'node_relations', 'users', ['user_id'], ['id'], ondelete='CASCADE')
    op.create_index('idx_nr_user_relation', 'node_relations', ['user_id', 'relation_type'], postgresql_where=sa.text('deleted_at IS NULL'))

def downgrade():
    op.drop_constraint('fk_node_relations_user', 'node_relations', type_='foreignkey')
    op.drop_column('node_relations', 'user_id')
```

**约定**:
- `user_id IS NULL` → 全局边（seed/system生成）
- `user_id IS NOT NULL` → 用户私有边（co_activation/co_review）

### M1.3 新表：review_calibration_logs

```python
# Migration: p22_add_review_calibration_logs.py

def upgrade():
    op.create_table(
        'review_calibration_logs',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('asset_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('learning_assets.id', ondelete='SET NULL'), nullable=True),
        sa.Column('concept_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('knowledge_nodes.id', ondelete='SET NULL'), nullable=True),
        sa.Column('reviewed_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('difficulty', sa.String(16), nullable=False),  # easy/good/hard
        sa.Column('predicted_recall', sa.Float, nullable=True),
        sa.Column('actual_recall', sa.Boolean, nullable=True),
        sa.Column('brier_error', sa.Float, nullable=True),
        sa.Column('review_count', sa.Integer, nullable=False),
        sa.Column('interval_days_before', sa.Integer, nullable=True),
        sa.Column('interval_days_after', sa.Integer, nullable=True),
        sa.Column('explanation_code', sa.String(50), nullable=True),  # learning_difficulty_adjusted, etc.
        sa.Column('metadata', postgresql.JSONB, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    )

    op.create_index('idx_rcl_user_reviewed', 'review_calibration_logs', ['user_id', 'reviewed_at'])
    op.create_index('idx_rcl_asset', 'review_calibration_logs', ['asset_id'])

def downgrade():
    op.drop_table('review_calibration_logs')
```

### M1.4 验收标准
- [ ] `alembic upgrade head` 成功
- [ ] `alembic downgrade -1` 可回滚（验证后再upgrade回来）
- [ ] 部分唯一索引测试：同一(user, asset, concept, link_type)不能重复插入（除非软删）
- [ ] 插入测试数据确认关系正常

---

## M2：图谱飞轮（资产→概念链接生成）（1.5天）

### M2.1 AssetConceptLinkService

**文件**: `/backend/app/services/asset_concept_link_service.py`

```python
"""
Asset-Concept Link Service

核心职责:
1. 资产创建时自动生成 provenance 链接
2. 根据headword匹配或创建concept节点
3. 写入事件到outbox
"""
from datetime import datetime, timezone
from typing import Optional, List
from uuid import UUID
import json

from sqlalchemy import select, and_, text
from sqlalchemy.ext.asyncio import AsyncSession
from loguru import logger

from app.models.asset_concept_link import AssetConceptLink, LinkType
from app.models.learning_assets import LearningAsset, MatchStrength
from app.models.galaxy import KnowledgeNode


# === 护栏常量 ===
MAX_METADATA_BYTES = 2048


class AssetConceptLinkService:
    """资产-概念链接服务"""

    async def generate_links_for_asset(
        self,
        db: AsyncSession,
        asset: LearningAsset,
    ) -> List[AssetConceptLink]:
        """
        为新资产生成概念链接

        规则:
        1. 根据provenance.match_strength确定confidence
        2. 尝试匹配已有concept，不存在则创建
        3. 写入事件到outbox
        """
        links = []

        # 1. 获取或创建concept
        concept = await self._get_or_create_concept(
            db=db,
            headword=asset.headword,
            user_id=asset.user_id,
            language_code=asset.language_code,
        )

        # 2. 计算confidence
        provenance = asset.provenance_json or {}
        match_strength = provenance.get("match_strength", "ORPHAN")
        confidence = self._strength_to_confidence(match_strength)

        # 3. 构建metadata（限长）
        metadata = self._build_limited_metadata(provenance)

        # 4. Upsert链接
        link = await self._upsert_link(
            db=db,
            user_id=asset.user_id,
            asset_id=asset.id,
            concept_id=concept.id,
            link_type=LinkType.PROVENANCE,
            confidence=confidence,
            metadata=metadata,
        )
        links.append(link)

        logger.info(f"Generated {len(links)} links for asset {asset.id} → concept {concept.id}")
        return links

    async def _get_or_create_concept(
        self,
        db: AsyncSession,
        headword: str,
        user_id: UUID,
        language_code: str,
    ) -> KnowledgeNode:
        """获取或创建概念节点"""
        # 按headword精确匹配
        query = select(KnowledgeNode).where(
            and_(
                KnowledgeNode.name == headword,
                KnowledgeNode.deleted_at.is_(None),
            )
        ).limit(1)

        result = await db.execute(query)
        existing = result.scalar_one_or_none()

        if existing:
            return existing

        # 创建最小节点
        node = KnowledgeNode(
            name=headword,
            source_type="user_created",
            status="published",
            # position将由LayoutService计算
        )
        db.add(node)
        await db.flush()
        await db.refresh(node)

        # 写入事件
        await self._write_event(
            db=db,
            aggregate_type="knowledge_node",
            aggregate_id=node.id,
            event_type="node_created",
            payload={"name": headword, "source": "asset_link"},
        )

        return node

    def _strength_to_confidence(self, strength: str) -> float:
        """匹配强度转置信度"""
        mapping = {
            "STRONG": 0.9,
            "WEAK": 0.6,
            "ORPHAN": 0.4,
        }
        return mapping.get(strength, 0.4)

    def _build_limited_metadata(self, provenance: dict) -> Optional[dict]:
        """构建限长metadata"""
        if not provenance:
            return None

        # 只保留关键字段（不含全文）
        allowed_keys = ["chunk_id", "doc_id", "page_no", "score", "match_strength"]
        filtered = {k: v for k, v in provenance.items() if k in allowed_keys}

        # 限长检查
        serialized = json.dumps(filtered)
        if len(serialized) > MAX_METADATA_BYTES:
            filtered["truncated"] = True
            filtered["original_size"] = len(serialized)
            # 移除最大的字段直到满足限制
            while len(json.dumps(filtered)) > MAX_METADATA_BYTES and len(filtered) > 2:
                largest_key = max(filtered.keys(), key=lambda k: len(str(filtered.get(k, ""))))
                if largest_key not in ["truncated", "original_size"]:
                    del filtered[largest_key]

        return filtered

    async def _upsert_link(
        self,
        db: AsyncSession,
        user_id: UUID,
        asset_id: UUID,
        concept_id: UUID,
        link_type: LinkType,
        confidence: float,
        metadata: Optional[dict],
    ) -> AssetConceptLink:
        """Upsert链接（部分唯一索引友好）"""
        # 查找已有链接
        query = select(AssetConceptLink).where(
            and_(
                AssetConceptLink.user_id == user_id,
                AssetConceptLink.asset_id == asset_id,
                AssetConceptLink.concept_id == concept_id,
                AssetConceptLink.link_type == link_type.value,
                AssetConceptLink.deleted_at.is_(None),
            )
        )
        result = await db.execute(query)
        existing = result.scalar_one_or_none()

        if existing:
            existing.confidence = confidence
            existing.metadata = metadata
            existing.updated_at = datetime.now(timezone.utc)
            link = existing
        else:
            link = AssetConceptLink(
                user_id=user_id,
                asset_id=asset_id,
                concept_id=concept_id,
                link_type=link_type.value,
                confidence=confidence,
                metadata=metadata,
            )
            db.add(link)

        await db.flush()
        if not existing:
            await db.refresh(link)

        # 写入事件
        await self._write_event(
            db=db,
            aggregate_type="asset_concept_link",
            aggregate_id=link.id,
            event_type="link_upserted",
            payload={
                "asset_id": str(asset_id),
                "concept_id": str(concept_id),
                "link_type": link_type.value,
                "confidence": confidence,
            },
        )

        return link

    async def _write_event(
        self,
        db: AsyncSession,
        aggregate_type: str,
        aggregate_id: UUID,
        event_type: str,
        payload: dict,
    ) -> None:
        """写入事件到outbox（复用现有机制）"""
        seq_result = await db.execute(
            text("""
                INSERT INTO event_sequence_counters (aggregate_type, aggregate_id, next_sequence)
                VALUES (:aggregate_type, :aggregate_id, 1)
                ON CONFLICT (aggregate_type, aggregate_id)
                DO UPDATE SET next_sequence = event_sequence_counters.next_sequence + 1
                RETURNING next_sequence
            """),
            {"aggregate_type": aggregate_type, "aggregate_id": aggregate_id}
        )
        sequence_number = seq_result.scalar()

        await db.execute(
            text("""
                INSERT INTO event_outbox
                (aggregate_type, aggregate_id, event_type, event_version, sequence_number, payload, metadata)
                VALUES (:aggregate_type, :aggregate_id, :event_type, 1, :sequence_number, :payload, :metadata)
            """),
            {
                "aggregate_type": aggregate_type,
                "aggregate_id": aggregate_id,
                "event_type": event_type,
                "sequence_number": sequence_number,
                "payload": json.dumps(payload),
                "metadata": json.dumps({"service": "asset_concept_link_service"}),
            }
        )


# Singleton
asset_concept_link_service = AssetConceptLinkService()
```

### M2.2 集成到LearningAssetService

在 `/backend/app/services/learning_asset_service.py` 的 `create_asset_from_selection` 方法末尾添加:

```python
# 在 return asset 之前添加:

# 7. Generate concept links (async, non-blocking)
try:
    from app.services.asset_concept_link_service import asset_concept_link_service
    await asset_concept_link_service.generate_links_for_asset(db, asset)
except Exception as e:
    # 链接生成失败不应阻断资产创建
    logger.warning(f"Failed to generate concept links for asset {asset.id}: {e}")

return asset
```

### M2.3 用户私有边生成（co_activation）

创建Celery任务 `/backend/app/tasks/co_activation_builder.py`:

```python
"""
Co-Activation Edge Builder

每日任务：分析用户行为，生成概念间co_activation边
"""
from datetime import datetime, timedelta, timezone
from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.asset_concept_link import AssetConceptLink
from app.models.galaxy import NodeRelation


async def build_co_activation_edges(db: AsyncSession, user_id: UUID, window_days: int = 7):
    """
    构建用户的co_activation边

    规则：同一用户在window_days内激活的资产，其关联概念形成边
    """
    cutoff = datetime.now(timezone.utc) - timedelta(days=window_days)

    # 查询用户近期的资产-概念链接
    query = select(
        AssetConceptLink.concept_id,
        func.array_agg(AssetConceptLink.asset_id).label("asset_ids"),
        func.count(AssetConceptLink.id).label("count"),
    ).where(
        and_(
            AssetConceptLink.user_id == user_id,
            AssetConceptLink.created_at >= cutoff,
            AssetConceptLink.deleted_at.is_(None),
        )
    ).group_by(AssetConceptLink.concept_id)

    result = await db.execute(query)
    concept_data = result.fetchall()

    # 构建共现矩阵并生成边
    concepts = [row.concept_id for row in concept_data]
    for i, c1 in enumerate(concepts):
        for c2 in concepts[i+1:]:
            # 检查是否已有边
            existing = await db.execute(
                select(NodeRelation).where(
                    and_(
                        NodeRelation.source_node_id == c1,
                        NodeRelation.target_node_id == c2,
                        NodeRelation.user_id == user_id,
                        NodeRelation.relation_type == "co_activation",
                        NodeRelation.deleted_at.is_(None),
                    )
                )
            )
            if existing.scalar_one_or_none():
                # 更新权重（指数衰减）
                pass  # TODO: implement weight update
            else:
                # 创建新边
                edge = NodeRelation(
                    source_node_id=c1,
                    target_node_id=c2,
                    user_id=user_id,
                    relation_type="co_activation",
                    strength=0.5,
                    created_by="system",
                )
                db.add(edge)

    await db.commit()
```

### M2.4 验收标准
- [ ] 创建资产后1秒内可查到`asset_concept_links`记录
- [ ] `event_outbox`中有`link_upserted`事件
- [ ] Galaxy可查询到新概念节点（若headword不存在则创建）
- [ ] 对同一资产重复触发不产生重复链接

---

## M3：同步飞轮（事件流API）（2天）

### M3.1 Proto定义扩展

**文件**: `/proto/sync_service.proto`

```protobuf
syntax = "proto3";

package sync.v1;

option go_package = "github.com/sparkle/gateway/gen/sync/v1;syncv1";

import "google/protobuf/timestamp.proto";

service SyncService {
  // Bootstrap: 获取初始状态快照
  rpc Bootstrap(BootstrapRequest) returns (BootstrapResponse);

  // GetEvents: 获取增量事件
  rpc GetEvents(GetEventsRequest) returns (GetEventsResponse);
}

message BootstrapRequest {
  string user_id = 1;
  string schema_version = 2;  // 客户端schema版本
}

message BootstrapResponse {
  string cursor = 1;  // 用于后续GetEvents
  SnapshotData snapshot = 2;
}

message SnapshotData {
  repeated LearningAssetSnapshot assets = 1;
  repeated AssetConceptLinkSnapshot links = 2;
  repeated ConceptSnapshot concepts = 3;
  repeated UserNodeStatusSnapshot statuses = 4;
}

message LearningAssetSnapshot {
  string id = 1;
  string status = 2;
  string headword = 3;
  string translation = 4;
  google.protobuf.Timestamp review_due_at = 5;
  int32 review_count = 6;
  google.protobuf.Timestamp updated_at = 7;
}

message AssetConceptLinkSnapshot {
  string id = 1;
  string asset_id = 2;
  string concept_id = 3;
  string link_type = 4;
  double confidence = 5;
}

message ConceptSnapshot {
  string id = 1;
  string name = 2;
  double position_x = 3;
  double position_y = 4;
  google.protobuf.Timestamp updated_at = 5;
}

message UserNodeStatusSnapshot {
  string node_id = 1;
  double mastery_score = 2;
  int64 revision = 3;
  google.protobuf.Timestamp next_review_at = 4;
}

message GetEventsRequest {
  string user_id = 1;
  string cursor = 2;  // 上次返回的cursor
  int32 limit = 3;    // 最大返回数量，默认100
}

message GetEventsResponse {
  repeated SyncEvent events = 1;
  string next_cursor = 2;
  bool has_more = 3;
}

message SyncEvent {
  string id = 1;
  string type = 2;           // e.g., "learning_asset.created"
  string aggregate_id = 3;
  int64 sequence = 4;
  google.protobuf.Timestamp occurred_at = 5;
  bytes payload = 6;         // JSON payload (限长)
}
```

### M3.2 Go Gateway实现

**文件**: `/backend/gateway/internal/handler/sync_handler.go`

```go
package handler

import (
    "encoding/json"
    "net/http"
    "strconv"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/sparkle/gateway/internal/service"
)

// Payload大小限制
const MaxEventPayloadBytes = 2048

type SyncHandler struct {
    syncService *service.SyncService
}

func NewSyncHandler(syncService *service.SyncService) *SyncHandler {
    return &SyncHandler{syncService: syncService}
}

// Bootstrap returns initial state snapshot
func (h *SyncHandler) Bootstrap(c *gin.Context) {
    userID := c.GetString("user_id") // from auth middleware

    snapshot, cursor, err := h.syncService.GetBootstrapData(c.Request.Context(), userID)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "cursor":   cursor,
        "snapshot": snapshot,
    })
}

// GetEvents returns incremental events after cursor
func (h *SyncHandler) GetEvents(c *gin.Context) {
    userID := c.GetString("user_id")
    cursor := c.Query("cursor")
    limitStr := c.DefaultQuery("limit", "100")
    limit, _ := strconv.Atoi(limitStr)
    if limit > 500 {
        limit = 500
    }

    events, nextCursor, hasMore, err := h.syncService.GetEvents(
        c.Request.Context(), userID, cursor, limit,
    )
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    // Enforce payload size limits
    for i := range events {
        events[i].Payload = truncatePayload(events[i].Payload, MaxEventPayloadBytes)
    }

    c.JSON(http.StatusOK, gin.H{
        "events":      events,
        "next_cursor": nextCursor,
        "has_more":    hasMore,
    })
}

func truncatePayload(payload json.RawMessage, maxBytes int) json.RawMessage {
    if len(payload) <= maxBytes {
        return payload
    }

    // Parse, truncate, re-serialize
    var data map[string]interface{}
    if err := json.Unmarshal(payload, &data); err != nil {
        return json.RawMessage(`{"truncated":true}`)
    }

    data["truncated"] = true
    data["original_size"] = len(payload)

    // Remove large fields until under limit
    for len(payload) > maxBytes && len(data) > 2 {
        var largestKey string
        var largestSize int
        for k, v := range data {
            if k == "truncated" || k == "original_size" {
                continue
            }
            size := len(fmt.Sprintf("%v", v))
            if size > largestSize {
                largestSize = size
                largestKey = k
            }
        }
        if largestKey != "" {
            delete(data, largestKey)
        }
        payload, _ = json.Marshal(data)
    }

    return payload
}
```

### M3.3 SyncService实现

**文件**: `/backend/gateway/internal/service/sync_service.go`

```go
package service

import (
    "context"
    "encoding/base64"
    "encoding/json"
    "strconv"
    "time"

    "github.com/jackc/pgx/v5/pgxpool"
)

type SyncEvent struct {
    ID          string          `json:"id"`
    Type        string          `json:"type"`
    AggregateID string          `json:"aggregate_id"`
    Sequence    int64           `json:"sequence"`
    OccurredAt  time.Time       `json:"occurred_at"`
    Payload     json.RawMessage `json:"payload"`
}

type SyncService struct {
    db *pgxpool.Pool
}

func NewSyncService(db *pgxpool.Pool) *SyncService {
    return &SyncService{db: db}
}

func (s *SyncService) GetBootstrapData(ctx context.Context, userID string) (map[string]interface{}, string, error) {
    snapshot := make(map[string]interface{})

    // 1. Fetch learning assets
    assets, err := s.fetchUserAssets(ctx, userID)
    if err != nil {
        return nil, "", err
    }
    snapshot["assets"] = assets

    // 2. Fetch asset-concept links
    links, err := s.fetchUserLinks(ctx, userID)
    if err != nil {
        return nil, "", err
    }
    snapshot["links"] = links

    // 3. Fetch related concepts
    concepts, err := s.fetchRelatedConcepts(ctx, userID)
    if err != nil {
        return nil, "", err
    }
    snapshot["concepts"] = concepts

    // 4. Fetch user node statuses
    statuses, err := s.fetchUserNodeStatuses(ctx, userID)
    if err != nil {
        return nil, "", err
    }
    snapshot["statuses"] = statuses

    // 5. Generate cursor (based on max event ID or timestamp)
    cursor, err := s.getCurrentCursor(ctx, userID)
    if err != nil {
        return nil, "", err
    }

    return snapshot, cursor, nil
}

func (s *SyncService) GetEvents(ctx context.Context, userID, cursor string, limit int) ([]SyncEvent, string, bool, error) {
    // Decode cursor (format: "event_id:timestamp")
    afterID := int64(0)
    if cursor != "" {
        decoded, _ := base64.StdEncoding.DecodeString(cursor)
        afterID, _ = strconv.ParseInt(string(decoded), 10, 64)
    }

    // Query events
    query := `
        SELECT id, aggregate_type || '.' || event_type as type,
               aggregate_id, sequence_number, created_at, payload
        FROM event_outbox
        WHERE id > $1
          AND (
            aggregate_type = 'learning_asset'
            OR aggregate_type = 'asset_concept_link'
            OR aggregate_type = 'knowledge_node'
          )
        ORDER BY id ASC
        LIMIT $2
    `

    rows, err := s.db.Query(ctx, query, afterID, limit+1)
    if err != nil {
        return nil, "", false, err
    }
    defer rows.Close()

    var events []SyncEvent
    for rows.Next() {
        var e SyncEvent
        if err := rows.Scan(&e.ID, &e.Type, &e.AggregateID, &e.Sequence, &e.OccurredAt, &e.Payload); err != nil {
            return nil, "", false, err
        }
        events = append(events, e)
    }

    hasMore := len(events) > limit
    if hasMore {
        events = events[:limit]
    }

    nextCursor := ""
    if len(events) > 0 {
        lastID := events[len(events)-1].ID
        nextCursor = base64.StdEncoding.EncodeToString([]byte(lastID))
    }

    return events, nextCursor, hasMore, nil
}

// ... fetchUserAssets, fetchUserLinks等辅助方法省略
```

### M3.4 路由注册

```go
// backend/gateway/internal/router/router.go

func SetupRoutes(r *gin.Engine, ...) {
    // ... 现有路由

    sync := r.Group("/api/v1/sync")
    sync.Use(authMiddleware.RequireAuth())
    {
        syncHandler := handler.NewSyncHandler(syncService)
        sync.GET("/bootstrap", syncHandler.Bootstrap)
        sync.GET("/events", syncHandler.GetEvents)
    }
}
```

### M3.5 验收标准
- [ ] `GET /api/v1/sync/bootstrap` 返回用户状态快照 + cursor
- [ ] `GET /api/v1/sync/events?cursor=xxx` 返回增量事件
- [ ] 事件payload符合限长要求（<2KB）
- [ ] 同一aggregate的事件sequence单调递增
- [ ] cursor可重放（重复请求返回稳定结果）

---

## M4：Flutter同步引擎（Isar + 幂等应用）（2天）

### M4.1 扩展Isar Schema

**文件**: `/mobile/lib/core/offline/local_database.dart`

```dart
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

// === 现有Collections保持不变 ===

@collection
class LocalKnowledgeNode {
  // ... 保持现有代码
}

@collection
class PendingUpdate {
  // ... 保持现有代码
}

@collection
class LocalCRDTSnapshot {
  // ... 保持现有代码
}

@collection
class OutboxItem {
  // ... 保持现有代码
}

// === Phase 9 新增Collections ===

@collection
class LocalLearningAsset {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String serverId;

  late String status;  // INBOX, ACTIVE, ARCHIVED
  late String headword;
  String? translation;
  String? definition;

  DateTime? reviewDueAt;
  int reviewCount = 0;

  late DateTime updatedAt;

  @enumerated
  SyncStatus syncStatus = SyncStatus.synced;
}

@collection
class LocalAssetConceptLink {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String serverId;

  late String assetId;
  late String conceptId;
  late String linkType;
  double confidence = 1.0;

  late DateTime updatedAt;
}

@collection
class ProcessedEvent {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String eventId;  // 服务端事件ID

  late String aggregateId;
  late int sequence;
  late DateTime occurredAt;
  late DateTime processedAt;
}

@collection
class SyncState {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String key = 'main';  // 单例key

  String? cursor;
  DateTime? lastSyncAt;
  String schemaVersion = '1';
}

@collection
class SyncConflict {
  Id id = Isar.autoIncrement;

  late String entityType;  // asset, link, concept
  late String entityId;
  late String conflictType;  // version_mismatch, deleted_on_server
  late String localData;  // JSON
  late String serverData;  // JSON
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
    isar = await Isar.open(
      [
        LocalKnowledgeNodeSchema,
        PendingUpdateSchema,
        LocalCRDTSnapshotSchema,
        OutboxItemSchema,
        // Phase 9 新增
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
```

### M4.2 SyncEngine重构

**文件**: `/mobile/lib/core/offline/sync_engine.dart`

```dart
import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:isar/isar.dart';
import 'package:logger/logger.dart';
import 'package:sparkle/core/offline/local_database.dart';

class SyncEngine {
  SyncEngine(this._localDb, this._dio);

  final LocalDatabase _localDb;
  final Dio _dio;
  final Logger _logger = Logger();

  StreamSubscription<void>? _outboxSubscription;
  bool _isProcessing = false;
  bool _isBootstrapped = false;

  // === 初始化 ===

  Future<void> initialize() async {
    // 检查是否需要bootstrap
    final state = await _getSyncState();
    _isBootstrapped = state?.cursor != null;

    if (!_isBootstrapped) {
      await _performBootstrap();
    }

    // 启动增量同步
    _startIncrementalSync();
    _startOutboxProcessor();
  }

  Future<SyncState?> _getSyncState() async {
    return await _localDb.isar.syncStates
        .filter()
        .keyEqualTo('main')
        .findFirst();
  }

  // === Bootstrap ===

  Future<void> _performBootstrap() async {
    _logger.i('Starting bootstrap sync...');

    try {
      final response = await _dio.get('/api/v1/sync/bootstrap');
      final data = response.data;

      await _localDb.isar.writeTxn(() async {
        // 1. 写入assets
        for (final asset in data['snapshot']['assets'] ?? []) {
          final local = LocalLearningAsset()
            ..serverId = asset['id']
            ..status = asset['status']
            ..headword = asset['headword']
            ..translation = asset['translation']
            ..reviewDueAt = asset['review_due_at'] != null
                ? DateTime.parse(asset['review_due_at'])
                : null
            ..reviewCount = asset['review_count'] ?? 0
            ..updatedAt = DateTime.parse(asset['updated_at']);
          await _localDb.isar.localLearningAssets.put(local);
        }

        // 2. 写入links
        for (final link in data['snapshot']['links'] ?? []) {
          final local = LocalAssetConceptLink()
            ..serverId = link['id']
            ..assetId = link['asset_id']
            ..conceptId = link['concept_id']
            ..linkType = link['link_type']
            ..confidence = link['confidence'] ?? 1.0
            ..updatedAt = DateTime.now();
          await _localDb.isar.localAssetConceptLinks.put(local);
        }

        // 3. 写入concepts
        for (final concept in data['snapshot']['concepts'] ?? []) {
          final local = LocalKnowledgeNode()
            ..serverId = concept['id']
            ..name = concept['name']
            ..mastery = 0  // 从statuses获取
            ..lastUpdated = DateTime.parse(concept['updated_at'])
            ..syncStatus = SyncStatus.synced;
          await _localDb.isar.localKnowledgeNodes.put(local);
        }

        // 4. 更新sync state
        final state = SyncState()
          ..key = 'main'
          ..cursor = data['cursor']
          ..lastSyncAt = DateTime.now()
          ..schemaVersion = '1';
        await _localDb.isar.syncStates.put(state);
      });

      _isBootstrapped = true;
      _logger.i('Bootstrap complete, cursor: ${data['cursor']}');

    } catch (e) {
      _logger.e('Bootstrap failed: $e');
      rethrow;
    }
  }

  // === 增量同步 ===

  void _startIncrementalSync() {
    // 每30秒或网络恢复时触发
    Timer.periodic(const Duration(seconds: 30), (_) => _pullEvents());

    Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none) && _isBootstrapped) {
        _pullEvents();
      }
    });
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

        final events = response.data['events'] as List;

        for (final event in events) {
          await _applyEventIdempotent(event);
        }

        cursor = response.data['next_cursor'];
        hasMore = response.data['has_more'] ?? false;

        // 更新cursor
        await _localDb.isar.writeTxn(() async {
          state.cursor = cursor;
          state.lastSyncAt = DateTime.now();
          await _localDb.isar.syncStates.put(state);
        });
      }

    } catch (e) {
      _logger.e('Pull events failed: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // === 幂等事件应用 ===

  Future<void> _applyEventIdempotent(Map<String, dynamic> event) async {
    final eventId = event['id'] as String;

    // 1. 检查是否已处理
    final existing = await _localDb.isar.processedEvents
        .filter()
        .eventIdEqualTo(eventId)
        .findFirst();

    if (existing != null) {
      _logger.d('Skipping already processed event: $eventId');
      return;
    }

    // 2. 应用事件
    final type = event['type'] as String;
    final payload = event['payload'];

    await _localDb.isar.writeTxn(() async {
      switch (type) {
        case 'learning_asset.created':
        case 'learning_asset.updated':
          await _applyAssetEvent(payload);
          break;
        case 'learning_asset.status_changed':
          await _applyAssetStatusChange(payload);
          break;
        case 'asset_concept_link.upserted':
          await _applyLinkUpsert(payload);
          break;
        case 'asset_concept_link.deleted':
          await _applyLinkDelete(payload);
          break;
        case 'knowledge_node.created':
        case 'knowledge_node.updated':
          await _applyConceptEvent(payload);
          break;
        default:
          _logger.w('Unknown event type: $type');
      }

      // 3. 记录已处理
      final processed = ProcessedEvent()
        ..eventId = eventId
        ..aggregateId = event['aggregate_id']
        ..sequence = event['sequence']
        ..occurredAt = DateTime.parse(event['occurred_at'])
        ..processedAt = DateTime.now();
      await _localDb.isar.processedEvents.put(processed);
    });
  }

  Future<void> _applyAssetEvent(Map<String, dynamic> payload) async {
    final serverId = payload['asset_id'] ?? payload['id'];
    final existing = await _localDb.isar.localLearningAssets
        .filter()
        .serverIdEqualTo(serverId)
        .findFirst();

    if (existing != null) {
      // LWW: 更新现有
      existing.status = payload['status'] ?? existing.status;
      existing.headword = payload['headword'] ?? existing.headword;
      existing.updatedAt = DateTime.now();
      await _localDb.isar.localLearningAssets.put(existing);
    } else {
      // 创建新的
      final local = LocalLearningAsset()
        ..serverId = serverId
        ..status = payload['status'] ?? 'INBOX'
        ..headword = payload['headword'] ?? ''
        ..updatedAt = DateTime.now();
      await _localDb.isar.localLearningAssets.put(local);
    }
  }

  Future<void> _applyAssetStatusChange(Map<String, dynamic> payload) async {
    // 类似逻辑...
  }

  Future<void> _applyLinkUpsert(Map<String, dynamic> payload) async {
    // 类似逻辑...
  }

  Future<void> _applyLinkDelete(Map<String, dynamic> payload) async {
    final assetId = payload['asset_id'];
    final conceptId = payload['concept_id'];

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
    // 类似逻辑...
  }

  // === Outbox处理（保持现有逻辑）===

  void _startOutboxProcessor() {
    // ... 保持现有outbox处理逻辑
  }

  void stop() {
    _outboxSubscription?.cancel();
  }
}
```

### M4.3 验收标准
- [ ] 新设备首次启动执行bootstrap，本地有完整数据
- [ ] 增量事件拉取后processed_events记录
- [ ] 重复事件不重复处理（幂等性）
- [ ] 离线创建资产→恢复网络→同步到服务端→事件回流到本地

---

## M5：个性化调度 + Galaxy增量布局（1.5天）

### M5.1 复习校准闭环

扩展 `/backend/app/services/learning_asset_service.py`:

```python
# 在LearningAssetService类中添加

# === 动态间隔调整 ===

async def record_review_with_calibration(
    self,
    db: AsyncSession,
    user_id: UUID,
    asset_id: UUID,
    difficulty: str,
) -> Tuple[LearningAsset, Dict[str, Any]]:
    """
    记录复习结果并进行个性化校准

    Returns:
        (更新后的asset, 校准信息字典)
    """
    asset = await self.get_asset_by_id(db, asset_id, user_id)
    if not asset:
        raise ValueError(f"Asset not found: {asset_id}")

    # 1. 记录校准日志
    calibration = await self._record_calibration(db, asset, difficulty)

    # 2. 检查是否需要调整间隔
    adjustment = await self._check_interval_adjustment(db, user_id, asset_id)

    # 3. 应用调整后的间隔
    if adjustment["should_adjust"]:
        adjusted_intervals = self._get_adjusted_intervals(adjustment)
        base_interval = adjusted_intervals[min(asset.review_count, len(adjusted_intervals)-1)]
    else:
        base_interval = self.REVIEW_INTERVALS[difficulty][min(asset.review_count, 5)]

    # 4. 更新资产
    now = datetime.now(timezone.utc)
    asset.review_count += 1
    asset.last_seen_at = now
    asset.review_due_at = now + timedelta(days=base_interval)

    # 5. 更新成功率
    success_score = {'easy': 1.0, 'good': 0.7, 'hard': 0.3}[difficulty]
    alpha = 0.3
    if asset.review_count == 1:
        asset.review_success_rate = success_score
    else:
        asset.review_success_rate = alpha * success_score + (1-alpha) * asset.review_success_rate

    await db.flush()

    # 6. 写入事件
    await self._write_event_outbox(
        db=db,
        aggregate_type="learning_asset",
        aggregate_id=asset_id,
        event_type="review_calibrated",
        payload={
            "difficulty": difficulty,
            "interval_days": base_interval,
            "review_count": asset.review_count,
            "explanation_code": adjustment.get("explanation_code", "standard"),
            "adjustment_factor": adjustment.get("factor", 1.0),
        },
    )

    return asset, {
        "interval_days": base_interval,
        "explanation_code": adjustment.get("explanation_code", "standard"),
        "next_review_at": asset.review_due_at.isoformat(),
    }

async def _record_calibration(
    self,
    db: AsyncSession,
    asset: LearningAsset,
    difficulty: str,
) -> "ReviewCalibrationLog":
    """记录校准日志"""
    from app.models.review_calibration import ReviewCalibrationLog

    log = ReviewCalibrationLog(
        user_id=asset.user_id,
        asset_id=asset.id,
        reviewed_at=datetime.now(timezone.utc),
        difficulty=difficulty,
        review_count=asset.review_count + 1,
    )
    db.add(log)
    await db.flush()
    return log

async def _check_interval_adjustment(
    self,
    db: AsyncSession,
    user_id: UUID,
    asset_id: UUID,
) -> Dict[str, Any]:
    """检查是否需要间隔调整"""
    # 查询最近N次复习
    from app.models.review_calibration import ReviewCalibrationLog

    query = select(ReviewCalibrationLog).where(
        and_(
            ReviewCalibrationLog.user_id == user_id,
            ReviewCalibrationLog.asset_id == asset_id,
        )
    ).order_by(ReviewCalibrationLog.reviewed_at.desc()).limit(5)

    result = await db.execute(query)
    recent_logs = list(result.scalars().all())

    # 规则：连续3次hard → 缩短间隔
    if len(recent_logs) >= 3:
        last_three = [log.difficulty for log in recent_logs[:3]]
        if last_three == ["hard", "hard", "hard"]:
            return {
                "should_adjust": True,
                "factor": 0.5,  # 间隔减半
                "explanation_code": "learning_difficulty_adjusted",
            }

    # 规则：连续3次easy → 延长间隔
    if len(recent_logs) >= 3:
        last_three = [log.difficulty for log in recent_logs[:3]]
        if last_three == ["easy", "easy", "easy"]:
            return {
                "should_adjust": True,
                "factor": 1.5,  # 间隔延长50%
                "explanation_code": "mastery_accelerated",
            }

    return {"should_adjust": False}

def _get_adjusted_intervals(self, adjustment: Dict) -> List[int]:
    """获取调整后的间隔表"""
    factor = adjustment.get("factor", 1.0)
    base = self.REVIEW_INTERVALS["good"]
    return [max(1, int(d * factor)) for d in base]
```

### M5.2 Galaxy增量布局

**文件**: `/backend/app/services/galaxy_layout_service.py`

```python
"""
Galaxy Layout Service

职责：
1. 为新概念计算增量位置（不触发全局重排）
2. 支持位置锁定
3. 位置更新冷却（24小时内不重排）
"""
import random
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple, List
from uuid import UUID

import numpy as np
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.galaxy import KnowledgeNode
from app.services.embedding_service import embedding_service


class GalaxyLayoutService:
    """Galaxy布局服务"""

    # 位置更新冷却时间
    POSITION_COOLDOWN_HOURS = 24

    # 默认布局范围
    LAYOUT_RANGE = 1000.0  # -500 to 500

    async def compute_position_for_concept(
        self,
        db: AsyncSession,
        concept: KnowledgeNode,
        force: bool = False,
    ) -> Tuple[float, float]:
        """
        为概念计算位置

        策略：
        1. 如果有embedding，找kNN邻居取质心
        2. 否则随机位置
        3. 添加微扰动避免重叠
        """
        # 检查冷却
        if not force and self._is_position_locked(concept):
            return concept.position_x, concept.position_y

        if concept.embedding is not None:
            x, y = await self._compute_knn_position(db, concept)
        else:
            x, y = self._random_position()

        # 微扰动
        x += random.uniform(-5, 5)
        y += random.uniform(-5, 5)

        # 更新位置
        concept.position_x = x
        concept.position_y = y
        concept.updated_at = datetime.now(timezone.utc)

        await db.flush()

        return x, y

    async def _compute_knn_position(
        self,
        db: AsyncSession,
        concept: KnowledgeNode,
        k: int = 3,
    ) -> Tuple[float, float]:
        """基于kNN计算质心位置"""
        # 查找有embedding和位置的邻居节点
        query = select(KnowledgeNode).where(
            and_(
                KnowledgeNode.id != concept.id,
                KnowledgeNode.embedding.isnot(None),
                KnowledgeNode.position_x.isnot(None),
                KnowledgeNode.deleted_at.is_(None),
            )
        ).order_by(
            KnowledgeNode.embedding.cosine_distance(concept.embedding)
        ).limit(k)

        result = await db.execute(query)
        neighbors = list(result.scalars().all())

        if not neighbors:
            return self._random_position()

        # 计算质心
        xs = [n.position_x for n in neighbors if n.position_x is not None]
        ys = [n.position_y for n in neighbors if n.position_y is not None]

        if not xs or not ys:
            return self._random_position()

        return float(np.mean(xs)), float(np.mean(ys))

    def _random_position(self) -> Tuple[float, float]:
        """生成随机位置"""
        half = self.LAYOUT_RANGE / 2
        return (
            random.uniform(-half, half),
            random.uniform(-half, half),
        )

    def _is_position_locked(self, concept: KnowledgeNode) -> bool:
        """检查位置是否被锁定（冷却中）"""
        if concept.position_x is None or concept.position_y is None:
            return False

        if concept.updated_at is None:
            return False

        cooldown_until = concept.updated_at + timedelta(hours=self.POSITION_COOLDOWN_HOURS)
        return datetime.now(timezone.utc) < cooldown_until


# Singleton
galaxy_layout_service = GalaxyLayoutService()
```

### M5.3 集成到概念创建流程

在`AssetConceptLinkService._get_or_create_concept`中：

```python
# 创建新节点后，计算位置
from app.services.galaxy_layout_service import galaxy_layout_service

# ... 创建node后
await galaxy_layout_service.compute_position_for_concept(db, node)
```

### M5.4 验收标准
- [ ] 连续3次Hard后，下次间隔显著缩短（7d→3d左右）
- [ ] 复习响应包含`explanation_code`字段
- [ ] 新概念插入后有position_x/y（非null）
- [ ] 同一概念24小时内重复请求不改变位置

---

## M6：集成验收（0.5天）

### M6.1 三闭环演示脚本

**场景A：资产→图谱**
```bash
# 1. 创建资产
curl -X POST /api/v1/assets \
  -d '{"selected_text": "polymorphism", "translation": "多态"}'

# 2. 验证链接生成
curl /api/v1/assets/{asset_id}/links
# 应返回 asset_concept_links 记录

# 3. 验证Galaxy节点
curl /api/v1/galaxy/nodes?name=polymorphism
# 应返回节点，有position_x/y
```

**场景B：复习→个性化**
```bash
# 1. 连续3次标记Hard
for i in 1 2 3; do
  curl -X POST /api/v1/assets/{asset_id}/review -d '{"difficulty": "hard"}'
done

# 2. 检查间隔
curl /api/v1/assets/{asset_id}
# review_due_at 应该比标准间隔短
# 响应包含 explanation_code: "learning_difficulty_adjusted"
```

**场景C：多端一致**
```bash
# 1. 手机离线创建资产
# 2. 恢复网络
# 3. 另一设备调用 /sync/events
# 4. 验证资产同步
```

### M6.2 自动化测试检查清单

```python
# tests/test_phase9_integration.py

class TestPhase9Integration:
    async def test_asset_creates_concept_link(self):
        """资产创建后自动生成链接"""
        asset = await create_asset("polymorphism")
        links = await get_links_for_asset(asset.id)
        assert len(links) >= 1
        assert links[0].link_type == "provenance"

    async def test_consecutive_hard_reduces_interval(self):
        """连续Hard缩短间隔"""
        asset = await create_and_activate_asset("test")

        for _ in range(3):
            await review_asset(asset.id, "hard")

        result = await review_asset(asset.id, "hard")
        assert result["interval_days"] < 7  # 标准good是7天
        assert result["explanation_code"] == "learning_difficulty_adjusted"

    async def test_event_idempotency(self):
        """事件重复不重复处理"""
        event_id = "test-event-123"
        event = {"id": event_id, "type": "learning_asset.created", ...}

        await sync_engine.apply_event(event)
        await sync_engine.apply_event(event)  # 重复

        processed = await get_processed_events(event_id)
        assert len(processed) == 1

    async def test_bootstrap_then_incremental(self):
        """Bootstrap后增量同步"""
        # Bootstrap
        response = await client.get("/sync/bootstrap")
        cursor = response["cursor"]

        # 创建新资产
        await create_asset("new_word")

        # 增量同步
        events = await client.get(f"/sync/events?cursor={cursor}")
        assert any(e["type"] == "learning_asset.created" for e in events["events"])
```

### M6.3 护栏验证

```python
async def test_payload_size_limit():
    """事件payload限长"""
    events = await get_sync_events(cursor, limit=100)
    for event in events:
        assert len(json.dumps(event["payload"])) <= 2048

async def test_galaxy_position_stability():
    """位置稳定性"""
    node = await create_concept("test")
    pos1 = (node.position_x, node.position_y)

    # 刷新
    await refresh_concept_position(node.id)
    node = await get_concept(node.id)
    pos2 = (node.position_x, node.position_y)

    # 24小时内不应变化
    assert pos1 == pos2
```

---

## 交付物清单

1. **Alembic Migrations**
   - `p20_add_asset_concept_links.py`
   - `p21_add_user_id_to_node_relations.py`
   - `p22_add_review_calibration_logs.py`

2. **Python Services**
   - `/backend/app/models/asset_concept_link.py`
   - `/backend/app/models/review_calibration.py`
   - `/backend/app/services/asset_concept_link_service.py`
   - `/backend/app/services/galaxy_layout_service.py`
   - `/backend/app/tasks/co_activation_builder.py`

3. **Go Gateway**
   - `/backend/gateway/internal/handler/sync_handler.go`
   - `/backend/gateway/internal/service/sync_service.go`

4. **Proto**
   - `/proto/sync_service.proto`

5. **Flutter**
   - 扩展 `/mobile/lib/core/offline/local_database.dart`
   - 重构 `/mobile/lib/core/offline/sync_engine.dart`

6. **Tests**
   - `/backend/tests/test_phase9_integration.py`

7. **文档**
   - `/docs/PHASE9_BASELINE.md`

---

## 硬性约束提醒

执行过程中务必遵守：

- ✅ 主键一律UUID
- ✅ 所有表继承BaseModel软删语义
- ✅ 复用现有event_outbox/event_sequence_counters
- ✅ JSONB限长（MAX_METADATA_BYTES=2048）
- ✅ 全栈时间统一datetime.now(timezone.utc)
- ✅ 不提交gen/目录
- ❌ 不引入新事件系统
- ❌ 不直接落库全文
