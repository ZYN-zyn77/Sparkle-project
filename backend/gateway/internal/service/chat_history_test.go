package service

import (
	"context"
	"fmt"
	"sync"
	"testing"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/require"
)

func TestSaveMessageRespectsBreakerAtomically(t *testing.T) {
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})

	svc := NewChatHistoryService(rdb)
	svc.SetBreakerThreshold(10)

	ctx := context.Background()
	var wg sync.WaitGroup
	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			msg := []byte(fmt.Sprintf("msg-%d", i))
			if err := svc.SaveMessage(ctx, "sid", msg); err != nil {
				t.Errorf("save message failed: %v", err)
			}
		}(i)
	}
	wg.Wait()

	length, err := rdb.LLen(ctx, "queue:persist:history").Result()
	require.NoError(t, err)
	require.LessOrEqual(t, length, int64(10))
	require.Greater(t, svc.GetDroppedDueToBreaker(), int64(0))
}
