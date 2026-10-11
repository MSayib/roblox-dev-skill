--@skilltest: prelude screen-gui
-- prelude: a ScreenGui that has a HUDFrame, as the reader built it in Studio.
local hudFrame = Instance.new("Frame")
hudFrame.Name = "HUDFrame"
hudFrame.Parent = screenGui
local screenGui = screenGui :: ScreenGui & { HUDFrame: Frame }
