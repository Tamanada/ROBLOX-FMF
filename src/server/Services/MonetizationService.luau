--!strict
-- server/Services/MonetizationService.luau — Blueprint §8, §10.5.
-- Game Passes (§8.1) and Developer Products (§8.2). Binding rules (§8.4):
--   * no gameplay-critical content is Robux-exclusive (Shells/Hype/repairs are
--     all earnable in-game — these only ACCELERATE);
--   * no direct paid loot boxes;
--   * every Dev Product flows through ProcessReceipt with IDEMPOTENCE (§8.4.3):
--       1. resolve the player + active profile (else NotProcessedYet → retry);
--       2. claim the PurchaseId in the profile BEFORE granting;
--       3. grant, then persist immediately (SaveNow, §10.4);
--       4. a retry with a known PurchaseId returns PurchaseGranted without
--          double-granting.
-- Effects are pushed to the owning services (Economy/Hype/Build) so this stays
-- a leaf (nothing requires it back).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local BuildService = require(script.Parent.BuildService)
local HypeService = require(script.Parent.HypeService)

local MonetizationService = {}

local started = false

--------------------------------------------------------------------------
-- Pure idempotency core (unit-tested in tests/Monetization.spec.luau)
--------------------------------------------------------------------------

-- Claims a PurchaseId. Returns true if this is a NEW grant (caller grants),
-- false if already granted (idempotent — do NOT grant again). Marking BEFORE
-- the grant is the §8.4.3 ordering.
function MonetizationService._claimPurchase(history: { [string]: boolean }, purchaseId: string): boolean
	if history[purchaseId] then
		return false
	end
	history[purchaseId] = true
	return true
end

--------------------------------------------------------------------------
-- Effect application
--------------------------------------------------------------------------

-- Applies a Dev Product effect. Returns false if it could not be granted (the
-- caller then rolls back the claim so a retry can succeed).
local function grantProduct(player: Player, data: Types.PlayerData, product: Monetization.ProductDef): boolean
	if product.effect == "shells" then
		return EconomyService.Credit(player, product.amount, "devproduct")
	elseif product.effect == "hypeBoost" then
		HypeService.AddTimedBoost(
			player,
			data,
			Monetization.HYPE_BOOST_AMOUNT,
			Monetization.HYPE_BOOST_DURATION_SECONDS
		)
		return true
	elseif product.effect == "repairAll" then
		BuildService.RepairAll(player)
		return true
	end
	return false
end

-- Applies a Game Pass effect (idempotent — safe to call every join).
local function applyPass(player: Player, data: Types.PlayerData, pass: Monetization.PassDef)
	if pass.effect == "autoCollect" then
		BuildService.SetAutoCollect(player, true)
	elseif pass.effect == "vip" then
		BuildService.SetExternalMultiplier(player, data, "vip", Monetization.VIP_SHELLS_MULTIPLIER)
	elseif pass.effect == "goldenBoat" then
		player:SetAttribute("NPCArrivalMultiplier", Monetization.GOLDEN_BOAT_ARRIVAL_MULTIPLIER)
	elseif pass.effect == "pyro" then
		player:SetAttribute("PassPyro", true)
	end
	-- extraPlot: deferred (multi-plot persistence) — flag only.
	player:SetAttribute("Owns_" .. pass.id, true)
end

--------------------------------------------------------------------------
-- ProcessReceipt (§8.4.3 idempotent) + Game Pass purchases
--------------------------------------------------------------------------

local function processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player == nil then
		-- §10.5 — profile unavailable: tell Roblox to retry later.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.Get(player)
	if data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = Monetization.productByProductId[receiptInfo.ProductId]
	if product == nil then
		-- Unknown product id: don't consume the receipt — retry later.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	if not MonetizationService._claimPurchase(data.purchaseHistory, purchaseId) then
		-- Already granted in a prior call: idempotent success.
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if not grantProduct(player, data, product) then
		data.purchaseHistory[purchaseId] = nil -- roll back so a retry can grant
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	DataService.SaveNow(player) -- §10.4 — persist the grant immediately
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onGamePassFinished(player: Player, gamePassId: number, purchased: boolean)
	if not purchased then
		return
	end
	local pass = Monetization.passByGamePassId[gamePassId]
	if pass == nil then
		return
	end
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	data.passes[pass.id] = true
	applyPass(player, data, pass)
	DataService.SaveNow(player)
end

--------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------

function MonetizationService.Init()
	if started then
		return
	end
	started = true

	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassFinished)
end

-- Re-apply owned passes on join (§8.1 — persistent effects). Verifies live
-- ownership for passes with a real id, then applies every owned effect.
function MonetizationService.TrackPlayer(player: Player, data: Types.PlayerData)
	for _, pass in Monetization.passes do
		local owned = data.passes[pass.id] == true
		if not owned and pass.gamePassId ~= 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.gamePassId)
			end)
			if ok and result == true then
				owned = true
				data.passes[pass.id] = true
			end
		end
		if owned then
			applyPass(player, data, pass)
		end
	end
end

return MonetizationService
