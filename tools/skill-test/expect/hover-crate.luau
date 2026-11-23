-- expect: AlignPosition lifts HoverCrate vertically, thin ray misses, thick Margin=2.0 hits.
task.wait(0.35)
local minYAttr = ServerStorage:GetAttribute("HoverMinY") :: number?
local maxYAttr = ServerStorage:GetAttribute("HoverMaxY") :: number?
__skilltest.check("hover crate moved vertically", minYAttr ~= nil and maxYAttr ~= nil and maxYAttr > minYAttr, `{tostring(minYAttr)} -> {tostring(maxYAttr)}`)
__skilltest.eq("thin raycast misses offset checkpoint", ServerStorage:GetAttribute("ThinHits"), 0)
local thickAttr = ServerStorage:GetAttribute("ThickHits") :: number?
__skilltest.check("thick Margin=2.0 raycast hits offset checkpoint", thickAttr ~= nil and thickAttr > 0, tostring(thickAttr))
crate:Destroy()
checkpoint:Destroy()
ServerStorage:SetAttribute("HoverMinY", nil)
ServerStorage:SetAttribute("HoverMaxY", nil)
ServerStorage:SetAttribute("ThinHits", nil)
ServerStorage:SetAttribute("ThickHits", nil)
ServerStorage:SetAttribute("PlayerTriggered", nil)
