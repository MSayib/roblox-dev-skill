-- Runs the plugin-level cases (ServerStorage.SkillTestPluginCases, from build_suite.py) at plugin
-- level, where they belong: paste this file into MCP execute_luau on the Edit datamodel (or the
-- command bar). A game Script cannot run them; their security level is the point.
-- Expectation results come back through shared.SkillTestPluginResult (expect/_lib.luau).
-- Returns one line per failing case and a summary line "[SKILLTEST] DONE plugin ...".
local cases = require(game:GetService("ServerStorage"):WaitForChild("SkillTestPluginCases") :: ModuleScript) :: { any }

local lines: { string } = {}
local total, failed, expectPass, expectFail = 0, 0, 0, 0
for _, case in cases do
	total += 1
	shared.SkillTestPluginResult = nil
	local fn, compileError = loadstring(case.src, "=" .. case.id)
	local ok, err = false, compileError
	if fn then
		ok, err = pcall(fn)
	end
	local result = shared.SkillTestPluginResult
	local problem: string? = nil
	if not ok then
		problem = `runtime-error :: {err}`
	elseif case.expect then
		if result and result.fail == 0 and result.pass > 0 and result.done then
			expectPass += 1
		else
			expectFail += 1
			problem = `expect-fail :: {if result then `pass={result.pass} fail={result.fail} done={result.done}` else "no result"}`
		end
	end
	if problem then
		failed += 1
		table.insert(lines, `[SKILLTEST] {case.id} {problem}`)
	end
end
shared.SkillTestPluginResult = nil
table.insert(lines, `[SKILLTEST] DONE plugin cases={total} ok={total - failed} expect-pass={expectPass} expect-fail={expectFail}`)
return table.concat(lines, "\n")
