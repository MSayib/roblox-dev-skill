# Monetization Systems

> Reference: https://create.roblox.com/docs/production/monetization

## Table of Contents
- [Overview](#overview)
- [In-Experience Monetization](#in-experience-monetization)
- [Transfers API (Player-to-Player Donations)](#transfers-api)
- [Roblox Plus Subscription](#roblox-plus-subscription)
- [Publishing Requirements](#publishing-requirements)
- [Managed Pricing](#managed-pricing)
- [What's Allowed vs Not Allowed](#whats-allowed-vs-not-allowed)
- [Implementation Guide: Donation System](#implementation-guide)
- [LEGACY: Cross-Game Sales (Discontinued)](#legacy-cross-game-sales)

---

## Overview

Roblox monetization (checked 2026-10-11) consists of:
1. **Game Passes** — One-time purchases granting permanent perks
2. **Developer Products** — Repeatable purchases (consumables)
3. **Transfers API** — Player-to-player Robux transfers (NEW, replaces cross-game sales)
4. **Subscriptions** — Recurring in-experience subscriptions
5. **Engagement-Based Payouts** — Automatic payouts based on player time

---

## In-Experience Monetization

### Game Passes
One-time purchases that persist permanently for the player.

```lua
--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local VIP_PASS_ID = 123456789 -- Replace with your Game Pass ID

local function onPlayerAdded(player: Player)
    local success, hasPass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_PASS_ID)
    end)

    if success and hasPass then
        -- Grant VIP benefits
        print(`{player.Name} has VIP pass`)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
```

### Developer Products
Repeatable purchases (coins, potions, boosts).

```lua
--!strict
local MarketplaceService = game:GetService("MarketplaceService")

local PRODUCT_HANDLERS: { [number]: (Player) -> boolean } = {
    [111111111] = function(player: Player): boolean
        -- Grant 100 coins
        -- Update DataStore here
        return true
    end,
    [222222222] = function(player: Player): boolean
        -- Grant speed boost
        return true
    end,
}

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
    local player = game:GetService("Players"):GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local handler = PRODUCT_HANDLERS[receiptInfo.ProductId]
    if not handler then
        warn("No handler for product:", receiptInfo.ProductId)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- pcall's first value only says the handler did not ERROR. A handler that returns false
    -- ("not granted yet") must not be answered with PurchaseGranted, or the player pays for nothing.
    local ok, granted = pcall(handler, player)
    if ok and granted == true then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    if not ok then
        warn("Receipt handler errored:", granted)
    end
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.ProcessReceipt = processReceipt
```

> **This handler is not yet idempotent.** `ProcessReceipt` runs again for every unresolved purchase
> when the player joins, so a receipt you already granted can arrive again (a server that stopped
> after granting, before Roblox recorded the result). Record each `PurchaseId` together with the
> grant: see `worked-examples.md` §6 for the `UpdateAsync` pattern, tested in Studio 0.742. Roblox's
> own sample checks only `if success then`, although its warning says a handler must return `true`.

> **`BindReceiptHandler` is the newer route.** The official `MarketplaceService` reference
> (2026-10-11) calls `ProcessReceipt` "legacy" and documents
> `MarketplaceService:BindReceiptHandler(Enum.ReceiptType.DeveloperProduct, handler, filter?)`:
> a handler per list of product IDs (or a catch-all), returning `Enum.ReceiptDecision.Processed` or
> `NotProcessedYet`. A bound handler takes precedence and unmatched receipts fall through to
> `ProcessReceipt`, so the two can coexist while you migrate. It has been in the API dump since at
> least 0.733 (`Security: None`), and a game Script registered both forms in Studio 0.742 without
> error; a full purchase through it was not run here. The idempotency rule is the same: record the
> `PurchaseId` with the grant.

### 5. Subscriptions (Recurring In-Experience)

Subscriptions allow recurring billing for exclusive perks within an experience.
Players are charged automatically each billing period.

**Server-side — Check subscription status:**
```lua
--!strict
local MarketplaceService = game:GetService("MarketplaceService")

local SUBSCRIPTION_ID = "EXP-0000000000" -- Your subscription product ID

local function isSubscribed(player: Player): boolean
    local success, status = pcall(function()
        return MarketplaceService:GetUserSubscriptionStatusAsync(player, SUBSCRIPTION_ID)
    end)
    if success and status then
        return status.IsSubscribed
    end
    return false
end
```

**Server-side — Handle subscription state changes:**
<!-- skilltest: prelude subscription-id -->
```lua
--!strict
-- The event is on Players (MarketplaceService has no SubscriptionStatusChanged) and carries no
-- status, so read it again. Only server scripts receive it.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

Players.UserSubscriptionStatusChanged:Connect(function(player: Player, subscriptionId: string)
    if subscriptionId ~= SUBSCRIPTION_ID then
        return
    end
    local ok, status = pcall(function()
        return MarketplaceService:GetUserSubscriptionStatusAsync(player, subscriptionId)
    end)
    if not ok then
        return -- the check failed: change nothing, check again later
    end
    if status.IsSubscribed then
        -- Grant perks
    else
        -- Revoke perks
    end
end)
```

**Client-side — Prompt purchase:**
<!-- skilltest: prelude subscription-id -->
```lua
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
MarketplaceService:PromptSubscriptionPurchase(player, SUBSCRIPTION_ID)
```

**Key facts:**
- Subscriptions are managed in the Creator Dashboard
- `Players.UserSubscriptionStatusChanged` fires only after the server re-checks, which it does when
  the purchase modal closes. A player who subscribed outside the experience must still be prompted
  (the prompt says they are already subscribed) before the event fires
- Revenue split: same as other in-experience purchases
- Players can cancel anytime; access continues until the billing period ends
- Use `GetUserSubscriptionDetailsAsync` for plan details (price, period)
- Use `GetUserSubscriptionPaymentHistoryAsync` for payment audit trail

---

## Transfers API

> **Added May 2026** — Official replacement for cross-game donation patterns.
> Reference: https://create.roblox.com/docs/production/monetization/robux-transfers

### How It Works
- Player A sends Robux to Player B through a platform-controlled UI
- **10% commission** goes to the experience creator
- **90%** goes to the recipient
- **0% platform fee** from Roblox

### Requirements
| Requirement | Detail |
|-------------|--------|
| Sender | Must have active **Roblox Plus** subscription |
| Recipient | No subscription required |
| Age | Sender and recipient: 18+ must be age checked; under 18 need a linked parental account and parental approval for **each** transfer |
| Per-transaction | 10–500 Robux (official *Robux transfers* page) |
| Daily / monthly limit | 500 Robux per day, 1,000 per month. Asked whether this would scale by age or verification, Roblox said it is "intentionally starting with this limit" (staff FAQ, May 2026). No higher tier is documented |
| Reversibility | All transfers are **FINAL** |

### API Reference

```lua
--!strict
local MarketplaceService = game:GetService("MarketplaceService")

----- Receipt Handlers -----

local function processSenderReceipt(receiptInfo: { [string]: any }): Enum.ReceiptDecision
    print("Transfer sent:", receiptInfo.TransferRequestId)
    print("Amount:", receiptInfo.CurrencySpent)
    -- Log to DataStore for audit trail
    return Enum.ReceiptDecision.Processed
end

local function processReceiverReceipt(receiptInfo: { [string]: any }): Enum.ReceiptDecision
    print("Transfer received:", receiptInfo.TransferRequestId)
    -- Grant in-game rewards or acknowledgment
    return Enum.ReceiptDecision.Processed
end

-- Bind handlers (must be done on server)
MarketplaceService:BindReceiptHandler(
    Enum.ReceiptType.RobuxTransferSender,
    processSenderReceipt
)
MarketplaceService:BindReceiptHandler(
    Enum.ReceiptType.RobuxTransferReceiver,
    processReceiverReceipt
)

----- Initiate Transfer -----

local function initiateTransfer(sender: Player, receiverUserId: number, amount: number)
    -- Validate amount
    if amount < 10 or amount > 500 then
        warn("Amount must be between 10 and 500 Robux")
        return
    end

    local success, transferRequestId = pcall(function()
        return MarketplaceService:PromptRobuxTransferAsync(
            sender,
            receiverUserId,
            amount
        )
    end)

    if success then
        print("Transfer initiated:", transferRequestId)
    else
        -- Common failures:
        -- No Roblox Plus subscription
        -- Age restriction
        -- Daily/monthly limit reached
        -- Insufficient Robux
        warn("Transfer failed:", tostring(transferRequestId))
    end
end
```

### Security Considerations
- Call `PromptRobuxTransferAsync` **server-side only**
- Validate the amount on the server (10–500 range)
- Validate that sender is actually the requesting player
- Log `TransferRequestId` in DataStore for audit trail
- Handle pcall failures gracefully (subscription, age, limits)
- Never promise direct Robux payouts as rewards
- Only return `Enum.ReceiptDecision.Processed` after successfully logging

---

## Roblox Plus Subscription

> Rolled out April 30, 2026 ("Introducing Roblox Plus", Roblox staff, 2026-04-10). It does not
> replace Premium: the announcement says an existing Premium subscription still grants avatar
> marketplace access.

- Required for SENDING Robux via Transfers API
- Includes: free private servers, purchase discounts, Robux transfers
- NOT the same as "Roblox+" third-party browser extension
- Players can also send Robux directly through the platform (not just in-game)

---

## Publishing Requirements

> Rollout began May 19, 2026 ("Alternate Publishing Requirements for Roblox Kids and Select",
> Roblox staff, 2026-05-11).

- **Publishing fee**: a one-time, refundable 1,000 Robux per game to publish to all ages
- **Alternative**: an active Plus or Premium subscription (no per-game fee)
- **Refunded** automatically 90 days after the game becomes eligible for Kids or Select accounts,
  or 90 days after payment if it never does
- **Forfeited** only if the game is permanently removed for severe Community Standards violations

---

## Managed Pricing

> Announced 2026-06-15 ("Managed Pricing: One System for Better Pricing and Earnings Growth",
> Roblox staff); official *Managed pricing* and *Price optimization* pages.

- Unifies Regional Pricing + Price Optimization into single automated workflow
- Runs pricing tests at least every 90 days
- Opt-in/opt-out per item; new items enrolled by default
- Requires 60,000+ transactions over 30 days for price optimization
- Use `GetUsersPriceLevelsAsync` API to prevent price arbitrage

---

## What's Allowed vs Not Allowed

### ❌ NOT Allowed (Post-May 29, 2026)
- Cross-game sales of Game Passes
- Cross-game sales of Developer Products
- Old "PLS DONATE" booth system (listing other games' passes)
- Third-party Robux trading/buying/selling
- Direct Robux payouts as reward mechanisms
- Pushy/high-pressure purchase language
- Inaccurate countdown timers that restart

### ✅ Allowed
- Developer Products within their OWN experience
- Game Passes within their OWN experience
- Transfers API for in-game tipping/donations
- Direct Robux transfers via Roblox Plus (platform-level)
- Official Trading System (13+, for items)
- In-game currency systems using DataStores across your own games
- Subscriptions within your experience

---

## Implementation Guide

### Step-by-Step: Donation System

1. **Publish your experience** (1,000 Robux fee or Roblox Plus subscription)
2. **Create a ServerScript** in ServerScriptService
3. **Bind receipt handlers** for `RobuxTransferSender` and `RobuxTransferReceiver`
4. **Create UI** (LocalScript) allowing Player A to select Player B and an amount (10–500)
5. **Fire RemoteEvent** to server with target userId and amount
6. **Server validates** amount, player state, then calls `PromptRobuxTransferAsync`
7. **Platform shows confirmation UI** (Roblox's built-in, not yours)
8. **Process receipt** in bound handler — log and grant any in-game rewards
9. **Handle failures** — no subscription, age limit, daily cap, etc.

---

## LEGACY: Cross-Game Sales (Discontinued)

> **Discontinued May 29, 2026**

Previously, developers could sell Game Passes and Developer Products from other
experiences inside their own game. This was commonly used for "PLS DONATE" style
donation games.

**Why removed**: in Roblox's words, developer products and passes "were never designed for
peer-to-peer Robux transfers", and the change protects players "from fraud and exploitation"
(staff post, 2026-05-04).

**Migration path**: Use the Transfers API (see above).

> [!WARNING]
> There is conflicting information about whether Robux earned via Transfers API is
> eligible for DevEx. Always verify at:
> https://create.roblox.com/docs/production/monetization/robux-transfers
