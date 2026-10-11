-- expect: a receipt is granted once, re-delivery does not grant twice, not-ready stays retryable.
local skilltestPlayers = game:GetService("Players")
local skilltestPlayer = skilltestPlayers:GetPlayers()[1] or skilltestPlayers.PlayerAdded:Wait()
local receipt = {
	PurchaseId = "skilltest-" .. game:GetService("HttpService"):GenerateGUID(false),
	PlayerId = skilltestPlayer.UserId,
	ProductId = COINS_100,
}
__skilltest.eq("no leaderstats yet -> NotProcessedYet (retried later)",
	ReceiptHandler.process(receipt), Enum.ProductPurchaseDecision.NotProcessedYet)
local leaderstats = Instance.new("Folder")
leaderstats.Name = "leaderstats"
local coins = Instance.new("IntValue")
coins.Name = "Coins"
coins.Parent = leaderstats
leaderstats.Parent = skilltestPlayer
__skilltest.eq("ready -> PurchaseGranted", ReceiptHandler.process(receipt), Enum.ProductPurchaseDecision.PurchaseGranted)
__skilltest.eq("100 coins granted", coins.Value, 100)
__skilltest.eq("same PurchaseId again -> PurchaseGranted", ReceiptHandler.process(receipt), Enum.ProductPurchaseDecision.PurchaseGranted)
__skilltest.eq("but coins are not granted twice", coins.Value, 100)
leaderstats:Destroy()
