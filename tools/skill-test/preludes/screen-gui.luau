--@skilltest: prelude local-player
-- prelude: the reader's ScreenGui in PlayerGui.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkillTestGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")
