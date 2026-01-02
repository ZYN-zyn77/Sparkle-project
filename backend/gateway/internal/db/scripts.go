package db

import (
	_ "embed"
)

//go:embed scripts/decr_quota.lua
var DecrQuotaScript string

//go:embed scripts/chat_history_enqueue.lua
var ChatHistoryEnqueueScript string
