-- expect: the pool is whole after acquire/release, and stays whole (2.16.0 fixed a leak here).
local pool = npcPool :: any
__skilltest.eq("released NPC is back in ServerStorage", npc.Parent, ServerStorage)
__skilltest.eq("pool back to 10 available", #pool.available, 10)
__skilltest.eq("nothing left in use", next(pool.inUse), nil)
for _ = 1, 6 do
	pool:release(pool:acquire())
end
__skilltest.eq("still 10 after six more cycles", #pool.available, 10)
local a, b = pool:acquire(), pool:acquire()
__skilltest.eq("two out, 8 left", #pool.available, 8)
pool:release(a)
pool:release(a)
__skilltest.eq("a second release of the same NPC is ignored", #pool.available, 9)
pool:release(b)
__skilltest.eq("back to 10", #pool.available, 10)
