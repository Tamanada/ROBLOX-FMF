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
local EventService = require(script.Parent.EventService)
local FullMoonService = require(script.Parent.FullMoonService)
local HypeService = require(script.Parent.HypeService)
local PlotService = require(script.Parent.PlotService)

local BuildService = {}

type Runtime = {
	uncollected: number,
	ratePerMinute: number,
	-- keyed revenue multipliers stacked on the base rate (§5.2 staff, §6 friend
	-- bonus, §8.1 VIP pass). Product of all entries; empty ⇒ ×1.
	multipliers: { [string]: number },
	autoCollect: boolean, -- §8.1 Auto-Collect pass
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

local function multiplierProduct(playerRuntime: Runtime): number
	local product = 1
	for _, value in playerRuntime.multipliers do
		product *= value
	end
	return product
end

local function refreshRate(player: Player, data: Types.PlayerData)
	local playerRuntime = runtime[player]
	if playerRuntime == nil then
		return
	end
	-- §5.2/§6/§8.1 — external multipliers (staff, friend bonus, VIP pass) scale
	-- the whole plot rate. The base rate stays the pure §4 computation.
	playerRuntime.ratePerMinute = BuildService._computeRatePerMinute(data) * multiplierProduct(playerRuntime)
	EconomyService.SetTheoreticalRate(player, playerRuntime.ratePerMinute)
end

local function setMaxZoneAttribute(player: Player, data: Types.PlayerData)
	local maxZone = 1
	for zoneKey, unlocked in data.unlockedZones do
		local n = tonumber(zoneKey)
		if unlocked and n ~= nil and n > maxZone then
			maxZone = n
		end
	end
	player:SetAttribute("MaxUnlockedZone", maxZone)
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

	local data, equipment = getEquipment(player)
	local origin = PlotService.GetPlotOrigin(player)
	if data == nil or equipment == nil or origin == nil then
		return
	end

	-- §4 — the equipment's zone must be unlocked (Zone 1 always, Zone 2 via
	-- RequestUnlockZone, Zone 3 in S6).
	if data.unlockedZones[tostring(def.zone)] ~= true then
		notify(player, "This zone is not unlocked yet.")
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

-- §4 — unlock the next zone (one-time Shells cost + Hype requirement).
local function onRequestUnlockZone(player: Player, zone: number)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local zoneKey = tostring(zone)
	if data.unlockedZones[zoneKey] == true then
		notify(player, "That zone is already unlocked.")
		return
	end
	local req = Economy.ZONE_UNLOCKS[zone]
	if req == nil then
		notify(player, "That zone cannot be unlocked yet.")
		return
	end
	-- Sequential unlocks: the previous zone must already be open.
	if data.unlockedZones[tostring(zone - 1)] ~= true then
		notify(player, "Unlock the previous zone first.")
		return
	end
	if data.hype < req.hype then
		notify(player, `Reach Hype {req.hype} to unlock Zone {zone}.`)
		return
	end
	if not EconomyService.Debit(player, req.shells, "unlock:" .. zoneKey) then
		notify(player, `Zone {zone} costs {req.shells} 🐚.`)
		return
	end

	data.unlockedZones[zoneKey] = true
	setMaxZoneAttribute(player, data)
	notify(player, `Zone {zone} unlocked — new festival grounds! 🌴`)
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
-- Cross-service hooks (§5.2 staff, §7 storm/monkeys) — pushed IN so this
-- service never has to require StaffService/EventService back (no cycles).
--------------------------------------------------------------------------

-- §5.2/§6/§8.1 — set a named revenue multiplier (key "staff" / "friend" /
-- "vip" …). Pushed by StaffService, SocialService, MonetizationService.
function BuildService.SetExternalMultiplier(player: Player, data: Types.PlayerData, key: string, value: number)
	local playerRuntime = runtime[player]
	if playerRuntime == nil then
		return
	end
	playerRuntime.multipliers[key] = value
	refreshRate(player, data)
end

-- §5.2 — thin wrapper kept for StaffService.
function BuildService.SetStaffMultiplier(player: Player, data: Types.PlayerData, multiplier: number)
	BuildService.SetExternalMultiplier(player, data, "staff", multiplier)
end

-- §8.1 — Auto-Collect pass: the accrual loop banks the pool automatically.
function BuildService.SetAutoCollect(player: Player, enabled: boolean)
	local playerRuntime = runtime[player]
	if playerRuntime ~= nil then
		playerRuntime.autoCollect = enabled
	end
end

-- §8.2 — Instant Repair All product: repair every broken equipment for free.
function BuildService.RepairAll(player: Player)
	local data, equipment = getEquipment(player)
	if data == nil or equipment == nil then
		return
	end
	local repaired = 0
	for _, entry in equipment do
		if entry.broken then
			entry.broken = false
			repaired += 1
		end
	end
	if repaired > 0 then
		HypeService.Recompute(player, data)
		refreshRate(player, data)
		PlotService.RefreshEquipment(player, data)
		notify(player, `🔧 All {repaired} equipment repaired!`)
	end
end

-- §4 / §7 — break up to `count` working (non-gift) equipment at random. Broken
-- equipment earns 0 and drags Hype until repaired (existing RequestRepair).
function BuildService.DamageRandomEquipment(player: Player, count: number)
	local data, equipment = getEquipment(player)
	if data == nil or equipment == nil then
		return
	end

	local working: { number } = {}
	for index, entry in equipment do
		if not entry.broken then
			local def = Equipment.byId[entry.id]
			if def ~= nil and def.cost > 0 then
				table.insert(working, index)
			end
		end
	end

	local broke = 0
	for _ = 1, count do
		if #working == 0 then
			break
		end
		local pick = math.random(1, #working)
		equipment[working[pick]].broken = true
		table.remove(working, pick)
		broke += 1
	end

	if broke > 0 then
		HypeService.Recompute(player, data)
		refreshRate(player, data)
		PlotService.RefreshEquipment(player, data)
		notify(player, `⛈️ {broke} equipment damaged — repair to restore revenue!`)
	end
end

-- §7 — monkeys steal a fraction of the UNCOLLECTED pool (banked Shells are
-- safe): urgency to collect.
function BuildService.StealUncollected(player: Player, fraction: number)
	local playerRuntime = runtime[player]
	if playerRuntime == nil then
		return
	end
	local stolen = math.floor(playerRuntime.uncollected * fraction)
	if stolen <= 0 then
		return
	end
	playerRuntime.uncollected -= stolen
	PlotService.SetPlotAttribute(player, "Uncollected", math.floor(playerRuntime.uncollected))
	notify(player, `🐒 Monkeys stole {stolen} 🐚 you hadn't collected!`)
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
	Net.Server.Handle("RequestUnlockZone", { isArrayIndex }, onRequestUnlockZone)
	Net.Server.Handle("RequestCollect", {}, onRequestCollect)

	-- §7 — EventService pushes storm damage / monkey theft here (no back-require).
	EventService.SetDamageHandler(BuildService.DamageRandomEquipment)
	EventService.SetStealHandler(BuildService.StealUncollected)

	-- Revenue accrual loop (§2.1.2) — server holds the amounts (§10.3.4);
	-- the plot attribute is display-only replication.
	task.spawn(function()
		while true do
			task.wait(Economy.REVENUE_TICK_SECONDS)
			-- §2.2 — day pays ½ the night rate, so night is ×2. The catalogue
			-- rates are night rates; the phase multiplier scales them. §2.3 —
			-- the per-player Full Moon multiplier (×5/×2) stacks on top; §7 —
			-- the server-wide event multiplier (storm ×0.5, VIP ×1.5) too.
			local phaseMultiplier = EventService.GetRevenueMultiplier()
			local eventMultiplier = EventService.GetEventRevenueMultiplier()
			for player, playerRuntime in runtime do
				if playerRuntime.ratePerMinute > 0 then
					local fullMoon = FullMoonService.GetRevenueMultiplier(player)
					local tickShare = Economy.REVENUE_TICK_SECONDS / 60
					playerRuntime.uncollected += playerRuntime.ratePerMinute * tickShare * phaseMultiplier * fullMoon * eventMultiplier
					PlotService.SetPlotAttribute(player, "Uncollected", math.floor(playerRuntime.uncollected))
				end
				-- §8.1 — Auto-Collect pass banks the pool each tick.
				if playerRuntime.autoCollect then
					local amount = math.floor(playerRuntime.uncollected)
					if amount > 0 then
						playerRuntime.uncollected -= amount
						EconomyService.Credit(player, amount, "collect")
						PlotService.SetPlotAttribute(player, "Uncollected", math.floor(playerRuntime.uncollected))
					end
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

	runtime[player] = { uncollected = 0, ratePerMinute = 0, multipliers = {}, autoCollect = false }
	refreshRate(player, data)
	setMaxZoneAttribute(player, data) -- §4 — client shows unlocked zones
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
