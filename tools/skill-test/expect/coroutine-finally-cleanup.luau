-- expect: task.cancel on the pulse thread runs the finally callback, which destroys the Highlight.
__skilltest.eq("Highlight gone after task.cancel", part:FindFirstChildOfClass("Highlight"), nil)
__skilltest.eq("thread is dead", coroutine.status(pulse), "dead")
local co = coroutine.create(function() return 1 end)
local seen = {}
coroutine.finally(co, function(status: string) table.insert(seen, "first:" .. status) end)
coroutine.finally(co, function(status: string) table.insert(seen, "second:" .. status) end)
coroutine.resume(co)
__skilltest.eq("callbacks run LIFO", table.concat(seen, ","), "second:finished,first:finished")
part:Destroy()
