# Luau Language Fundamentals

> Reference for AI coding skill — verified against official Roblox documentation and Luau language release specs (**v0.737**, released 2026-09-04).
> Sources: https://create.roblox.com/docs/luau, https://luau.org, https://roblox.github.io/lua-style-guide/

## Table of Contents
- [Language Overview](#language-overview)
- [Type System & Inference Modes](#type-system--inference-modes)
- [New Type Solver & Type Functions](#new-type-solver--type-functions)
- [Type Annotations](#type-annotations)
- [Type Operators & Type Constructors](#type-operators--type-constructors)
- [Buffer and Vector Native Libraries](#buffer-and-vector-native-libraries)
- [Native Code Generation (`--!native`)](#native-code-generation---native)
- [Naming Conventions](#naming-conventions)
- [Modern Task Library & Fast pcall](#modern-task-library--fast-pcall)
- [Guard Clauses](#guard-clauses)
- [String Interpolation](#string-interpolation)
- [Generalized Iteration](#generalized-iteration)
- [Table Methods & Immutability](#table-methods--immutability)
- [LEGACY Patterns](#legacy-patterns)

---

## Language Overview

Luau is the scripting language used in Roblox Studio — a fast, safe, gradually
typed language **derived from Lua 5.1**. Key additions over Lua 5.1:
- Gradual type system with annotations, inference, and user-defined type functions
- `continue` keyword, compound operators (`+=`, `-=`, `*=`, `/=`, `%=`, `^=`, `..=`)
- String interpolation with backtick strings (`` `value: {val}` ``)
- Generalized iteration (`for k, v in table`)
- `if-then-else` expressions (ternary)
- `table.freeze`, `table.isfrozen`, `table.clone`, `table.clear`
- High-performance `buffer` and `vector` native libraries
- Native code generation (`--!native`) and fast `pcall`/`xpcall` VM execution (`LOP_FASTPCALL`)
- No `goto` statement

### What landed in 0.736 and 0.737 (source: luau-lang/luau release notes)

Both releases are **fixes and internals, not new syntax you can write today**. Nothing here changes
how you write Luau for Roblox; it is here so nobody mistakes an internal change for a new feature.

| Release | Change | What it means for your code |
|---|---|---|
| 0.736 | Better generalization of lambdas defined in table literals; fewer internal errors on generics | Some previously-annotated tables may now infer correctly on their own |
| 0.736 | Modules without a `return` can join cyclic groups; better cyclic-require errors | Cycle mistakes report more usefully |
| 0.737 | Type arguments are now typechecked in explicit instantiation | Code that passed a bad explicit type argument may now error — a **fix**, not a regression |
| 0.737 | `keyof` produces unions in lexicographic order | `keyof` results are stable across platforms |
| 0.737 | Table indexers no longer leak their generics into unsealed tables passed as arguments | Fewer spurious inference results |
| 0.737 | The require-cycle length limit was removed | Long cycles no longer hit an arbitrary cap (they are still bad design) |
| 0.737 | Fixed upvalue handling in `repeat..until` loops using `continue` | A real miscompile; if you hit odd upvalue behaviour there, it was this |

**Experimental, and NOT usable in Roblox:** the **Classes** RFC prototype and the **`if local`**
statement both exist in 0.737 only behind `DebugLuau*` fast-flags in the open-source Luau repo. They
are not enabled in Roblox Studio. Do not write either into game code, and do not tell a user they
can.

---

## Type System & Inference Modes

### Inference Modes
Set on the **first line** of any Script/LocalScript/ModuleScript:
```luau
--!strict    -- Asserts ALL types (inferred + explicit). Mandatory for new code.
--!nonstrict -- Only checks explicitly annotated types (default)
--!nocheck   -- Disables type checking entirely
--!native    -- Compiles script to native machine code for maximum execution speed
```

### Core Types
```luau
--!strict
local name: string = "Player1"                -- Primitives: string, number, boolean, nil
local target: Part? = nil                     -- Optional: type? means type | nil
local part: Part = Instance.new("Part")       -- Roblox classes are types
local material: Enum.Material = part.Material -- Enums are types
local bufferData: buffer = buffer.create(64)  -- Buffer type
local vec: vector = vector.create(1, 2, 3)    -- Vector native type
local value = someFunction()
local str: string = (value :: any) :: string  -- Type cast with ::
```

---

## New Type Solver & Type Functions

The **New Type Solver** is the standard type engine for Luau (GA since November 2025):
- Unlocks **built-in type functions** (`keyof`, `rawkeyof`, `setmetatable<T, M>`)
- Supports **user-defined type functions** (`type function`) with `pcall`/`xpcall` error handling and runtime heap limits
- Relabels inferred generics cleanly (`T`, `U`, `V`, `W` instead of `a`, `b`, `c`)
- Deep bidirectional control-flow narrowing and refined table indexer resolution
- Config: Studio → Workspace Properties → Scripting → `LuauTypeCheckMode`

```luau
--!strict
-- Standardized generic definitions
type Result<T, E> = { success: true, value: T } | { success: false, error: E }

-- Metatable type constructor
type ClassImpl = { __index: ClassImpl, greet: (self: Class) -> () }
export type Class = setmetatable<{ name: string }, ClassImpl>
```

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

## Type Operators & Type Constructors

### `typeof` — infer type from a runtime value
```luau
--!strict
type Car = typeof({ Speed = 0, Wheels = 4 })
--> Car: { Speed: number, Wheels: number }
```

### `keyof` — extract keys as union
```luau
--!strict
type Config = { Volume: number, Brightness: number, Language: string }
type ConfigKey = keyof<Config>  --> "Volume" | "Brightness" | "Language"
```

### `setmetatable` — typed OOP metatables
```luau
--!strict
local Account = {}
Account.__index = Account

export type Account = setmetatable<{ balance: number }, typeof(Account)>

function Account.new(initial: number): Account
	local self = setmetatable({ balance = initial }, Account)
	return self
end
```

---

## Buffer and Vector Native Libraries

Luau features high-performance native libraries for binary data and SIMD-accelerated 3D vectors.

### Buffer Library (`buffer.*`)
Buffers are fixed-size, mutable byte arrays designed for fast binary serialization, networking packets, and memory storage:
```luau
--!strict
-- Create a 16-byte buffer
local b = buffer.create(16)

-- Write typed numeric values
buffer.writeu8(b, 0, 255)
buffer.writei32(b, 1, 100000)
buffer.writef32(b, 5, 3.14159)
buffer.writestring(b, 9, "HELO")

-- Read values back
local header = buffer.readu8(b, 0)
local count = buffer.readi32(b, 1)
local pi = buffer.readf32(b, 5)
local tag = buffer.readstring(b, 9, 4)
```

### Vector Library (`vector.*`)
Native SIMD-optimized vector type with zero table allocation overhead:
```luau
--!strict
local v1 = vector.create(10, 20, 30)
local v2 = vector.create(1, 2, 3)
local v3 = v1 + v2
local dotProduct = vector.dot(v1, v2)
local magnitude = vector.magnitude(v1)
```

---

## Native Code Generation (`--!native`)

For compute-intensive algorithms (pathfinding, procedural generation, ray marching, heavy math), enable Luau Native Code Generation.

> **Server-side only.** The official docs scope this to "server-side scripts in your game" — a
> `--!native` LocalScript gains nothing from the comment. Only the script's *functions* are compiled;
> top-level code usually runs once and does not benefit.

```luau
--!strict
--!native
-- Functions in this script are compiled to machine code (server-side)
local function calculateNoiseGrid(width: number, height: number): { number }
	local grid = table.create(width * height, 0)
	for x = 1, width do
		for y = 1, height do
			grid[(y - 1) * width + x] = math.noise(x * 0.1, y * 0.1, 0)
		end
	end
	return grid
end
```

Per-function opt-in, when a whole-script pragma is too blunt:

```luau
@native
local function hotPath(x: number): number
	return x * x + 1
end
```

> **Best Practice**: Use `--!native` on math-heavy or tight numerical server loops. UI and simple
> event handler scripts do not benefit. Roblox publishes **no speedup figure** — the docs tell you to
> measure with and without, using the Script Profiler, and they list real costs: longer server
> startup, extra memory for the compiled code, and a native-code size limit past which compilation
> **silently stops** and the remainder runs as ordinary bytecode.

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

## Modern Task Library & Fast pcall

**Always prefer `task.*` over legacy globals.** No throttling, precise frame timing.

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

-- task.delay: resumes on a Heartbeat step at least N seconds later -- never earlier,
-- and later than N under load. Do not treat the delay as exact.
local thread = task.delay(5, function()
	print("5 seconds later")
end)

-- task.cancel: cancel a scheduled thread
task.cancel(thread)

-- task.wait: yields for N seconds, returns actual elapsed time
local elapsed = task.wait(1)  -- Yields ~1 second
```

### Fast `pcall` / `xpcall` (`LOP_FASTPCALL`)
In Luau 0.735+, the VM introduces `LOP_FASTPCALL`, reducing `pcall` and `xpcall` runtime invocation overhead by **~2x**. Wrap fallible operations safely without worrying about function call penalties:

```luau
--!strict
local success, result = pcall(function()
	return DataStoreService:GetDataStore("PlayerData"):GetAsync(playerKey)
end)
if not success then
	warn(`[DataStore] Failed to fetch data: {result}`)
end
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

## Table Methods & Immutability

```luau
--!strict
-- table.find: returns index or nil
local fruits = { "Apple", "Banana", "Cherry" }
local idx = table.find(fruits, "Banana")  --> 2

-- table.create: pre-allocate with optional fill
local zeros = table.create(10, 0)  -- { 0, 0, ..., 0 }

-- table.clear: empty an existing table without reallocating memory
local reusableTable = { 1, 2, 3 }
table.clear(reusableTable)         -- {} (retains capacity, 0 GC pressure)

-- table.freeze: make read-only (shallow)
local CONFIG = table.freeze({ MaxPlayers = 50, RoundTime = 300 })
-- CONFIG.MaxPlayers = 100         --> ERROR: Attempt to modify a readonly table

-- table.isfrozen: check immutability status
local isProtected = table.isfrozen(CONFIG) --> true

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
| `results = {}` in loop | `table.clear(results)` | 0 GC memory reuse |

```luau
--!strict
-- LEGACY → MODERN
-- wait(1)                       → task.wait(1)
-- spawn(function() end)         → task.spawn(function() end)
-- delay(5, function() end)      → task.delay(5, function() end)
-- for k, v in pairs(t) do end  → for k, v in t do end
-- name .. " scored " .. tostring(score) → `{name} scored {score}`
```
