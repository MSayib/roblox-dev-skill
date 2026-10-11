--@skilltest: prelude screen-gui
-- prelude: the Frames the UI snippets name, each in the reader's ScreenGui.
local function skilltestFrame(name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Parent = screenGui
	return f
end
local frame = skilltestFrame("frame")
local containerFrame = skilltestFrame("containerFrame")
local inventoryFrame = skilltestFrame("inventoryFrame")
local card = skilltestFrame("card")
-- myFrame is a child of a Frame that has a UIListLayout (the snippet's own comment).
local myFrame = Instance.new("Frame")
myFrame.Parent = containerFrame
Instance.new("UIListLayout").Parent = containerFrame
