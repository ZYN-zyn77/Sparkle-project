package service

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// MaxEventPayloadBytes is the maximum size for event payloads
const MaxEventPayloadBytes = 2048

// SyncEvent represents a sync event for client consumption
type SyncEvent struct {
	ID          string          `json:"id"`
	Type        string          `json:"type"`
	AggregateID string          `json:"aggregate_id"`
	Sequence    int64           `json:"sequence"`
	OccurredAt  time.Time       `json:"occurred_at"`
	Payload     json.RawMessage `json:"payload"`
}

// LearningAssetSnapshot represents a learning asset for bootstrap
type LearningAssetSnapshot struct {
	ID          string     `json:"id"`
	Status      string     `json:"status"`
	Headword    string     `json:"headword"`
	Translation *string    `json:"translation,omitempty"`
	Definition  *string    `json:"definition,omitempty"`
	ReviewDueAt *time.Time `json:"review_due_at,omitempty"`
	ReviewCount int        `json:"review_count"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

// AssetConceptLinkSnapshot represents an asset-concept link for bootstrap
type AssetConceptLinkSnapshot struct {
	ID         string  `json:"id"`
	AssetID    string  `json:"asset_id"`
	ConceptID  string  `json:"concept_id"`
	LinkType   string  `json:"link_type"`
	Confidence float64 `json:"confidence"`
}

// ConceptSnapshot represents a knowledge node for bootstrap
type ConceptSnapshot struct {
	ID        string     `json:"id"`
	Name      string     `json:"name"`
	PositionX *float64   `json:"position_x,omitempty"`
	PositionY *float64   `json:"position_y,omitempty"`
	UpdatedAt time.Time  `json:"updated_at"`
}

// UserNodeStatusSnapshot represents user's node status for bootstrap
type UserNodeStatusSnapshot struct {
	NodeID       string     `json:"node_id"`
	MasteryScore float64    `json:"mastery_score"`
	Revision     int64      `json:"revision"`
	NextReviewAt *time.Time `json:"next_review_at,omitempty"`
}

// SnapshotData contains all data for bootstrap sync
type SnapshotData struct {
	Assets   []LearningAssetSnapshot    `json:"assets"`
	Links    []AssetConceptLinkSnapshot `json:"links"`
	Concepts []ConceptSnapshot          `json:"concepts"`
	Statuses []UserNodeStatusSnapshot   `json:"statuses"`
}

// SyncService handles multi-device sync operations
type SyncService struct {
	pool *pgxpool.Pool
}

// NewSyncService creates a new SyncService
func NewSyncService(pool *pgxpool.Pool) *SyncService {
	return &SyncService{pool: pool}
}

// GetBootstrapData returns initial state snapshot for a user
func (s *SyncService) GetBootstrapData(ctx context.Context, userID string) (*SnapshotData, string, error) {
	snapshot := &SnapshotData{
		Assets:   make([]LearningAssetSnapshot, 0),
		Links:    make([]AssetConceptLinkSnapshot, 0),
		Concepts: make([]ConceptSnapshot, 0),
		Statuses: make([]UserNodeStatusSnapshot, 0),
	}

	// 1. Fetch learning assets
	assets, err := s.fetchUserAssets(ctx, userID)
	if err != nil {
		return nil, "", fmt.Errorf("fetch assets: %w", err)
	}
	snapshot.Assets = assets

	// 2. Fetch asset-concept links
	links, err := s.fetchUserLinks(ctx, userID)
	if err != nil {
		return nil, "", fmt.Errorf("fetch links: %w", err)
	}
	snapshot.Links = links

	// 3. Fetch related concepts
	concepts, err := s.fetchRelatedConcepts(ctx, userID)
	if err != nil {
		return nil, "", fmt.Errorf("fetch concepts: %w", err)
	}
	snapshot.Concepts = concepts

	// 4. Fetch user node statuses
	statuses, err := s.fetchUserNodeStatuses(ctx, userID)
	if err != nil {
		return nil, "", fmt.Errorf("fetch statuses: %w", err)
	}
	snapshot.Statuses = statuses

	// 5. Get current cursor (max event ID)
	cursor, err := s.getCurrentCursor(ctx, userID)
	if err != nil {
		return nil, "", fmt.Errorf("get cursor: %w", err)
	}

	return snapshot, cursor, nil
}

// GetEvents returns incremental events since cursor
func (s *SyncService) GetEvents(ctx context.Context, userID, cursor string, limit int) ([]SyncEvent, string, bool, error) {
	// Validate limit
	if limit <= 0 {
		limit = 100
	}
	if limit > 500 {
		limit = 500
	}

	// Decode cursor
	afterID := int64(0)
	if cursor != "" {
		decoded, err := base64.StdEncoding.DecodeString(cursor)
		if err == nil {
			afterID, _ = strconv.ParseInt(string(decoded), 10, 64)
		}
	}

	// Query events
	// Filters events related to user's learning assets and concept links
	query := `
		SELECT
			e.id::text,
			e.aggregate_type || '.' || e.event_type as type,
			e.aggregate_id::text,
			e.sequence_number,
			e.created_at,
			e.payload
		FROM event_outbox e
		WHERE e.id > $1
		  AND (
		    -- Learning asset events for this user
		    (e.aggregate_type = 'learning_asset' AND e.payload->>'user_id' = $2)
		    -- Asset-concept link events for this user
		    OR (e.aggregate_type = 'asset_concept_link')
		    -- Knowledge node events (global)
		    OR (e.aggregate_type = 'knowledge_node')
		  )
		ORDER BY e.id ASC
		LIMIT $3
	`

	rows, err := s.pool.Query(ctx, query, afterID, userID, limit+1)
	if err != nil {
		return nil, "", false, fmt.Errorf("query events: %w", err)
	}
	defer rows.Close()

	var events []SyncEvent
	for rows.Next() {
		var e SyncEvent
		var payload []byte
		if err := rows.Scan(&e.ID, &e.Type, &e.AggregateID, &e.Sequence, &e.OccurredAt, &payload); err != nil {
			return nil, "", false, fmt.Errorf("scan event: %w", err)
		}
		e.Payload = truncatePayload(payload, MaxEventPayloadBytes)
		events = append(events, e)
	}

	if err := rows.Err(); err != nil {
		return nil, "", false, fmt.Errorf("rows error: %w", err)
	}

	// Check if there are more
	hasMore := len(events) > limit
	if hasMore {
		events = events[:limit]
	}

	// Generate next cursor
	nextCursor := ""
	if len(events) > 0 {
		lastID := events[len(events)-1].ID
		nextCursor = base64.StdEncoding.EncodeToString([]byte(lastID))
	}

	return events, nextCursor, hasMore, nil
}

// Private helper methods

func (s *SyncService) fetchUserAssets(ctx context.Context, userID string) ([]LearningAssetSnapshot, error) {
	query := `
		SELECT
			id::text, status, headword, translation, definition,
			review_due_at, review_count, updated_at
		FROM learning_assets
		WHERE user_id = $1 AND deleted_at IS NULL
		ORDER BY updated_at DESC
		LIMIT 1000
	`

	rows, err := s.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var assets []LearningAssetSnapshot
	for rows.Next() {
		var a LearningAssetSnapshot
		if err := rows.Scan(
			&a.ID, &a.Status, &a.Headword, &a.Translation, &a.Definition,
			&a.ReviewDueAt, &a.ReviewCount, &a.UpdatedAt,
		); err != nil {
			return nil, err
		}
		assets = append(assets, a)
	}

	return assets, rows.Err()
}

func (s *SyncService) fetchUserLinks(ctx context.Context, userID string) ([]AssetConceptLinkSnapshot, error) {
	query := `
		SELECT
			id::text, asset_id::text, concept_id::text, link_type, confidence
		FROM asset_concept_links
		WHERE user_id = $1 AND deleted_at IS NULL
		ORDER BY created_at DESC
		LIMIT 5000
	`

	rows, err := s.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var links []AssetConceptLinkSnapshot
	for rows.Next() {
		var l AssetConceptLinkSnapshot
		if err := rows.Scan(&l.ID, &l.AssetID, &l.ConceptID, &l.LinkType, &l.Confidence); err != nil {
			return nil, err
		}
		links = append(links, l)
	}

	return links, rows.Err()
}

func (s *SyncService) fetchRelatedConcepts(ctx context.Context, userID string) ([]ConceptSnapshot, error) {
	// Fetch concepts linked to user's assets
	query := `
		SELECT DISTINCT
			kn.id::text, kn.name, kn.position_x, kn.position_y, kn.updated_at
		FROM knowledge_nodes kn
		WHERE kn.deleted_at IS NULL
		  AND (
		    kn.id IN (
		      SELECT concept_id FROM asset_concept_links
		      WHERE user_id = $1 AND deleted_at IS NULL
		    )
		    OR kn.id IN (
		      SELECT node_id FROM user_node_status WHERE user_id = $1
		    )
		  )
		ORDER BY kn.updated_at DESC
		LIMIT 2000
	`

	rows, err := s.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var concepts []ConceptSnapshot
	for rows.Next() {
		var c ConceptSnapshot
		if err := rows.Scan(&c.ID, &c.Name, &c.PositionX, &c.PositionY, &c.UpdatedAt); err != nil {
			return nil, err
		}
		concepts = append(concepts, c)
	}

	return concepts, rows.Err()
}

func (s *SyncService) fetchUserNodeStatuses(ctx context.Context, userID string) ([]UserNodeStatusSnapshot, error) {
	query := `
		SELECT
			node_id::text, mastery_score, revision, next_review_at
		FROM user_node_status
		WHERE user_id = $1
		ORDER BY updated_at DESC
		LIMIT 2000
	`

	rows, err := s.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var statuses []UserNodeStatusSnapshot
	for rows.Next() {
		var st UserNodeStatusSnapshot
		if err := rows.Scan(&st.NodeID, &st.MasteryScore, &st.Revision, &st.NextReviewAt); err != nil {
			return nil, err
		}
		statuses = append(statuses, st)
	}

	return statuses, rows.Err()
}

func (s *SyncService) getCurrentCursor(ctx context.Context, userID string) (string, error) {
	// Get the max event ID as cursor
	var maxID int64
	err := s.pool.QueryRow(ctx, `
		SELECT COALESCE(MAX(id), 0) FROM event_outbox
	`).Scan(&maxID)
	if err != nil {
		return "", err
	}

	if maxID == 0 {
		return "", nil
	}

	return base64.StdEncoding.EncodeToString([]byte(strconv.FormatInt(maxID, 10))), nil
}

// truncatePayload ensures payload doesn't exceed max bytes
func truncatePayload(payload []byte, maxBytes int) json.RawMessage {
	if len(payload) <= maxBytes {
		return json.RawMessage(payload)
	}

	// Parse, truncate, re-serialize
	var data map[string]interface{}
	if err := json.Unmarshal(payload, &data); err != nil {
		return json.RawMessage(`{"truncated":true}`)
	}

	data["truncated"] = true
	data["original_size"] = len(payload)

	// Remove large fields until under limit
	result, _ := json.Marshal(data)
	for len(result) > maxBytes && len(data) > 2 {
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
			result, _ = json.Marshal(data)
		} else {
			break
		}
	}

	return json.RawMessage(result)
}
