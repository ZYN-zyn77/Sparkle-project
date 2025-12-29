package service

import (
	"context"
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestChatHistoryKeysAreUserScoped(t *testing.T) {
	tr := setupRedis(t)
	defer tr.cleanup(t)

	service := NewChatHistoryService(tr.client)
	ctx := context.Background()

	sessionID := "shared-session"
	userA := "user-a"
	userB := "user-b"

	err := service.SaveMessage(ctx, userA, sessionID, []byte("hello-from-a"))
	require.NoError(t, err)

	err = service.SaveMessage(ctx, userB, sessionID, []byte("hello-from-b"))
	require.NoError(t, err)

	cacheKeyA := fmt.Sprintf("chat:history:%s:%s", userA, sessionID)
	cacheKeyB := fmt.Sprintf("chat:history:%s:%s", userB, sessionID)

	historyA, err := tr.client.LRange(ctx, cacheKeyA, 0, -1).Result()
	require.NoError(t, err)
	historyB, err := tr.client.LRange(ctx, cacheKeyB, 0, -1).Result()
	require.NoError(t, err)

	assert.Equal(t, []string{"hello-from-a"}, historyA)
	assert.Equal(t, []string{"hello-from-b"}, historyB)

	queueKeyA := fmt.Sprintf("queue:persist:history:%s:%s", userA, sessionID)
	queueKeyB := fmt.Sprintf("queue:persist:history:%s:%s", userB, sessionID)

	queueA, err := tr.client.LRange(ctx, queueKeyA, 0, -1).Result()
	require.NoError(t, err)
	queueB, err := tr.client.LRange(ctx, queueKeyB, 0, -1).Result()
	require.NoError(t, err)

	assert.Equal(t, []string{"hello-from-a"}, queueA)
	assert.Equal(t, []string{"hello-from-b"}, queueB)
}

func TestSessionOwnerValidationBlocksHijack(t *testing.T) {
	tr := setupRedis(t)
	defer tr.cleanup(t)

	service := NewChatHistoryService(tr.client)
	ctx := context.Background()

	sessionID := "protected-session"
	ownerID := "user-owner"
	attackerID := "user-attacker"

	allowed, err := service.EnsureSessionOwner(ctx, ownerID, sessionID)
	require.NoError(t, err)
	require.True(t, allowed)

	err = service.SaveMessage(ctx, ownerID, sessionID, []byte("owner-message"))
	require.NoError(t, err)

	allowed, err = service.EnsureSessionOwner(ctx, attackerID, sessionID)
	require.NoError(t, err)
	require.False(t, allowed)

	owner, err := tr.client.Get(ctx, fmt.Sprintf("session:owner:%s", sessionID)).Result()
	require.NoError(t, err)
	assert.Equal(t, ownerID, owner)

	cacheKeyOwner := fmt.Sprintf("chat:history:%s:%s", ownerID, sessionID)
	cacheKeyAttacker := fmt.Sprintf("chat:history:%s:%s", attackerID, sessionID)

	ownerHistory, err := tr.client.LRange(ctx, cacheKeyOwner, 0, -1).Result()
	require.NoError(t, err)
	attackerHistory, err := tr.client.LRange(ctx, cacheKeyAttacker, 0, -1).Result()
	require.NoError(t, err)

	assert.Equal(t, []string{"owner-message"}, ownerHistory)
	assert.Empty(t, attackerHistory)

	queueKeyOwner := fmt.Sprintf("queue:persist:history:%s:%s", ownerID, sessionID)
	queueKeyAttacker := fmt.Sprintf("queue:persist:history:%s:%s", attackerID, sessionID)

	queueOwner, err := tr.client.LRange(ctx, queueKeyOwner, 0, -1).Result()
	require.NoError(t, err)
	queueAttacker, err := tr.client.LRange(ctx, queueKeyAttacker, 0, -1).Result()
	require.NoError(t, err)

	assert.Equal(t, []string{"owner-message"}, queueOwner)
	assert.Empty(t, queueAttacker)
}
