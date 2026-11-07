-- expect: a part joins, OnAdded runs, and it leaves when the tag goes. Run in Studio 0.746.0.7461269.
local brick = Instance.new("Part")
brick.Anchored = true
brick.Position = Vector3.new(8000, 500, 0)
brick:AddTag("KillBrick")
brick.Parent = workspace
task.wait(0.3)
__skilltest.eq("OnAdded ran for a part tagged later", brick.Material, Enum.Material.Neon)
__skilltest.eq("the part is a member", killBricks:GetCount(), 1)
brick:RemoveTag("KillBrick")
task.wait(0.3)
__skilltest.eq("it left when the tag went", killBricks:GetCount(), 0)
brick:Destroy()
killBricks:Destroy()
