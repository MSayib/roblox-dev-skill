-- expect: the cleanup loop disconnected everything.
__skilltest.eq("two connections tracked", #connections, 2)
for i, conn in connections do
	__skilltest.eq(`connection {i} disconnected`, conn.Connected, false)
end
