package service

import (
	"context"
	"fmt"
	"log"
	"sync/atomic"
	"time"

	"github.com/redis/go-redis/v9"
)

const (
	DefaultMaxQueueSize = 10000
	ChatHistoryTTL      = 30 * time.Minute
	ChatQueueTTL        = 2 * time.Hour
	SessionOwnerTTL     = 24 * time.Hour
)

type ChatHistoryService struct {
	rdb              *redis.Client
	breakerThreshold atomic.Int64
}

func NewChatHistoryService(rdb *redis.Client) *ChatHistoryService {
	s := &ChatHistoryService{rdb: rdb}
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
func (s *ChatHistoryService) GetQueueLength(ctx context.Context, userID, sid string) (int64, error) {
	if userID != "" && sid != "" {
		return s.rdb.LLen(ctx, historyQueueKey(userID, sid)).Result()
	}

	var total int64
	iter := s.rdb.Scan(ctx, 0, fmt.Sprintf("%s:*", historyQueuePrefix()), 0).Iterator()
	for iter.Next(ctx) {
		length, err := s.rdb.LLen(ctx, iter.Val()).Result()
		if err != nil {
			return 0, err
		}
		total += length
	}
	if err := iter.Err(); err != nil {
		return 0, err
	}

	legacyLen, err := s.rdb.LLen(ctx, historyQueuePrefix()).Result()
	if err != nil && err != redis.Nil {
		return 0, err
	}
	return total + legacyLen, nil
}

func (s *ChatHistoryService) SaveMessage(ctx context.Context, userID, sid string, msg []byte) error {
	pipe := s.rdb.Pipeline()

	// 1. Write to cache (for AI context, with TTL)
	cacheKey := historyCacheKey(userID, sid)
	pipe.RPush(ctx, cacheKey, msg)
	pipe.LTrim(ctx, cacheKey, -20, -1) // Keep last 20 messages
	pipe.Expire(ctx, cacheKey, ChatHistoryTTL)

	// 2. Write to persistent queue (for DB, with Circuit Breaker)
	queueKey := historyQueueKey(userID, sid)

	// Check queue length (Circuit Breaker)
	// We do this check outside the pipeline for simplicity, acknowledging the small race condition.
	// For strict atomicity, a Lua script could be used, but this is sufficient for OOM protection.
	qLen, err := s.rdb.LLen(ctx, queueKey).Result()
	if err != nil {
		// If Redis is reachable but LLEN fails, it's risky.
		// If Redis is unreachable, pipeline exec will fail anyway.
		log.Printf("Failed to check queue length: %v", err)
		return err
	}

	threshold := s.breakerThreshold.Load()
	if qLen < threshold {
		pipe.RPush(ctx, queueKey, msg)
		pipe.Expire(ctx, queueKey, ChatQueueTTL)
	} else {
		// Circuit Breaker triggered
		log.Printf("Persistence queue overloaded (%d/%d), dropping message for session %s", qLen, threshold, sid)
		// We execute the pipeline (to save to cache) but skip the DB queue push.
	}

	_, err = pipe.Exec(ctx)
	return err
}

func (s *ChatHistoryService) EnsureSessionOwner(ctx context.Context, userID, sid string) (bool, error) {
	ownerKey := sessionOwnerKey(sid)

	claimed, err := s.rdb.SetNX(ctx, ownerKey, userID, SessionOwnerTTL).Result()
	if err != nil {
		return false, err
	}
	if claimed {
		return true, nil
	}

	owner, err := s.rdb.Get(ctx, ownerKey).Result()
	if err != nil {
		if err == redis.Nil {
			// Try to establish ownership again if key expired between operations
			claimed, err = s.rdb.SetNX(ctx, ownerKey, userID, SessionOwnerTTL).Result()
			if err != nil {
				return false, err
			}
			return claimed, nil
		}
		return false, err
	}

	if owner != userID {
		return false, nil
	}

	// Refresh TTL on valid reuse
	if _, err := s.rdb.Expire(ctx, ownerKey, SessionOwnerTTL).Result(); err != nil {
		return false, err
	}

	return true, nil
}

func historyCacheKey(userID, sid string) string {
	return fmt.Sprintf("chat:history:%s:%s", userID, sid)
}

func historyQueuePrefix() string {
	return "queue:persist:history"
}

func historyQueueKey(userID, sid string) string {
	return fmt.Sprintf("%s:%s:%s", historyQueuePrefix(), userID, sid)
}

func sessionOwnerKey(sid string) string {
	return fmt.Sprintf("session:owner:%s", sid)
}
