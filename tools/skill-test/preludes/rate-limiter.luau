-- prelude: the reader's TokenBucket instance (the module shown earlier on the page).
local rateLimiter = { buckets = {} :: { [number]: any } }
