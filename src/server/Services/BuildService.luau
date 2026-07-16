--!strict
-- server/Services/BuildService.luau — Blueprint §2.1, §4, §10.3.
-- Buy / upgrade / repair / collect — the S1 core loop. Every handler is
-- server-authoritative (§10.3): the client only sends intents through Net
-- (typed args + rate limit), then this service re-checks, in order:
--   1. argument sanity (Net spec + finite/integer checks),
--   2. ownership (the player's own plot/equipment),
--   3. game-state legality (catalogue id, zone unlocked, plot bounds,
--      balance, upgrade path, broken state),
-- before mutating the profile. All prices/rates come from shared/Config.
-- Revenue accrues server-side into an uncollected pool per plot; the
-- client only ever sees replicated display values.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
local EconomyMath = require(ReplicatedStorage.Shared.Util.EconomyMath)
local Serde = require(ReplicatedStorage.Shared.Util.Serde)
local Net = require(ReplicatedStorage.Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local HypeService = require(script.Parent.HypeService)
local PlotService = require(script.Parent.PlotService)

local BuildService = {}

type Runtime = {
	uncollected: number,
	ratePerMinute: number,
}

local runtime: { [Player]: Runtime } = {}
local started = false

local BOUNDS_MARGIN = 2
local MAX_BUILD_HEIGHT = 50

--------------------------------------------------------------------------
-- Pure helpers (unit-tested in tests/Economy.spec.luau)
--------------------------------------------------------------------------

-- Position expressed RELATIVE to the plot origin. NaN components fail the
-- comparisons and are therefore rejected (§10.3.2: position in plot bounds).
function BuildService._isWithinPlotBounds(relativePosition: Vector3, plotSize: Vector3): boolean
	local halfX = plotSize.X / 2 - BOUNDS_MARGIN
	local halfZ = plotSize.Z / 2 - BOUNDS_MARGIN
	return math.abs(relativePosition.X) <= halfX
		and math.abs(relativePosition.Z) <= halfZ
		and relativePosition.Y >= 0
		and relativePosition.Y <= MAX_BUILD_HEIGHT
end

-- Sum of effective rates (§3.3 Hype multiplier included) of the festival's
-- working equipment. Broken equipment earns 0 (§4).
function BuildService._computeRatePerMinute(data: Types.PlayerData): number
	local slot = data.plots[Economy.MAIN_PLOT_SLOT]
	if slot == nil then
		return 0
	end

	local total = 0
	for _, entry in slot.equipment do
		if not entry.broken then
			local def = Equipment.byId[entry.id]
			if def ~= nil then
				total += EconomyMath.effectiveRate(def.revenuePerMinuteNight, entry.level, data.hype)
			end
		end
	end
	return total
end

--------------------------------------------------------------------------
-- Internals
--------------------------------------------------------------------------

local function isArrayIndex(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value >= 1
		and value == math.floor(value)
end

local function notify(player: Player, message: string)
	Net.Server.Fire("Notify", player, message)
end

local function refreshRate(player: Player, data: Types.PlayerData)
	local playerRuntime = runtime[player]
	if playerRuntime == nil then
		return
	end
	playerRuntime.ratePerMinute = BuildService._computeRatePerMinute(data)
	EconomyService.SetTheoreticalRate(player, playerRuntime.ratePerMinute)
end

local function getEquipment(player: Player): (Types.PlayerData?, { Types.EquipmentInstance }?)
	local data = DataService.Get(player)
	if data == nil then
		return nil, nil
	end
	local slot = data.plots[Economy.MAIN_PLOT_SLOT]
	if slot == nil then
		return data, nil
	end
	return data, slot.equipment
end

--------------------------------------------------------------------------
-- Intent handlers (§10.3.1 — RequestBuy(equipmentId, cframe))
--------------------------------------------------------------------------

local function onRequestBuy(player: Player, equipmentId: string, worldCFrame: CFrame)
	local def = Equipment.byId[equipmentId]
	if def == nil then
		notify(player, "Unknown equipment.")
		return
	end
	if def.cost <= 0 then
		-- Campfire is a gift (§4) — never purchasable.
		notify(player, "This one is a gift — already yours!")
		return
	end
	if def.zone ~= 1 then
		-- Zone 2 unlocks in Sprint 4, Zone 3 in Sprint 6 (§4).
		notify(player, "This zone is not unlocked yet.")
		return
	end

	local data, equipment = getEquipment(player)
	local origin = PlotService.GetPlotOrigin(player)
	if data == nil or equipment == nil or origin == nil then
		return
	end

	local relative = origin:ToObjectSpace(worldCFrame)
	if not BuildService._isWithinPlotBounds(relative.Position, PlotService.PLOT_SIZE) then
		notify(player, "You can only build on your own plot.")
		return
	end

	if not EconomyService.Debit(player, def.cost, "buy:" .. equipmentId) then
		notify(player, `Not enough Shells — {def.displayName} costs {def.cost} 🐚.`)
		return
	end

	local entry: Types.EquipmentInstance = {
		id = equipmentId,
		level = 1,
		cframe = Serde.serializeCFrame(relative),
		broken = false,
	}
	table.insert(equipment, entry)

	HypeService.Recompute(player, data)
	refreshRate(player, data)
	PlotService.RefreshEquipment(player, data)
	notify(player, `{def.displayName} built! 🎉`)
end

local function onRequestUpgrade(player: Player, index: number)
	local data, equipment = getEquipment(player)
	if data == nil or equipment == nil then
		return
	end

	local entry = equipment[index]
	if entry == nil then
		notify(player, "Unknown equipment slot.")
		return
	end

	local def = Equipment.byId[entry.id]
	if def == nil or def.cost <= 0 then
		-- Free gifts (campfire) have no upgrade path — 60% of 0 would be
		-- free infinite ×1.5 revenue.
		notify(player, "This equipment cannot be upgraded.")
		return
	end
	if entry.level >= EconomyMath.maxLevel() then
		notify(player, `{def.displayName} is already at max level.`)
		return
	end

	local cost = EconomyMath.upgradeCost(def.cost)
	if not EconomyService.Debit(player, cost, "upgrade:" .. entry.id) then
		notify(player, `Not enough Shells — upgrade costs {cost} 🐚.`)
		return
	end

	entry.level += 1
	refreshRate(player, data)
	PlotService.RefreshEquipment(player, data)
	notify(player, `{def.displayName} upgraded to Lv{entry.level}! ⚡`)
end

local function onRequestRepair(player: Player, index: number)
	local data, equipment = getEquipment(player)
	if data == nil or equipment == nil then
		return
	end

	local entry = equipment[index]
	if entry == nil then
		notify(player, "Unknown equipment slot.")
		return
	end
	if not entry.broken then
		notify(player, "This equipment is not broken.")
		return
	end

	local def = Equipment.byId[entry.id]
	if def == nil then
		return
	end

	local cost = EconomyMath.repairCost(def.cost)
	if not EconomyService.Debit(player, cost, "repair:" .. entry.id) then
		notify(player, `Not enough Shells — repair costs {cost} 🐚.`)
		return
	end

	entry.broken = false
	HypeService.Recompute(player, data)
	refreshRate(player, data)
	PlotService.RefreshEquipment(player, data)
	notify(player, `{def.displayName} repaired! 🔧`)
end

local function onRequestCollect(player: Player)
	local playerRuntime = runtime[player]
	if playerRuntime == nil then
		return
	end

	local amount = math.floor(playerRuntime.uncollected)
	if amount <= 0 then
		notify(player, "Nothing to collect yet.")
		return
	end

	playerRuntime.uncollected -= amount
	EconomyService.Credit(player, amount, "collect")
	PlotService.SetPlotAttribute(player, "Uncollected", math.floor(playerRuntime.uncollected))
	notify(player, `Collected {amount} 🐚`)
end

--------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------

function BuildService.Init()
	if started then
		return
	end
	started = true

	Net.Server.Declare("Notify")
	Net.Server.Handle("RequestBuy", { "string", "CFrame" }, onRequestBuy)
	Net.Server.Handle("RequestUpgrade", { isArrayIndex }, onRequestUpgrade)
	Net.Server.Handle("RequestRepair", { isArrayIndex }, onRequestRepair)
	Net.Server.Handle("RequestCollect", {}, onRequestCollect)

	-- Revenue accrual loop (§2.1.2) — server holds the amounts (§10.3.4);
	-- the plot attribute is display-only replication.
	task.spawn(function()
		while true do
			task.wait(Economy.REVENUE_TICK_SECONDS)
			for player, playerRuntime in runtime do
				if playerRuntime.ratePerMinute > 0 then
					playerRuntime.uncollected += playerRuntime.ratePerMinute * (Economy.REVENUE_TICK_SECONDS / 60)
					PlotService.SetPlotAttribute(player, "Uncollected", math.floor(playerRuntime.uncollected))
				end
			end
		end
	end)
end

-- Called once per player after DataService + PlotService are ready.
function BuildService.TrackPlayer(player: Player, data: Types.PlayerData)
	local slot = data.plots[Economy.MAIN_PLOT_SLOT]
	if slot == nil then
		slot = { equipment = {} }
		data.plots[Economy.MAIN_PLOT_SLOT] = slot
	end

	-- §4 — Campfire (offert): first join receives the free campfire at the
	-- plot center.
	if #slot.equipment == 0 then
		table.insert(slot.equipment, {
			id = "campfire",
			level = 1,
			cframe = Serde.serializeCFrame(CFrame.new(0, 3, 0)),
			broken = false,
		})
		PlotService.RefreshEquipment(player, data)
	end

	HypeService.Recompute(player, data)

	-- §2.4 — offline earnings: 20% of the active rate, cap 8h, computed on
	-- the SAVED state (previous lastSeen, before this session stamped it).
	local savedRate = BuildService._computeRatePerMinute(data)
	local lastSeen = DataService.GetPreviousLastSeen(player)
	if lastSeen ~= nil and lastSeen > 0 then
		local offline = EconomyMath.offlineEarnings(savedRate, os.time() - lastSeen)
		if offline > 0 then
			EconomyService.Credit(player, offline, "offline")
			notify(player, `Welcome back! Your festival earned {offline} 🐚 while you were away.`)
		end
	end

	runtime[player] = { uncollected = 0, ratePerMinute = 0 }
	refreshRate(player, data)
end

function BuildService.UntrackPlayer(player: Player)
	local playerRuntime = runtime[player]
	if playerRuntime == nil then
		return
	end
	runtime[player] = nil

	-- Auto-bank the leftover pool on leave so nothing is lost between
	-- sessions. (Monkeys will steal LIVE uncollected Shells from S4 — §7.)
	local amount = math.floor(playerRuntime.uncollected)
	if amount > 0 then
		EconomyService.Credit(player, amount, "collect")
	end
end

return BuildService
