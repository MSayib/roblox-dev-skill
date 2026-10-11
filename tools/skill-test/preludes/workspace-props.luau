-- prelude: the Workspace objects the snippets name (an NPC with a Head, a TV screen, a chest),
-- as the reader's place has them.
local function skilltestProp(name: string, head: boolean)
	if workspace:FindFirstChild(name) then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.Position = Vector3.new(#name * 4, 3, 20)
	if head then
		local model = Instance.new("Model")
		model.Name = name
		part.Name = "Head"
		part.Parent = model
		model.Parent = workspace
	else
		part.Name = name
		part.Parent = workspace
	end
end
skilltestProp("SomeNPC", true)
skilltestProp("TVScreen", false)
skilltestProp("TreasureChest", false)
