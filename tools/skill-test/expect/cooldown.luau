-- expect: the first action passes, a second within the cooldown is refused, after it passes again.
local who = {} :: any
__skilltest.eq("first action allowed", isOnCooldown(who), false)
__skilltest.eq("immediate second refused", isOnCooldown(who), true)
task.wait(COOLDOWN_SECONDS + 0.1)
__skilltest.eq("allowed again after the cooldown", isOnCooldown(who), false)
