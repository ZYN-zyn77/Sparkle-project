package service

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
)

func TestGetUserContextDataTimeout(t *testing.T) {
	service := &UserContextService{
		contextTimeout: 500 * time.Millisecond,
	}
	userID := uuid.New()

	slowFetcher := func(ctx context.Context) error {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(1100 * time.Millisecond):
			return nil
		}
	}

	service.fetchPending = func(ctx context.Context, _ uuid.UUID, _ int32) ([]TaskSummary, error) {
		return []TaskSummary{}, slowFetcher(ctx)
	}
	service.fetchPlans = func(ctx context.Context, _ uuid.UUID, _ int32) ([]PlanSummary, error) {
		return []PlanSummary{}, nil
	}
	service.fetchStats = func(ctx context.Context, _ uuid.UUID) (FocusStatsSummary, error) {
		return FocusStatsSummary{}, slowFetcher(ctx)
	}
	service.fetchProgress = func(ctx context.Context, _ uuid.UUID, _ int) ([]ProgressEvent, error) {
		return []ProgressEvent{}, nil
	}

	start := time.Now()
	data, err := service.GetUserContextData(context.Background(), userID)
	elapsed := time.Since(start)

	require.Error(t, err)
	require.ErrorIs(t, err, context.DeadlineExceeded)
	require.Empty(t, data)
	require.GreaterOrEqual(t, elapsed, 450*time.Millisecond)
	require.Less(t, elapsed, 900*time.Millisecond)
}
