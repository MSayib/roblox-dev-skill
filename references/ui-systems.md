# Roblox UI Systems

> ScreenGui, layout, common elements, 3D-attached UI, animations, and responsive design.

## Table of Contents

1. [ScreenGui Basics](#screengui-basics)
2. [Positioning & Sizing — UDim2](#positioning--sizing--udim2)
3. [Layout Objects](#layout-objects)
4. [Common UI Elements](#common-ui-elements)
5. [3D-Attached UI](#3d-attached-ui)
6. [UI Animations with TweenService](#ui-animations-with-tweenservice)
7. [Responsive Design](#responsive-design)
8. [StarterGui & LocalScript Interaction](#startergui--localscript-interaction)
9. [ProximityPrompt](#proximityprompt)
10. [Best Practices](#best-practices)
11. [UIShadow — Native Drop Shadows (June 2026)](#uishadow--native-drop-shadows-june-2026)
12. [StyleQuery — Responsive Style Queries (May 2026)](#stylequery--responsive-style-queries-may-2026)
13. [Per-Corner UICorner Rounding (June 2026)](#per-corner-uicorner-rounding-june-2026)

---

## ScreenGui Basics

A `ScreenGui` is the root container for 2D UI. Place under `StarterGui`; it is
cloned into each player's `PlayerGui` on join (and respawn, unless
`ResetOnSpawn = false`).

| Property | Type | Purpose |
|---|---|---|
| `DisplayOrder` | `number` | Higher values render on top |
| `ResetOnSpawn` | `boolean` | `true` (default) = re-cloned every respawn. `false` for persistent UI |
| `IgnoreGuiInset` | `boolean` | `true` = covers the top bar area. Use for full-screen overlays |
| `Enabled` | `boolean` | Toggle visibility of the entire GUI tree |

```luau
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUDGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 10
screenGui.Parent = player.PlayerGui
```

---

## Positioning & Sizing — UDim2

`UDim2.new(xScale, xOffset, yScale, yOffset)` — **Scale** (0–1) is a fraction
of the parent size; **Offset** is fixed pixels added after scale.

```luau
UDim2.fromScale(0.5, 0.5)   -- scale only (offset = 0)
UDim2.fromOffset(200, 100)   -- offset only (scale = 0)
```

**`AnchorPoint`** shifts the origin (0–1 per axis). Center an element:

```luau
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
```

**Rule of thumb:** prefer **Scale** for responsive layout. Use **Offset** for
fixed-pixel elements (icons, padding).

---

## Layout Objects

Layout objects are children of a container and automatically arrange siblings.

### UIListLayout / UIGridLayout

```luau
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Vertical
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 8)
list.Parent = containerFrame

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(100, 100)
grid.CellPadding = UDim2.fromOffset(8, 8)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = containerFrame
```

### Constraints & Utilities

| Object | Purpose |
|---|---|
| `UISizeConstraint` | Clamp min/max pixel size |
| `UITextSizeConstraint` | Clamp min/max text size |
| `UIAspectRatioConstraint` | Lock width:height ratio |
| `UIPadding` | Internal padding on a container |
| `UICorner` | Round corners |
| `UIStroke` | Outline / border |
| `UIFlexItem` | Per-child flex grow/shrink (with UIListLayout) |
| `UIScale` | Uniformly scale a subtree |

---

## Common UI Elements

### TextLabel / TextButton / TextBox

```luau
local label = Instance.new("TextLabel")
label.Text = "Score: 0"
label.Font = Enum.Font.GothamBold
label.TextSize = 24
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(0.3, 0.05)
label.Parent = screenGui
```

`TextButton` adds `Activated` (preferred) and `MouseButton1Click` events.
`TextBox` adds `FocusLost` for text input.

### ImageLabel / ImageButton

```luau
local icon = Instance.new("ImageLabel")
icon.Image = "rbxassetid://123456789"
icon.ScaleType = Enum.ScaleType.Fit
icon.Size = UDim2.fromOffset(48, 48)
icon.BackgroundTransparency = 1
icon.Parent = screenGui
```

### Frame & ScrollingFrame

`Frame` — generic container. `ScrollingFrame` — scrollable container. Set
`AutomaticCanvasSize = Enum.AutomaticSize.Y` so the canvas grows with content.

```luau
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.fromScale(0.4, 0.6)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 6
scroll.Parent = screenGui
Instance.new("UIListLayout").Parent = scroll
```

---

## 3D-Attached UI

### BillboardGui (always faces camera)

```luau
local billboard = Instance.new("BillboardGui")
billboard.Size = UDim2.fromOffset(200, 50)
billboard.StudsOffset = Vector3.new(0, 3, 0)
billboard.Adornee = workspace.SomeNPC.Head
billboard.Parent = workspace.SomeNPC.Head

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.fromScale(1, 1)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = "Shopkeeper"
nameLabel.TextScaled = true
nameLabel.Parent = billboard
```

### SurfaceGui (renders on a Part face)

```luau
local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Face = Enum.NormalId.Front
surfaceGui.PixelsPerStud = 50
surfaceGui.Parent = workspace.TVScreen

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.Text = "Breaking News"
label.TextScaled = true
label.Parent = surfaceGui
```

---

## UI Animations with TweenService

```luau
local TweenService = game:GetService("TweenService")

local tweenInfo = TweenInfo.new(
    0.3,                       -- duration
    Enum.EasingStyle.Quad,     -- style
    Enum.EasingDirection.Out   -- direction
)

local frame: Frame = screenGui.HUDFrame
frame.BackgroundTransparency = 1

local tween = TweenService:Create(frame, tweenInfo, {
    BackgroundTransparency = 0,
    Position = UDim2.fromScale(0.5, 0.5),
})
tween:Play()
tween.Completed:Wait()
```

**Tweenable UI properties:** `Position`, `Size`, `BackgroundTransparency`,
`BackgroundColor3`, `TextTransparency`, `ImageTransparency`, `Rotation`,
`GroupTransparency` (on `CanvasGroup` — tween it to fade an entire subtree).

---

## Responsive Design

Use `UDim2.fromScale()` for responsive sizing. Use `UIAspectRatioConstraint`
to lock ratio. Detect device and adapt:

```luau
local UIS = game:GetService("UserInputService")
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

local camera = workspace.CurrentCamera
camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    local vp = camera.ViewportSize
    inventoryFrame.Size = if vp.Y > vp.X
        then UDim2.fromScale(0.9, 0.4)
        else UDim2.fromScale(0.4, 0.8)
end)
```

---

## StarterGui & LocalScript Interaction

UI code runs on the **client** in `LocalScripts`.

```luau
--!strict
-- ShopController (LocalScript under ShopGui)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local shopGui = player.PlayerGui:WaitForChild("ShopGui")
local shopFrame = shopGui:WaitForChild("ShopFrame")
local itemTemplate = shopFrame:WaitForChild("ItemTemplate")
local PurchaseRemote = ReplicatedStorage:WaitForChild("PurchaseItem") :: RemoteEvent

local function createItemEntry(itemName: string, price: number)
    local entry = itemTemplate:Clone()
    entry.Name = itemName
    entry.Visible = true
    (entry:FindFirstChild("NameLabel") :: TextLabel).Text = itemName
    (entry:FindFirstChild("PriceLabel") :: TextLabel).Text = tostring(price) .. " coins"
    local buyButton = entry:FindFirstChild("BuyButton") :: TextButton
    buyButton.Activated:Connect(function()
        PurchaseRemote:FireServer(itemName)
    end)
    entry.Parent = shopFrame
end
```

---

## ProximityPrompt

Interaction UI when a player is near a Part — Roblox renders it automatically.

```luau
local prompt = Instance.new("ProximityPrompt")
prompt.ObjectText = "Treasure Chest"
prompt.ActionText = "Open"
prompt.MaxActivationDistance = 10
prompt.HoldDuration = 0.5
prompt.RequiresLineOfSight = true
prompt.Parent = workspace.TreasureChest

prompt.Triggered:Connect(function(player: Player)
    print(player.Name .. " opened the chest")
end)
```

For custom styling: set `prompt.Style = Enum.ProximityPromptStyle.Custom` and
listen to `ProximityPromptService.PromptShown` / `PromptHidden`.

---

## Best Practices

**Organization:**
- One `ScreenGui` per logical feature (HUD, Shop, Settings). Control layering
  with `DisplayOrder`.
- Name everything descriptively — `HealthBarFrame`, not `Frame`.
- Use ModuleScripts for UI logic; keep LocalScripts thin.

**Performance:**
- Avoid creating/destroying UI every frame — toggle `Visible` or object pool.
- Use `CanvasGroup` to batch-render complex subtrees.
- Minimize `TextScaled` on many labels — prefer explicit `TextSize`.
- Set `Parent` last when building UI trees in code.

**Cleanup:**

```luau
local connections: { RBXScriptConnection } = {}
table.insert(connections, button.Activated:Connect(onActivated))
table.insert(connections, RunService.Heartbeat:Connect(onHeartbeat))

-- On cleanup (player leave, ScreenGui destroyed):
for _, conn in connections do
    conn:Disconnect()
end
```

- Disconnect all event connections to prevent memory leaks.
- `ResetOnSpawn = true` (default) destroys and re-clones the ScreenGui — any
  references to the old copy will break.

---

## UIShadow — Native Drop Shadows (June 2026)

`UIShadow` renders a native drop shadow beneath its parent `GuiObject`,
replacing image-based shadow workarounds. Add as a child of any `GuiObject`.

| Property | Type | Purpose |
|---|---|---|
| `Color` | `Color3` | Shadow color |
| `Transparency` | `number` | `0` = opaque, `1` = invisible |
| `BlurRadius` | `UDim` | Blur softness. Scale is relative to the shorter parent axis |
| `Offset` | `UDim2` | Shifts the shadow relative to the parent position |
| `Spread` | `UDim2` | Expands or shrinks the shadow relative to the parent size |
| `ZIndex` | `number` | Render order among sibling `UIShadow` instances (negative values only) |
| `Enabled` | `boolean` | Toggle shadow visibility (default `true`) |

**Key behaviors:**
- Automatically respects `UICorner` rounding on the parent.
- Rotates with the parent's `Rotation` property.
- Multiple `UIShadow` children are supported; order via `ZIndex`.

**Limitations:**
- Does **not** render text-shaped shadows — only the rectangular bounding box.
- Does **not** support inset shadows.
- Cannot apply `UIGradient` to a `UIShadow`.
- Does **not** work with `Path2D`.

```luau
--!strict
-- Add a soft drop shadow to a card Frame
local card = Instance.new("Frame")
card.Name = "CardFrame"
card.Size = UDim2.fromScale(0.3, 0.4)
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

-- Round corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = card

-- Drop shadow (inherits the rounded corners)
local shadow = Instance.new("UIShadow")
shadow.Color = Color3.fromRGB(0, 0, 0)
shadow.Transparency = 0.5
shadow.BlurRadius = UDim.new(0, 16)
shadow.Offset = UDim2.fromOffset(0, 4)
shadow.Parent = card

card.Parent = screenGui
```

**Legacy comparison — before `UIShadow`:**

```luau
-- OLD approach: 9-slice ImageLabel behind the frame
local shadowImage = Instance.new("ImageLabel")
shadowImage.Image = "rbxassetid://SHADOW_ASSET_ID"
shadowImage.ScaleType = Enum.ScaleType.Slice
shadowImage.SliceCenter = Rect.new(24, 24, 232, 232)
shadowImage.Size = UDim2.new(1, 20, 1, 20)
shadowImage.Position = UDim2.fromOffset(-10, -6)
shadowImage.BackgroundTransparency = 1
shadowImage.Parent = card  -- layered behind content

-- NEW approach: one line of UIShadow (shown above)
```

---

## StyleQuery — Responsive Style Queries (May 2026)

`StyleQuery` enables CSS-like conditional styling for Roblox UI. It works with
the `StyleRule` system to dynamically activate styles based on device,
container size, or accessibility settings.

A `StyleQuery` is an `Instance` you parent under a style sheet. When all its
conditions are `true`, any `StyleRule` using the `@QueryName` selector becomes
active.

### Available Conditions

| Condition | Type | Evaluates to `true` when… |
|---|---|---|
| `MinSize` | `Vector2` | Parent `AbsoluteSize` ≥ `MinSize` |
| `MaxSize` | `Vector2` | Parent `AbsoluteSize` < `MaxSize` |
| `AspectRatioRange` | `NumberRange` | Parent width/height ratio is within the range |
| `ViewportDisplaySize` | `Enum.DisplaySize` | Matches `GuiService.ViewportDisplaySize` |
| `PreferredInput` | `Enum.PreferredInput` | Matches `UserInputService.PreferredInput` |
| `PreferredTextSize` | `Enum.PreferredTextSize` | Matches `GuiService.PreferredTextSize` |
| `ReducedMotionEnabled` | `boolean` | Matches `GuiService.ReducedMotionEnabled` |

### API Methods

| Method | Description |
|---|---|
| `SetCondition(name: string, value: Variant)` | Set a single condition |
| `SetConditions(conditions: {[string]: Variant})` | Set multiple conditions at once |
| `GetCondition(name: string): Variant` | Read a condition's current value |
| `GetConditions(): {[string]: Variant}` | Read all conditions |

`StyleQuery.IsActive` (read-only `boolean`) — `true` when all conditions match.

### Scripted Example: Responsive Container Query

```luau
--!strict
-- Create a StyleQuery that activates for narrow containers (< 400px wide)
local narrowQuery = Instance.new("StyleQuery")
narrowQuery.Name = "NarrowContainer"
narrowQuery:SetCondition("MaxSize", Vector2.new(400, math.huge))
narrowQuery.Parent = styleSheet  -- parent to your StyleSheet/StyleRule tree

-- Any StyleRule with Selector = "@NarrowContainer" will activate
-- when the parent container's AbsoluteSize.X < 400
```

### Scripted Example: Multi-Condition Query (Mobile + Touch)

```luau
--!strict
-- Activate styles for small-screen touch devices
local mobileQuery = Instance.new("StyleQuery")
mobileQuery.Name = "MobileTouch"
mobileQuery:SetConditions({
    ["ViewportDisplaySize"] = Enum.DisplaySize.Small,
    ["PreferredInput"] = Enum.PreferredInput.Touch,
})
mobileQuery.Parent = styleSheet

-- StyleRules with Selector = "@MobileTouch" now auto-activate on mobile
```

### Built-in Selectors

Roblox provides pre-configured selectors you can use in `StyleRule.Selector`
without creating your own `StyleQuery` instances:

- `@PreferredTextSizeLarge` — active when the player has selected large text
- `@WideContainer` — active when the parent container is wide

### Style Editor Improvements (Studio)

- **Folder organization**: Group related `StyleRule` instances into folders.
- **Smart search**: Filter style rules by name, selector, or property.
- **Auto-populated selectors**: The editor suggests selectors like
  `@PreferredTextSizeLarge` when creating new rules.

---

## Per-Corner UICorner Rounding (June 2026)

`UICorner` now supports individual corner radii, enabling asymmetric rounding
(e.g. tabs, chat bubbles, notification toasts).

| Property | Type | Purpose |
|---|---|---|
| `CornerRadius` | `UDim` | **Shorthand** — sets all four corners at once; reads from `TopLeftRadius` |
| `TopLeftRadius` | `UDim` | Top-left corner radius |
| `TopRightRadius` | `UDim` | Top-right corner radius |
| `BottomRightRadius` | `UDim` | Bottom-right corner radius |
| `BottomLeftRadius` | `UDim` | Bottom-left corner radius |

> **Note:** Per-corner properties require the **New UI Capabilities** beta
> feature enabled in Studio as of June 2026. Writing to `CornerRadius`
> overwrites all four individual values.

```luau
--!strict
-- Chat bubble: rounded on top, flat on bottom-left
local bubble = Instance.new("Frame")
bubble.Name = "ChatBubble"
bubble.Size = UDim2.fromOffset(260, 80)
bubble.BackgroundColor3 = Color3.fromRGB(45, 45, 48)
bubble.Parent = screenGui

local corner = Instance.new("UICorner")
corner.TopLeftRadius = UDim.new(0, 16)
corner.TopRightRadius = UDim.new(0, 16)
corner.BottomRightRadius = UDim.new(0, 16)
corner.BottomLeftRadius = UDim.new(0, 0)  -- flat corner
corner.Parent = bubble
```

**Legacy comparison — uniform rounding only:**

```luau
-- OLD: all corners identical
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = frame

-- NEW: per-corner control (shown above)
```

**Tip:** When using the styling system (`StyleRule`), avoid setting both
`CornerRadius` and individual corner properties in the same rule — this may
produce unexpected results.
