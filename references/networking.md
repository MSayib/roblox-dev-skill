# Networking & Remote Communication

> **Source:** [RemoteEvent](https://create.roblox.com/docs/reference/engine/classes/RemoteEvent) ·
> [RemoteFunction](https://create.roblox.com/docs/reference/engine/classes/RemoteFunction) ·
> [UnreliableRemoteEvent](https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent) ·
> [MessagingService](https://create.roblox.com/docs/reference/engine/classes/MessagingService) ·
> [Remote Events & Callbacks](https://create.roblox.com/docs/scripting/events/remote)

## Table of Contents
1. [Client-Server Model](#client-server-model)
2. [RemoteEvent](#remoteevent)
3. [RemoteFunction](#remotefunction)
4. [UnreliableRemoteEvent](#unreliableremoteevent)
5. [BindableEvent & BindableFunction](#bindableevent--bindablefunction)
6. [MessagingService](#messagingservice)
7. [Rate Limiting Patterns](#rate-limiting-patterns)
8. [Folder Organization for Remotes](#folder-organization-for-remotes)
9. [Text Chat and Platform-Integrated Chat](#text-chat-and-platform-integrated-chat)
10. [LEGACY](#legacy)

---

## Client-Server Model

Roblox uses an **authoritative server** model:
- The **server** is the source of truth for game state
- **Clients** (players) send requests; the server validates and executes them
- **Never trust the client** — always validate all data received from clients

Communication crosses the client-server boundary via:
- `RemoteEvent` — one-way, async
- `RemoteFunction` — two-way, yields
- `UnreliableRemoteEvent` — one-way, async, lossy (high frequency)

All remote objects must be in a location visible to both sides, typically
`ReplicatedStorage`. Sometimes `Workspace` or inside a `Tool` is appropriate.

---

## RemoteEvent

One-way asynchronous communication across the client-server boundary.
**Does not yield** the firing script.

### Server → Client

```luau
--!strict
-- ServerScriptService/NotifyPlayer.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local notifyEvent = ReplicatedStorage:WaitForChild("NotifyPlayer") :: RemoteEvent

-- Fire to one client
local function notifyPlayer(player: Player, message: string)
    notifyEvent:FireClient(player, message)
end

-- Fire to ALL clients
local function notifyAll(message: string)
    notifyEvent:FireAllClients(message)
end
```

### Client → Server

```luau
--!strict
-- StarterPlayerScripts/RequestPurchase.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local purchaseEvent = ReplicatedStorage:WaitForChild("RequestPurchase") :: RemoteEvent

-- Client sends a request
purchaseEvent:FireServer("Sword", 1)
```

### Server Listener (ALWAYS validate arguments)

```luau
--!strict
-- ServerScriptService/HandlePurchase.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local purchaseEvent = ReplicatedStorage:WaitForChild("RequestPurchase") :: RemoteEvent

purchaseEvent.OnServerEvent:Connect(function(player: Player, itemName: unknown, quantity: unknown)
    -- VALIDATE EVERYTHING — clients can send anything
    if typeof(itemName) ~= "string" then return end
    if typeof(quantity) ~= "number" then return end
    if quantity ~= math.floor(quantity) or quantity < 1 or quantity > 100 then return end

    -- Validate item exists
    local VALID_ITEMS = { Sword = 100, Shield = 75, Potion = 25 }
    local price = VALID_ITEMS[itemName]
    if not price then return end

    -- Process purchase server-side
    print(`{player.Name} purchased {quantity}x {itemName}`)
end)
```

> **Critical:** The first argument to `OnServerEvent` is always the `Player` who
> fired it. This is engine-injected and **cannot be spoofed**. Never accept a
> player argument from the client in your parameters — use the auto-provided one.

---

## RemoteFunction

Two-way synchronous communication. The caller **yields** until the recipient
returns a value.

### Client → Server (Common)

```luau
--!strict
-- StarterPlayerScripts/GetInventory.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local getInventoryFunc = ReplicatedStorage:WaitForChild("GetInventory") :: RemoteFunction

local inventory = getInventoryFunc:InvokeServer()
print("My inventory:", inventory)
```

```luau
--!strict
-- ServerScriptService/InventoryHandler.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local getInventoryFunc = ReplicatedStorage:WaitForChild("GetInventory") :: RemoteFunction

getInventoryFunc.OnServerInvoke = function(player: Player): { [string]: number }
    -- Return the player's inventory from your data system
    return { Sword = 1, Potion = 5 }
end
```

### When to Use RemoteFunction vs RemoteEvent

| Use RemoteFunction when... | Use RemoteEvent when... |
|---|---|
| Client needs a return value from server | No return value needed |
| Fetching data (inventory, shop prices) | Sending actions (shoot, purchase, chat) |
| One-off request/response patterns | Continuous or fire-and-forget events |

### ⚠ Security Warning: OnClientInvoke

**Never use `OnClientInvoke` for security-sensitive operations.**

Risks of `InvokeClient` (server calling client):
- If the client **throws an error**, the server throws too
- If the client **disconnects**, `InvokeClient` throws an error
- If the client **never returns**, the server yields **forever**

Use `RemoteEvent:FireClient()` instead for server-to-client communication
whenever possible — it's async and doesn't have these risks.

---

## UnreliableRemoteEvent

A variant of `RemoteEvent` for **high-frequency, non-critical data** that
trades reliability for lower latency and reduced network overhead.

### Key Characteristics
- Delivery is **not guaranteed** (packets may be lost)
- Ordering is **not guaranteed** (events may arrive out of order)
- **Payload limit: 1000 bytes** — larger events are dropped (in Studio, the Output says by how
  many bytes; official reference)
- A ~500 requests/sec per-client throttle on `FireServer`, like `RemoteEvent` but counted
  separately; excess unreliable events are **dropped**, where excess `RemoteEvent`s are processed
  later, in order (official *Remote events and callbacks* page)
- Events are not resent if lost

### Good Use Cases
- Mouse position / cursor tracking
- Cosmetic particle effects
- Real-time position hints (before physics replication)
- Camera orientation sharing
- Damage numbers / visual feedback

### Bad Use Cases
- Purchase requests (must be reliable)
- Chat messages (must be reliable + ordered)
- Inventory changes (must be reliable)

### Example: Mouse Position Replication

```luau
--!strict
-- StarterPlayerScripts/SendMousePosition.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local mouseEvent = ReplicatedStorage:WaitForChild("MousePosition") :: UnreliableRemoteEvent
local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()

RunService.Heartbeat:Connect(function()
    mouseEvent:FireServer(mouse.Hit.Position)
end)
```

```luau
--!strict
-- ServerScriptService/ReceiveMousePosition.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local mouseEvent = ReplicatedStorage:WaitForChild("MousePosition") :: UnreliableRemoteEvent

mouseEvent.OnServerEvent:Connect(function(player: Player, position: unknown)
    if typeof(position) ~= "Vector3" then return end
    -- Use for cosmetic effects, aim indicators, etc.
end)
```

---

## BindableEvent & BindableFunction

For **same-boundary** communication (server-to-server or client-to-client).
These do NOT cross the network boundary.

### BindableEvent (one-way)
```luau
--!strict
-- Server-to-server communication
local ServerStorage = game:GetService("ServerStorage")
local gameEvent = ServerStorage:WaitForChild("RoundEnded") :: BindableEvent

-- Module A fires
gameEvent:Fire("TeamBlue", 150)

-- Module B listens
gameEvent.Event:Connect(function(winningTeam: string, score: number)
    print(`{winningTeam} won with {score} points!`)
end)
```

### BindableFunction (two-way, yields)
```luau
--!strict
local ServerStorage = game:GetService("ServerStorage")
local calcFunc = ServerStorage:WaitForChild("CalculateDamage") :: BindableFunction

calcFunc.OnInvoke = function(baseDamage: number, multiplier: number): number
    return baseDamage * multiplier
end

-- Caller (same boundary)
local damage = calcFunc:Invoke(50, 1.5)  --> 75
```

> **BindableEvent/BindableFunction caveats:**
> 1. Arguments are **deep-copied** — changes after firing don't affect the receiver
> 2. **Metatables are stripped** during copy — OOP objects lose their methods
> 3. **Cyclic table references cause errors** — tables referencing themselves fail
> 4. **Large tables have performance cost** — deep-copy is O(n) on table size
> 5. `BindableEvent:Fire()` executes listeners **synchronously** before returning
>    (unlike `RemoteEvent` which is async across the network boundary)
>
> **Preference:** For same-context communication (server-to-server or client-to-client),
> prefer direct `ModuleScript` method calls over BindableEvents. They avoid the
> deep-copy overhead and preserve metatables.

---

## MessagingService

Cross-server communication within the same experience. Best-effort delivery —
**not guaranteed**.

### Limits

| Limit | Maximum |
|---|---|
| Message size | 1 KB |
| Messages sent per server | 600 + 240 × numPlayers per minute |
| Messages received per topic | 40 + 80 × numServers per minute |
| Messages received for entire game | 400 + 200 × numServers per minute |
| Subscriptions per server | 20 + 8 × numPlayers |
| Subscribe requests per server | 240 per minute |

### Example: Global Announcement

```luau
--!strict
-- ServerScriptService/CrossServerAnnounce.server.luau
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")

local TOPIC = "GlobalAnnouncement"

-- Subscribe to receive messages from other servers
local success, connection = pcall(function()
    return MessagingService:SubscribeAsync(TOPIC, function(message)
        -- message.Data = the payload, message.Sent = Unix timestamp
        local text = message.Data :: string
        for _, player in Players:GetPlayers() do
            -- Display announcement to all players on this server
            print(`[Announcement] {text}`)
        end
    end)
end)

-- Publish a message to ALL servers
local function announceGlobally(text: string)
    local pubSuccess, pubErr = pcall(function()
        MessagingService:PublishAsync(TOPIC, text)
    end)
    if not pubSuccess then
        warn("Failed to publish:", pubErr)
    end
end
```

> **Important:** `SubscribeAsync` yields. Wrap in `pcall`. The returned
> connection can be disconnected with `connection:Disconnect()`.

---

## Rate Limiting Patterns

### Server-Side Throttle for RemoteEvents

```luau
--!strict
-- ServerScriptService/ThrottledRemote.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local actionEvent = ReplicatedStorage:WaitForChild("PlayerAction") :: RemoteEvent

local COOLDOWN = 0.5 -- seconds between allowed actions
local lastActionTime: { [Player]: number } = {}

actionEvent.OnServerEvent:Connect(function(player: Player, action: unknown)
    if typeof(action) ~= "string" then return end

    local now = os.clock()
    local lastTime = lastActionTime[player] or 0

    if now - lastTime < COOLDOWN then
        -- Too fast — ignore or warn
        return
    end
    lastActionTime[player] = now

    -- Process legitimate action
    print(`{player.Name} performed {action}`)
end)

-- Clean up on leave
local Players = game:GetService("Players")
Players.PlayerRemoving:Connect(function(player: Player)
    lastActionTime[player] = nil
end)
```

### Throttling Guidelines

- `RemoteEvent` and `UnreliableRemoteEvent` each have a **~500 requests/sec per client** limit,
  shared among all remotes of the same type (official reference)
- This limit is client-to-server (`FireServer`) only
- Server-to-client (`FireClient`, `FireAllClients`) has no documented per-client cap
  but excessive use causes network saturation
- Always implement **server-side cooldowns** for exploitable actions
- Use `UnreliableRemoteEvent` for high-frequency data to reduce reliable queue pressure

---

## Folder Organization for Remotes

Organize remote objects in `ReplicatedStorage` using folders for clarity:

```
ReplicatedStorage/
├── Remotes/
│   ├── Events/           -- RemoteEvent instances
│   │   ├── RequestPurchase
│   │   ├── NotifyPlayer
│   │   └── PlayerAction
│   ├── Functions/        -- RemoteFunction instances
│   │   ├── GetInventory
│   │   └── GetShopPrices
│   └── Unreliable/       -- UnreliableRemoteEvent instances
│       ├── MousePosition
│       └── CosmeticEffect
```

### Creating Remotes via Script (alternative to manual setup)

```luau
--!strict
-- ServerScriptService/CreateRemotes.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function createFolder(parent: Instance, name: string): Folder
    local folder = Instance.new("Folder")
    folder.Name = name
    folder.Parent = parent
    return folder
end

local remotesFolder = createFolder(ReplicatedStorage, "Remotes")
local eventsFolder = createFolder(remotesFolder, "Events")
local functionsFolder = createFolder(remotesFolder, "Functions")
local unreliableFolder = createFolder(remotesFolder, "Unreliable")

local function createRemote(className: string, name: string, parent: Instance): Instance
    local remote = Instance.new(className)
    remote.Name = name
    remote.Parent = parent
    return remote
end

createRemote("RemoteEvent", "RequestPurchase", eventsFolder)
createRemote("RemoteEvent", "NotifyPlayer", eventsFolder)
createRemote("RemoteFunction", "GetInventory", functionsFolder)
createRemote("UnreliableRemoteEvent", "MousePosition", unreliableFolder)
```

---

## Text Chat and Platform-Integrated Chat

> **Source:** [Platform-integrated chat](https://create.roblox.com/docs/chat/platform-integrated-chat)
> (page added 2026-10-20) · [TextChannelWindow](https://create.roblox.com/docs/reference/engine/classes/TextChannelWindow) ·
> [TextChatCommand](https://create.roblox.com/docs/reference/engine/classes/TextChatCommand)

**Platform-integrated chat** is an opt-in `TextChatService` mode in which Roblox delivers and
renders chat, and **your code can no longer read what players type**. The docs page says it
becomes **required for all games starting in May 2027**, when the APIs below are deprecated. So
do not build new features on reading chat text, even in a game that has not opted in.

- **Opting in is a Properties-window setting:** `TextChatService.PlatformIntegratedChat`
  (`Enum.RolloutState`). It is `RobloxScriptSecurity`: in Studio 0.743.0.7431133 a Script, a
  LocalScript and MCP `execute_luau` each fail to read it with `The current thread cannot read
  'PlatformIntegratedChat' (lacking capability RobloxScript)`. Ask the user to flip it.
- **What changes with it `Enabled`**, measured in Studio 0.743.0.7431133 on 2026-10-21 with a
  message typed into the chat box during a playtest:

  | API | Disabled (default) | Enabled |
  |---|---|---|
  | `TextChatService.MessageReceived` → `TextChatMessage.Text` / `.PrefixText` | the text | fires, but both are `""`, and each read logs `TextChatMessage.Text is deprecated when PlatformIntegratedChat is Enabled. Please use TextChannelWindow to build your custom chat UI.` |
  | `Player.Chatted` (server) | fires with the text | **did not fire at all** (the docs page says these APIs return `""`; either way there is nothing to parse) |
  | `TextChannel:SendAsync()` | sends; returns the `TextChatMessage` | returns `nil`, delivers nothing, and warns `TextChannel:SendAsync() is deprecated when PlatformIntegratedChat is Enabled` |
  | `TextChatCommand.Triggered` (server) | full line, e.g. `"/probecmd alpha beta"` | **same: the full line still arrives** |

  The docs page also lists `TextChatMessage.Translation` and `TextChatService.OnIncomingMessage`
  as unsupported; those two were not measured here.
- **Chat commands go through `TextChatCommand`.** It is the one path that still receives the
  command text, so admin and debug commands with arguments keep working:

```luau
--!strict
-- ServerScriptService/ChatCommands.server.luau
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

-- Fill in your own admin UserIds. Never decide this from anything the client sends.
local ADMIN_USER_IDS: { [number]: boolean } = {}

local kickCommand = Instance.new("TextChatCommand")
kickCommand.Name = "KickPlayerCommand"
kickCommand.PrimaryAlias = "/kickplayer"
kickCommand.Parent = TextChatService

kickCommand.Triggered:Connect(function(source: TextSource, unfilteredText: string)
	if not ADMIN_USER_IDS[source.UserId] then
		return
	end
	-- The whole line arrives, alias included: "/kickplayer SomeName". It is unfiltered,
	-- so never show it to other players without TextService filtering.
	local targetName = string.match(unfilteredText, "^%S+%s+(%S+)")
	local target = if targetName then Players:FindFirstChild(targetName) else nil
	if target and target:IsA("Player") then
		target:Kick("Removed by an admin.")
	end
end)
```

- **Custom chat display goes through `TextChannelWindow`.** Parent it under a `ScreenGui` or
  `SurfaceGui` and set `Target` to one `TextChannel`; one window shows one channel, and the docs
  say the Global channel cannot be a custom window's target. `ChatWindowConfiguration` settings do
  not apply to it: set `UseDefaultFont = false` and then `FontFace`. Tested 2026-10-21 from a
  LocalScript: the docs sample bound a window to `RBXGeneral` and took a custom `FontFace`.

<!-- skilltest: client -->
```luau
--!strict
-- StarterPlayerScripts/ChatWindow.client.luau
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CustomChat"
screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local general = TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXGeneral") :: TextChannel

local window = Instance.new("TextChannelWindow")
window.Size = UDim2.fromOffset(400, 300)
window.Position = UDim2.fromOffset(10, 10)
window.Target = general
window.UseDefaultFont = false                        -- FontFace is ignored while this is true
window.FontFace = Font.fromEnum(Enum.Font.Arcade)
window.Parent = screenGui
```

- **`ChatWindowConfiguration.TextChannelDisplayMode`** (show a custom channel only in its own
  window) is set in Studio. A LocalScript can read it, and writing fails with `lacking capability
  PluginOrOpenCloud` (tested 2026-10-21).
- **Not affected**, per the docs page: signs, boards, mail and comment systems that do not go
  through `TextChatService`. Their policy is unchanged (no two-way player communication, a rate
  limit of at least 1 minute, moderation). A game that needs `PrefixText` chat tags should not
  enable the mode yet, because prefixes are not supported.

---

## LEGACY

### Old Patterns to Avoid

**❌ Using string-based remote names with `FindFirstChild` everywhere:**
```luau
--@skilltest: antipattern
-- Old pattern: fragile, no type safety
local event = game:GetService("ReplicatedStorage"):FindFirstChild("SomeEvent")
if event then event:FireServer(...) end
```

**✅ Modern: `WaitForChild` with type assertion:**
<!-- skilltest: client; prelude replicated-storage -->
```luau
--!strict
local event = ReplicatedStorage:WaitForChild("SomeEvent") :: RemoteEvent
event:FireServer(...)
```

**❌ Using `OnClientInvoke` for server→client security checks:**
<!-- skilltest: prelude remote-function-client -->
```luau
-- DANGEROUS: Client controls the return value, can lie or hang
remoteFunc.OnClientInvoke = function()
    return "trusted_response"  -- Client can return anything!
end
```

**✅ Modern: Use RemoteEvent + server-side state instead.**

**❌ Putting remotes directly in `Workspace` root (old tutorials):**
Legacy tutorials often had remotes scattered in Workspace. Use `ReplicatedStorage`
with organized folders.

**❌ Creating one RemoteEvent per action in LocalScripts:**
Old pattern was clients creating their own remotes. The server should always
create remotes, never the client.

### Migration from Legacy Patterns

1. **Move remotes to ReplicatedStorage** under organized folders
2. **Replace `FindFirstChild` with `WaitForChild`** and type assertions
3. **Add server-side validation** to all `OnServerEvent` handlers
4. **Replace `RemoteFunction.OnClientInvoke`** with `RemoteEvent:FireClient`
5. **Switch high-frequency events** (mouse, cosmetics) to `UnreliableRemoteEvent`
6. **Add rate limiting** to all client→server remote handlers
