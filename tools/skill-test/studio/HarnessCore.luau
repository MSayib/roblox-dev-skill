--!strict
-- roblox-dev-skill Studio runtime reporter, shared by Harness.server.luau and
-- ClientHarness.client.luau (ReplicatedStorage.SkillTestHarnessCore).
--
-- It only reports: it records every runtime error raised by a case script during the window and
-- every "Infinite yield" warning, reads the expectation results the cases leave in
-- shared.SkillTestResults (tools/skill-test/expect/_lib.luau) for every case Rojo marked with a
-- SkillTestExpect attribute, then prints one line per failing case and a summary ending in
-- "[SKILLTEST] DONE <side>".
--
-- An "Infinite yield possible" warning only says WaitForChild waited 5 s. If the awaited child
-- exists when the window ends, the block went on (it is counted as `late`, e.g. a ScreenGui that
-- arrives with a slow first spawn); if it still does not, the block never ran to its end and
-- the case fails (`infinite-yield`).

local LogService = game:GetService("LogService")
local ScriptContext = game:GetService("ScriptContext")

local WINDOW_SECONDS = 25

return function(side: string, folders: { Instance })
	local errors: { [string]: string } = {}
	local yields: { [string]: string } = {}
	local lastYield: string? = nil

	local function caseOf(source: Instance?): string?
		if not source then
			return nil
		end
		for _, folder in folders do
			if source:IsDescendantOf(folder) then
				return source.Name
			end
		end
		return nil
	end

	ScriptContext.Error:Connect(function(message: string, _trace: string, source: Instance?)
		local case = caseOf(source)
		if case and not errors[case] then
			errors[case] = message
		end
	end)

	-- "Players.X.PlayerGui:WaitForChild(\"ShopGui\")" -> does that child exist now?
	local function arrived(warning: string): boolean
		local path, child = warning:match("on '([^']+):WaitForChild%(\"([^\"]+)\"")
		if not path or not child then
			return false
		end
		local node: Instance? = game
		for part in string.gmatch(path, "[^%.]+") do
			node = node and node:FindFirstChild(part)
		end
		return node ~= nil and node:FindFirstChild(child) ~= nil
	end

	-- The warning and the stack that names its script arrive as separate messages.
	LogService.MessageOut:Connect(function(message: string)
		if message:find("Infinite yield possible", 1, true) then
			lastYield = message
			return
		end
		local name = lastYield and message:match("SkillTest%a+%.([%w_%-]+)'")
		if name and lastYield then
			yields[name] = yields[name] or lastYield
			lastYield = nil
		end
	end)

	task.wait(WINDOW_SECONDS)

	local results = shared.SkillTestResults or {}
	local total, failed, errored, expectPass, expectFail, yielded, late = 0, 0, 0, 0, 0, 0, 0
	for _, folder in folders do
		for _, child in folder:GetChildren() do
			if not child:IsA("Script") then
				continue
			end
			total += 1
			local problem: string? = nil
			if errors[child.Name] then
				errored += 1
				problem = `runtime-error :: {errors[child.Name]}`
			end
			local yieldWarning = yields[child.Name]
			if yieldWarning and arrived(yieldWarning) then
				late += 1
				print(`[SKILLTEST] late {child.Name} :: {yieldWarning} (the child arrived later)`)
			elseif yieldWarning then
				yielded += 1
				problem = problem or `infinite-yield :: {yieldWarning}`
			end
			if child:GetAttribute("SkillTestExpect") then
				local r = results[child.Name]
				if r and r.fail == 0 and r.pass > 0 and r.done then
					expectPass += 1
				else
					expectFail += 1
					problem = problem
						or `expect-fail :: {if r then `pass={r.pass} fail={r.fail} done={r.done}` else "no result"}`
				end
			end
			if problem then
				failed += 1
				print(`[SKILLTEST] {problem:match("^[%w%-]+")} {child.Name} :: {problem:match("::%s*(.*)$")}`)
			end
		end
	end
	print(
		`[SKILLTEST] DONE {side} cases={total} ok={total - failed} runtime-error={errored} `
			.. `infinite-yield={yielded} late={late} expect-pass={expectPass} expect-fail={expectFail}`
	)
end
