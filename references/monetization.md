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

Roblox monetization in mid-2026 consists of:
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

    local success = pcall(handler, player)
    if success then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.ProcessReceipt = processReceipt
```

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
| Age | Both users must complete Roblox age check |
| Under 18 | Linked parental account with approval |
| Under 16 | Parental approval required in most regions |
| Per-transaction | 10–500 Robux |
| Daily limit (no 2SV) | 500 Robux/day |
| Monthly limit (no 2SV) | 1,000 Robux/month |
| Daily limit (with 2SV) | 5,000 Robux/day |
| Monthly limit (with 2SV) | 10,000 Robux/month |
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

> Launched April 30, 2026 — replaces old Roblox Premium.

- Required for SENDING Robux via Transfers API
- Includes: free private servers, purchase discounts, Robux transfers
- NOT the same as "Roblox+" third-party browser extension
- Players can also send Robux directly through the platform (not just in-game)

---

## Publishing Requirements

> Updated May 19, 2026

- **Publishing fee**: 1,000 Robux one-time per game for "All Ages" publishing
- **Alternative**: Active Roblox Plus subscription (no per-game fee)
- **Refundable**: After 60+ days of maintained engagement without moderation actions
- **Forfeited**: If game is permanently removed for Community Standards violations

---

## Managed Pricing

> Launched H1 2026

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

**Why removed**: Developer products and passes were "never originally designed for
peer-to-peer Robux transfers" — the pattern was exploited for fraud.

**Migration path**: Use the Transfers API (see above).

> [!WARNING]
> There is conflicting information about whether Robux earned via Transfers API is
> eligible for DevEx. Always verify at:
> https://create.roblox.com/docs/production/monetization/robux-transfers
