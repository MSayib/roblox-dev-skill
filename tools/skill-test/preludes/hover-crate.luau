-- prelude: create HoverCrate (with unanchored Body) and MarginCheckpoint for Example 9.
local _ws = game:GetService("Workspace")
local _crate = Instance.new("Model")
_crate.Name = "HoverCrate"
local _body = Instance.new("Part")
_body.Name = "Body"
_body.Size = Vector3.new(4, 2, 4)
_body.Position = Vector3.new(0, 80, 0)
_body.Anchored = false
_body.CanCollide = false
_body.Parent = _crate
_crate.PrimaryPart = _body
_crate.Parent = _ws

local _checkpoint = Instance.new("Part")
_checkpoint.Name = "MarginCheckpoint"
_checkpoint.Size = Vector3.new(2, 1, 2)
_checkpoint.Position = Vector3.new(0, 78, 0)
_checkpoint.Anchored = true
_checkpoint.CanCollide = false
_checkpoint.Parent = _ws
