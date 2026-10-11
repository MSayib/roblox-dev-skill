--@skilltest: plugin
-- prelude: a decorative MeshPart in the place, tagged as the snippet expects.
local decorative = Instance.new("MeshPart")
decorative.Name = "SkillTestDecorative"
decorative.Anchored = true
decorative:AddTag("Decorative")
decorative.Parent = workspace
