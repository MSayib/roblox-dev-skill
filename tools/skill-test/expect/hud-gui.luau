-- expect: the ScreenGui is in PlayerGui with the documented settings.
__skilltest.eq("in PlayerGui", screenGui.Parent, player:FindFirstChildOfClass("PlayerGui"))
__skilltest.eq("IgnoreGuiInset", screenGui.IgnoreGuiInset, true)
__skilltest.eq("ResetOnSpawn", screenGui.ResetOnSpawn, false)
