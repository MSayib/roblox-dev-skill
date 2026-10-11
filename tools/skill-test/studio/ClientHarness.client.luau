--!strict
-- roblox-dev-skill Studio runtime reporter (client side): the client blocks are LocalScripts under
-- StarterPlayerScripts.SkillTestClient, copied into the player's PlayerScripts at join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local report = require(ReplicatedStorage:WaitForChild("SkillTestHarnessCore") :: ModuleScript) :: (string, { Instance }) -> ()
report("client", { playerScripts:WaitForChild("SkillTestClient") })
