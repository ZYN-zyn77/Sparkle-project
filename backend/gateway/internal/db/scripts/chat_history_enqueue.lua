-- Atomically enqueue chat history if the queue is below the threshold.
-- KEYS[1]: queue key
-- ARGV[1]: threshold
-- ARGV[2]: message payload

local current = redis.call('LLEN', KEYS[1])
local threshold = tonumber(ARGV[1])
if current < threshold then
  redis.call('RPUSH', KEYS[1], ARGV[2])
  return 1
end

return 0
