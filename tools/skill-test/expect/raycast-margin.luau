-- expect: a ray 2 studs from a part misses below that margin, hits above it, and the result describes a sphere.
local target = Instance.new("Part")
target.Anchored = true
target.Size = Vector3.new(2, 2, 2)
target.Position = Vector3.new(3, 500, 50)
target.Parent = Workspace
local origin, direction = Vector3.new(0, 500, 0), Vector3.new(0, 0, 100)
local NONE: { Instance } = {}
__skilltest.eq("no margin misses", forgivingRaycast(origin, direction, 0, NONE), nil)
__skilltest.eq("a margin under the gap misses", forgivingRaycast(origin, direction, 1.9, NONE), nil)
local hit = forgivingRaycast(origin, direction, 2.1, NONE)
__skilltest.check("a margin over the gap hits the part", hit ~= nil and hit.Instance == target)
if hit then
	local toPosition = (hit.Position - origin).Magnitude
	__skilltest.check("Distance is the sphere's travel, shorter than origin to Position", hit.Distance < toPosition - 0.1, `{hit.Distance} vs {toPosition}`)
end
__skilltest.eq("an ignored part is not hit", forgivingRaycast(origin, direction, 2.1, { target }), nil)
__skilltest.check("a negative margin throws", not pcall(forgivingRaycast, origin, direction, -1, NONE))
__skilltest.check("a margin over 256 fails at the cast", not pcall(forgivingRaycast, origin, direction, 257, NONE))
target:Destroy()
