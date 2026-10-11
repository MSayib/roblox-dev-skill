--@skilltest: prelude screen-gui
-- prelude: a button and the reader's two handlers.
local RunService = game:GetService("RunService")
local button = Instance.new("TextButton")
button.Parent = screenGui
local activations, heartbeats = 0, 0
local function onActivated()
	activations += 1
end
local function onHeartbeat(_dt: number)
	heartbeats += 1
end
