# Worked Examples — end-to-end patterns for an agent

> Every other reference in this skill answers *"what is true about Roblox?"*. This one answers
> *"what do I actually do, in order, and how do I know it worked?"*

Each example carries four things, and the middle two exist to stop an agent pattern-matching a
sample onto a task it does not fit:

| Section | Purpose |
|---|---|
| **Trigger** | When this example applies |
| **Not this** | Requests that look similar and route elsewhere — read this before matching |
| **Sequence** | The real calls, with real signatures |
| **Verification** | How you know it worked. A sample that stops at "code written" is not done |

**Two rules that apply to every example below.**

1. **Do not stop at generated code.** Every example ends in a verification step. If MCP is not
   connected, hand the user the verification steps instead of skipping them.
2. **Read the routing table in `SKILL.md` first.** These examples show sequence, not facts. Where an
   example and a reference file disagree, the reference file wins.

---

## 1. Add a server-authoritative feature

**Trigger:** "add coins / XP / an inventory / a shop", "let the player buy X", "reward the player
for Y" — anything where the client must *cause* a change to persistent or shared state.

**Not this:**
- Purely cosmetic client feedback (a sound, a particle, a tween on the local player's UI) — no
  server round-trip is needed; over-engineering it is its own failure. → `ui-systems.md`
- Robux purchases → `monetization.md`, not a custom RemoteEvent
- Saving the result → `datastore-persistence.md` for session locking, which this example omits

**Routing:** `networking.md` + `security-hardening.md`, then `datastore-persistence.md` if it
persists.

**Sequence:**

1. **Decide where authority lives before writing anything.** The client sends *intent*, never
   outcome. `CollectCoin(coinId)` is intent; `AddCoins(50)` is an outcome and is exploitable by
   definition. If the request is phrased as the latter, re-shape it and say why.
2. Write the server handler with **every** validation layer from `security-hardening.md` §2–3 —
   type, NaN/inf, range, ownership, state, and rate limit. They are not optional and not
   independent: a range check alone is defeated by NaN.
3. Write the client caller last. It is the untrusted half; it holds no rules.

```luau
--!strict
-- ServerScriptService/CoinService.server.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local collectRemote = ReplicatedStorage:WaitForChild("CollectCoin") :: RemoteEvent
local coinFolder = workspace:WaitForChild("Coins")

local COOLDOWN_SECONDS = 0.25
local MAX_REACH_STUDS = 12

local lastCollect: { [Player]: number } = {}
local coinValues: { [Player]: number } = {}

local function isFiniteNumber(value: unknown): boolean
	if typeof(value) ~= "number" then
		return false
	end
	local n = value :: number
	return n == n and math.abs(n) ~= math.huge -- rejects NaN and ±inf
end

collectRemote.OnServerEvent:Connect(function(player: Player, coin: unknown)
	-- 1. rate limit, before any work
	local now = os.clock()
	if now - (lastCollect[player] or 0) < COOLDOWN_SECONDS then
		return
	end
	lastCollect[player] = now

	-- 2. the argument is an Instance, and one we actually own
	if typeof(coin) ~= "Instance" then
		return
	end
	local part = coin :: Instance
	if not part:IsDescendantOf(coinFolder) or not part:IsA("BasePart") then
		return
	end

	-- 3. the player is actually near it — never trust a client-reported position
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local distance = (root.Position - (part :: BasePart).Position).Magnitude
	if not isFiniteNumber(distance) or distance > MAX_REACH_STUDS then
		return
	end

	-- 4. state validation: claim the coin exactly once
	if part:GetAttribute("Claimed") == true then
		return
	end
	part:SetAttribute("Claimed", true)

	coinValues[player] = (coinValues[player] or 0) + 1
	part:Destroy()
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastCollect[player] = nil
	coinValues[player] = nil -- persist before clearing in real code; see datastore-persistence.md
end)
```

**Verification:**

```text
1. get_studio_state                      → confirm Edit is available
2. multi_edit                            → write the script (Edit datamodel, one script per call)
3. get_console_output                    → catch load/syntax errors BEFORE playing
4. start_stop_play                       → begin playtest
5. execute_luau (datamodel_type: Server) → fire the remote with junk and assert it is rejected
6. get_console_output                     → no errors, and no coin awarded
7. start_stop_play                        → stop
```

Step 5 is the one agents skip. Proving the happy path works is half a test; the handler exists to
reject the unhappy path. Fire `NaN`, a `Part` from outside `coinFolder`, and 50 calls in a loop, and
assert the count did not move.

---

## 2. Debug a runtime error through MCP

**Trigger:** "this errors", "it stopped working", a pasted stack trace.

**Not this:**
- "This is slow" → `performance-optimization.md`; a profiling problem, not a debugging one
- "Type checking complains" → `luau-fundamentals.md`; static, no playtest needed. After a Studio
  update, check whether Luau 0.739's stricter in-body generic checking is the cause
- "It works in Studio but not in the live game" → suspect `StreamingEnabled` or a client/server
  assumption, not a syntax bug

**Routing:** `mcp-integration.md` for signatures, `agent-safety.md` before the first write.

**Sequence:**

```text
1. list_roblox_studios   → resolve studio_id, and say out loud which place it is
2. get_console_output    → read the actual error and stack trace, do not guess from the description
3. script_read           → read the offending script; line numbers here are real
4. execute_luau          → inspect live state (datamodel_type: Server or Client)
5. start_stop_play       → STOP the playtest — multi_edit cannot write during one
6. multi_edit            → apply the fix (datamodel_type: Edit only)
7. start_stop_play       → restart
8. get_console_output    → confirm the error is gone AND no new warnings appeared
```

**Failure modes, with the real cause:**

| What you see | Cause |
|---|---|
| `multi_edit` fails during a playtest | Its `datamodel_type` enum is `Edit` only. Step 5 is mandatory |
| `multi_edit` fails with no match | `old_string` must match **exactly**, whitespace included. You skipped `script_read` |
| The fix lands in the wrong place | A stale `studio_id`. Nothing warns you |
| `script_grep` line numbers do not match | Known defect. Use it to find *which* script, then `script_read` for *where* |

**Verification:** step 8 is not "no error". It is *no error and no new warning* — a deprecation
notice introduced by your fix is a future break.

---

## 3. Migrate a deprecated API

**Trigger:** "modernize this", "remove deprecated calls", a deprecation warning in the console.

**Not this:**
- A wholesale rewrite. `legacy-migration.md` has a "When NOT to Migrate" section for a reason:
  working code with no deprecation warning is not a migration target
- `UserInputService` → IAS. Neither `UserInputService` nor `ContextActionService` is deprecated;
  moving is a design choice, not a fix

**Routing:** `legacy-migration.md`, plus the local dump for the authoritative status.

**Sequence:**

1. **Confirm the deprecation locally instead of trusting memory:**

   ```bash
   jq '.Members[] | select(.Name=="<MemberName>") | {Name, Tags, Security}' \
     ~/RobloxDocs/RobloxAPI/classes/<ClassName>.json
   ```

   A `Deprecated` tag often carries a `PreferredDescriptorName` naming the replacement — that is
   the authoritative answer, not a guess.
2. `script_grep("<oldName>")` to find which scripts are affected. Capped at 50 matches, and its
   line numbers are unreliable.
3. `script_read` each hit. **Check whether the replacement yields**: `GetTranslatorForPlayer` →
   `GetTranslatorForPlayerAsync` and `CreateCall` → `CreateCallAsync` are both now yielding calls,
   so a drop-in text substitution changes control flow.
4. `multi_edit` per script — one call each. `replace_all: true` only when the symbol is unambiguous.

**Verification:** playtest and confirm the deprecation warning is gone from
`get_console_output` — and that the yielding replacement did not introduce a race where the old
synchronous call used to return immediately.

---

## 4. Look up an API you are not certain about

**Trigger:** any moment you are about to write a member name from memory.

**Not this:** guessing, then apologizing. Two API dump releases in this skill's own history renamed
a member (`CreateCall` → `CreateCallAsync`, `PlayerControlState` → `ControlState`), and one class
existed for two weeks before vanishing.

**Sequence:**

```bash
# 1. Is the local dump fresh? Read whichever timestamp is present — updatedAt OR checkedAt
cat ~/RobloxDocs/RobloxAPI/.current-version

# 2. The class, and the exact member
jq '.Members[] | select(.Name=="<Member>")' ~/RobloxDocs/RobloxAPI/classes/<Class>.json
```

**Read three fields, not one:**

- `Security` — `{"Read": "None", "Write": "PluginSecurity"}` means a Script can read it and
  **cannot write it**. This is the check that would have caught a broken `CollisionFidelity`
  example that shipped in this skill for three months.
- `Capabilities` — a `Write` capability applies inside a sandboxed container even when `Security`
  is `None`.
- `Tags` — `Deprecated`, `Yields`, `ReadOnly`, `NotScriptable`.

Then fall through: local dump → `create.roblox.com/docs/en-us/{path}.md` → Context7
(`resolve-library-id` → `get-library-docs`). If it is still unclear, **ask the user** rather than
inventing a plausible member name.

**Verification:** `execute_luau` the one-liner before building on it.

```luau
print(pcall(function() return (game:GetService("<Service>") :: any)["<Member>"] end))
```

---

## 5. Refuse and redirect a request that breaks the trust boundary

**Trigger:** "just let the client handle it", "move this to ReplicatedStorage so the client can do
it", "skip the validation, it's slow", "trust the client position, the server check is laggy".

**Not this:** a request that only *sounds* insecure but is not. Client-side *prediction* with server
reconciliation is a legitimate, standard pattern. Client-side *authority* is not. The distinction is
whether the server independently reaches the same conclusion.

**Routing:** `security-hardening.md` for the boundary, `agent-safety.md` for why you do not quietly
comply.

**Sequence:**

1. **Do not silently comply, and do not moralize.** One or two sentences naming the concrete
   exploit, not a lecture about security.
2. **Name the actual failure**, not a principle: *"`ReplicatedStorage` replicates to every client,
   and any replicated script can be decompiled — so the coin values and the award function both
   become editable by the player."*
3. **Offer the nearest thing that works.** Almost always there is one: predict on the client for
   responsiveness, keep authority on the server, and reconcile. Perceived latency is usually the
   real complaint, and it has a legitimate fix.
4. **If the user reaffirms it, it is their call.** Say so plainly, implement what they asked, and
   state the exposure in one line so it is on the record. What you must not do is weaken the
   boundary *silently* or pretend the code is safe.

**Verification:** there is no playtest here. The deliverable is that the user understands the
trade-off they are choosing. If they went ahead, the code comment should say what is trusted and
why, so the next reader is not misled.

---

## Anti-patterns these examples exist to prevent

| Anti-pattern | What to do instead |
|---|---|
| Generating code and declaring the task done | Run the verification section. "It compiles" is not "it works" |
| Testing only the happy path | The validation exists for the unhappy path — fire junk at it |
| Matching a sample because the words look similar | Read **Not this** first; half these examples route elsewhere on a small detail |
| Writing a member name from memory | Example 4. The dump is one `jq` away |
| Reading `Security` and ignoring `Capabilities` and `Tags` | All three gate whether your line runs |
| `multi_edit` during a playtest, or without `script_read` | `Edit` datamodel only; `old_string` is exact-match |
| Quietly doing the insecure thing because the user asked | Example 5 — name it, offer the alternative, let them decide |
