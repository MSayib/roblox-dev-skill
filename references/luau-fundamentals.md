# Luau Language Fundamentals

> Reference for AI coding skill — verified against official Roblox documentation.
> Sources: https://create.roblox.com/docs/luau, https://luau.org, https://roblox.github.io/lua-style-guide/

## Table of Contents
- [Language Overview](#language-overview)
- [Type System](#type-system)
- [New Type Solver](#new-type-solver)
- [Type Annotations](#type-annotations)
- [Type Operators](#type-operators)
- [Naming Conventions](#naming-conventions)
- [Modern Task Library](#modern-task-library)
- [Guard Clauses](#guard-clauses)
- [String Interpolation](#string-interpolation)
- [Generalized Iteration](#generalized-iteration)
- [Table Methods](#table-methods)
- [LEGACY Patterns](#legacy-patterns)

---

## Language Overview

Luau is the scripting language used in Roblox Studio — a fast, safe, gradually
typed language **derived from Lua 5.1**. Key additions over Lua 5.1:
- Gradual type system with annotations and inference
- `continue` keyword, compound operators (`+=`, `-=`, `*=`, `/=`, `..=`)
- String interpolation with backtick strings
- Generalized iteration (`for k, v in table`)
- `if-then-else` expressions (ternary)
- `table.freeze`, `table.clone` for immutability
- No `goto` statement

---

## Type System

### Inference Modes
Set on the **first line** of any Script/LocalScript/ModuleScript:
```luau
--!strict    -- Asserts ALL types (inferred + explicit). Use for new code.
--!nonstrict -- Only checks explicitly annotated types (default)
--!nocheck   -- Disables type checking entirely
```

### Core Types
```luau
--!strict
local name: string = "Player1"       -- Primitives: string, number, boolean, nil
local target: Part? = nil            -- Optional: type? means type | nil
local part: Part = Instance.new("Part")  -- Roblox classes are types
local material: Enum.Material = part.Material  -- Enums are types
local value = someFunction()
local str: string = (value :: any) :: string   -- Type cast with ::
```

---

## New Type Solver

The **New Type Solver** reached GA on **November 20, 2025**.
- Enabled by default for `--!nocheck` and `--!nonstrict` modes
- Old engine remains available through 2026 for migration
- Unlocks **type functions** (`keyof`, `rawkeyof`) not possible in old solver
- Better inference for complex tables, generics, and control-flow narrowing
- Config: Studio → Workspace Properties → Scripting → `LuauTypeCheckMode`

---

## Type Annotations

### Functions
```luau
--!strict
local function add(x: number, y: number): number
	return x + y
end

-- Multiple returns use parentheses
local function divide(a: number, b: number): (number, boolean)
	if b == 0 then return 0, false end
	return a / b, true
end

-- Functional type definitions
type Callback = (player: Player, score: number) -> ()
type Validator = (value: string) -> (boolean, string?)
```

### Custom Types and Generics
```luau
--!strict
type PlayerData = {
	Name: string,
	Score: number,
	Inventory: { string },
	Metadata: { [string]: any },
}

type Result<T> = { Success: boolean, Value: T?, Error: string? }

local function wrapResult<T>(value: T): Result<T>
	return { Success = true, Value = value, Error = nil }
end
```

### Exports, Unions, Intersections
```luau
--!strict
export type WeaponConfig = { Name: string, Damage: number, FireRate: number }
type StringOrNumber = string | number
type Named = { Name: string }
type Scored = { Score: number }
type NamedAndScored = Named & Scored
```

---

## Type Operators

### `typeof` — infer type from a runtime value
```luau
--!strict
type Car = typeof({ Speed = 0, Wheels = 4 })
--> Car: { Speed: number, Wheels: number }
```

### `keyof` — extract keys as union (New Type Solver only)
```luau
--!strict
type Config = { Volume: number, Brightness: number, Language: string }
type ConfigKey = keyof<Config>  --> "Volume" | "Brightness" | "Language"
```

---

## Naming Conventions

Official Roblox Lua Style Guide (https://roblox.github.io/lua-style-guide/):

| Convention | Use For | Example |
|---|---|---|
| **PascalCase** | Classes, ModuleScripts, Enums, Constructors | `PlayerManager` |
| **camelCase** | Variables, functions, parameters, methods | `playerName`, `getScore()` |
| **UPPER_SNAKE_CASE** | Constants | `MAX_HEALTH`, `DEFAULT_SPEED` |

**Acronym rule:** Do NOT capitalize full acronyms — treat them as words:
```luau
--!strict
-- CORRECT: JsonTable, HttpResponse, XmlParser
-- WRONG:   JSONTable, HTTPResponse, XMLParser
local jsonData = HttpService:JSONDecode(response)
```

---

## Modern Task Library

**Always prefer `task.*` over legacy globals.** No throttling, precise timing.

```luau
--!strict
-- task.spawn: runs immediately in a new thread
task.spawn(function()
	print("Immediate execution")
end)

-- task.defer: runs at end of current resume cycle
task.defer(function()
	print("Deferred execution")
end)

-- task.delay: runs after N seconds (no throttle, guaranteed on first Heartbeat)
local thread = task.delay(5, function()
	print("5 seconds later")
end)

-- task.cancel: cancel a scheduled thread
task.cancel(thread)

-- task.wait: yields for N seconds, returns actual elapsed time
local elapsed = task.wait(1)  -- Yields ~1 second
```

---

## Guard Clauses

Prefer early returns to reduce nesting:
```luau
--!strict
local function processPlayer(player: Player?)
	if not player then return end
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	humanoid.Health = humanoid.MaxHealth
end
```

---

## String Interpolation

Use backticks with `{expression}` — **prefer over `..` concatenation**:
```luau
--!strict
local name = "Builder"
local score = 42
local message = `Hello {name}, your score is {score}!`
local doubled = `{name} has {score * 2} double points`
local escaped = `Literal \`backtick\` and \{braces\}`
```

---

## Generalized Iteration

Iterate directly over tables without `pairs()`/`ipairs()`:
```luau
--!strict
local inventory = { Sword = 1, Shield = 2, Potion = 5 }
for item, count in inventory do
	print(`{item}: {count}`)
end

local names = { "Alice", "Bob", "Charlie" }
for index, name in names do
	print(`{index}. {name}`)
end
```

---

## Table Methods

```luau
--!strict
-- table.find: returns index or nil
local fruits = { "Apple", "Banana", "Cherry" }
local idx = table.find(fruits, "Banana")  --> 2

-- table.create: pre-allocate with optional fill
local zeros = table.create(10, 0)  -- { 0, 0, ..., 0 }

-- table.freeze: make read-only (shallow)
local CONFIG = table.freeze({ MaxPlayers = 50, RoundTime = 300 })
-- CONFIG.MaxPlayers = 100  --> ERROR: frozen table

-- table.clone: shallow copy
local copy = table.clone(original)
```

---

## LEGACY Patterns

### Deprecated Globals → Modern Replacements

| Legacy (deprecated) | Modern | Notes |
|---|---|---|
| `wait(n)` | `task.wait(n)` | Legacy throttles; modern is precise |
| `spawn(fn)` | `task.spawn(fn)` | Legacy delays ≥1 frame |
| `delay(n, fn)` | `task.delay(n, fn)` | Legacy throttles timing |
| `pairs(t)` / `ipairs(t)` | `for k, v in t` | Generalized iteration |
| `"a" .. b .. "c"` | `` `a {b} c` `` | String interpolation |

```luau
--!strict
-- LEGACY → MODERN
-- wait(1)                       → task.wait(1)
-- spawn(function() end)         → task.spawn(function() end)
-- delay(5, function() end)      → task.delay(5, function() end)
-- for k, v in pairs(t) do end  → for k, v in t do end
-- name .. " scored " .. tostring(score) → `{name} scored {score}`
```
