-- expect: 10 per 5 s allows 10 at once, refuses the 11th, refills over time, per user.
local limiter = skilltestModule.new(10, 5)
local allowed = 0
for _ = 1, 10 do
	if limiter:allow(1) then
		allowed += 1
	end
end
__skilltest.eq("10 allowed at once", allowed, 10)
__skilltest.eq("11th refused", limiter:allow(1), false)
__skilltest.eq("another user has a full bucket", limiter:allow(2), true)
local t0, c0 = time(), os.clock()
task.wait(0.7)
local gameAdvance, wallAdvance = time() - t0, os.clock() - c0
print(`[SKILLTEST] token-bucket: time() advanced {gameAdvance} s while os.clock() advanced {wallAdvance} s`)
__skilltest.eq("refilled after 0.7 s (2 tokens/s)", limiter:allow(1), true)
__skilltest.check("bad config refused", not pcall(skilltestModule.new, 0, 5))
