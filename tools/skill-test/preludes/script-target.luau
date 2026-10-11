--@skilltest: plugin
-- prelude: a script to edit and the reader's transform (plugin level).
local target = Instance.new("Script")
target.Name = "SkillTestEditTarget"
target.Source = "print('before')"
target.Parent = game:GetService("ServerStorage")
local function transform(oldSource: string): string
	return (oldSource:gsub("before", "after"))
end
