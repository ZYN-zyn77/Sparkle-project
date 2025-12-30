package service

import (
	"context"
	"log"
	"sync/atomic"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/sparkle/gateway/internal/db"
)

const (
	DefaultMaxQueueSize = 10000
	ChatHistoryTTL      = 30 * time.Minute
)

type ChatHistoryService struct {
	rdb                 *redis.Client
	breakerThreshold    atomic.Int64
	enqueueScript       *redis.Script
	droppedDueToBreaker atomic.Int64
}

func NewChatHistoryService(rdb *redis.Client) *ChatHistoryService {
	s := &ChatHistoryService{
		rdb:           rdb,
		enqueueScript: redis.NewScript(db.ChatHistoryEnqueueScript),
	}
	s.breakerThreshold.Store(DefaultMaxQueueSize)
	return s
}

// SetBreakerThreshold updates the circuit breaker limit dynamically
func (s *ChatHistoryService) SetBreakerThreshold(val int64) {
	s.breakerThreshold.Store(val)
}

// GetBreakerThreshold returns the current limit
func (s *ChatHistoryService) GetBreakerThreshold() int64 {
	return s.breakerThreshold.Load()
}

// GetQueueLength returns the current persistent queue size
func (s *ChatHistoryService) GetQueueLength(ctx context.Context) (int64, error) {
	return s.rdb.LLen(ctx, "queue:persist:history").Result()
}

func (s *ChatHistoryService) GetDroppedDueToBreaker() int64 {
	return s.droppedDueToBreaker.Load()
}

func (s *ChatHistoryService) SaveMessage(ctx context.Context, sid string, msg []byte) error {
	pipe := s.rdb.Pipeline()

	// 1. Write to cache (for AI context, with TTL)
	cacheKey := "chat:history:" + sid
	pipe.RPush(ctx, cacheKey, msg)
	pipe.LTrim(ctx, cacheKey, -20, -1) // Keep last 20 messages
	pipe.Expire(ctx, cacheKey, ChatHistoryTTL)

	// 2. Write to persistent queue (for DB, with Circuit Breaker)
	queueKey := "queue:persist:history"

	// Execute cache writes regardless of breaker status
	if _, err := pipe.Exec(ctx); err != nil {
		return err
	}

	threshold := s.breakerThreshold.Load()
	result, err := s.enqueueScript.Run(ctx, s.rdb, []string{queueKey}, threshold, msg).Int()
	if err != nil {
		log.Printf("Failed to enqueue chat history message: %v", err)
		return err
	}

	if result == 0 {
		dropped := s.droppedDueToBreaker.Add(1)
		log.Printf("Persistence queue overloaded (threshold=%d), dropping message for session %s (drop_count=%d)", threshold, sid, dropped)
	}

	return nil
}
