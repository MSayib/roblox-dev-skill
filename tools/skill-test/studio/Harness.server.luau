--!strict
-- roblox-dev-skill Studio runtime reporter.
--
-- Every complete server block of the skill is synced by Rojo (port 34871) as its own Script under
-- ServerScriptService.SkillTestServer, named after its case id, so it runs exactly as a developer
-- pasting it would: game-Script identity, real security and capability gates. (loadstring() was
-- tried first; it needs ServerScriptService.LoadStringEnabled, which is NotScriptable and is not
-- applied from a Rojo project.) Client blocks are LocalScripts under
-- StarterPlayerScripts.SkillTestClient; their errors are read from the console.
--
-- This Script only reports: it records every runtime error raised by a case script during the
-- window, then prints one line per failing case and a summary ending in "[SKILLTEST] DONE".

local ScriptContext = game:GetService("ScriptContext")
local ServerScriptService = game:GetService("ServerScriptService")

local WINDOW_SECONDS = 20

-- SkillTestActor is an Actor holding the blocks that must run under one (Parallel Luau).
local folders = { ServerScriptService:WaitForChild("SkillTestServer"), ServerScriptService:WaitForChild("SkillTestActor") }
local errors: { [string]: string } = {}

ScriptContext.Error:Connect(function(message: string, _trace: string, source: Instance?)
	if not source or errors[source.Name] then
		return
	end
	for _, folder in folders do
		if source:IsDescendantOf(folder) then
			errors[source.Name] = message
		end
	end
end)

task.wait(WINDOW_SECONDS)

local total, failed = 0, 0
for _, folder in folders do
	for _, child in folder:GetChildren() do
		if child:IsA("Script") then
			total += 1
			local message = errors[child.Name]
			if message then
				failed += 1
				print(`[SKILLTEST] runtime-error {child.Name} :: {message}`)
			end
		end
	end
end
print(`[SKILLTEST] DONE server cases={total} ok={total - failed} runtime-error={failed}`)
