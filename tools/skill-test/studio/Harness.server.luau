--!strict
-- roblox-dev-skill Studio runtime reporter (server side).
--
-- Every complete server block of the skill is synced by Rojo (port 34871) as its own Script under
-- ServerScriptService.SkillTestServer, named after its case id, so it runs exactly as a developer
-- pasting it would: game-Script identity, real security and capability gates. (loadstring() was
-- tried first; it needs ServerScriptService.LoadStringEnabled, which is NotScriptable and is not
-- applied from a Rojo project.) SkillTestActor is an Actor holding the blocks that must run under
-- one (Parallel Luau). The reporting is in HarnessCore.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local report = require(ReplicatedStorage:WaitForChild("SkillTestHarnessCore") :: ModuleScript) :: (string, { Instance }) -> ()
report("server", { ServerScriptService:WaitForChild("SkillTestServer"), ServerScriptService:WaitForChild("SkillTestActor") })
