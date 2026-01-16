package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/sparkle/gateway/internal/service"
)

// SyncHandler handles sync API requests
type SyncHandler struct {
	syncService *service.SyncService
}

// NewSyncHandler creates a new SyncHandler
func NewSyncHandler(syncService *service.SyncService) *SyncHandler {
	return &SyncHandler{syncService: syncService}
}

// Bootstrap returns initial state snapshot for a new device
// GET /api/v1/sync/bootstrap
func (h *SyncHandler) Bootstrap(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user_id not found in context"})
		return
	}

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

// GetEvents returns incremental events since cursor
// GET /api/v1/sync/events?cursor=xxx&limit=100
func (h *SyncHandler) GetEvents(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user_id not found in context"})
		return
	}

	cursor := c.Query("cursor")
	limitStr := c.DefaultQuery("limit", "100")
	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		limit = 100
	}

	events, nextCursor, hasMore, err := h.syncService.GetEvents(
		c.Request.Context(), userID, cursor, limit,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"events":      events,
		"next_cursor": nextCursor,
		"has_more":    hasMore,
	})
}

// RegisterRoutes registers sync routes
func (h *SyncHandler) RegisterRoutes(rg *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	sync := rg.Group("/sync")
	sync.Use(authMiddleware)
	{
		sync.GET("/bootstrap", h.Bootstrap)
		sync.GET("/events", h.GetEvents)
	}
}
