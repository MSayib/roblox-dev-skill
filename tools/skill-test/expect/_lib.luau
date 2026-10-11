-- skilltest expectation helpers (prepended by tools/skill-test/compose.py; not part of the skill).
-- Results go to the console and to shared.SkillTestResults[<case>] = { pass, fail, done }, which
-- the harness reads (a plugin-level case has no script: shared.SkillTestPluginResult, read by
-- run_plugin_cases.luau). Not attributes on the case script: in a Studio playtest they were
-- written, then found cleared on the original scripts after the run (2026-10-11; a clone of the
-- same script kept them; cause not established), so the harness must not depend on them.
local __skilltest = (function()
	local host: Instance? = if typeof(script) == "Instance" then script else nil
	local case = if host then host.Name else "plugin-case"
	local passed, failed = 0, 0
	local result = { pass = 0, fail = 0, done = false }
	if host then
		shared.SkillTestResults = shared.SkillTestResults or {}
		shared.SkillTestResults[case] = result
	else
		shared.SkillTestPluginResult = result
	end
	local lib = {}
	function lib.check(label: string, ok: boolean, detail: string?)
		if ok then
			passed += 1
			print(`[SKILLTEST] PASS {case} :: {label}`)
		else
			failed += 1
			warn(`[SKILLTEST] FAIL {case} :: {label}{if detail then " :: " .. detail else ""}`)
		end
		result.pass, result.fail = passed, failed
	end
	function lib.eq(label: string, actual: any, expected: any)
		lib.check(label, actual == expected, `got {tostring(actual)}, want {tostring(expected)}`)
	end
	function lib.done()
		result.done = true
		print(`[SKILLTEST] EXPECT-DONE {case} pass={passed} fail={failed}`)
	end
	return lib
end)()
