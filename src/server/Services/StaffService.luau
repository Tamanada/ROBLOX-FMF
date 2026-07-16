--!strict
-- server/Services/StaffService.luau — Blueprint §5 (staff collection).
-- Server-authoritative recruitment, assignment and fusion (§10.3):
--   * RequestRoll(bannerId): validate → debit Shells / Moon Shards → roll a
--     rarity from the BANNER odds (§5.1, displayed in-game) → grant a random
--     staff of that rarity. The client never sends amounts or results.
--   * RequestAssignStaff(index, zone): assign a staff to an unlocked zone
--     (zone 0 = unassign). Only assigned staff contribute effects (§5.2).
--   * RequestFuseStaff(staffId): consume 3 duplicates → 1 staff of the next
--     rarity (§5.2 duplicate sink). Legendary cannot fuse up.
-- Effects (§5.2) are recomputed on every change and PUSHED to BuildService
-- (revenue multiplier) and HypeService (Hype bonus) — keeping this service a
-- leaf (no other service requires it, so no require cycles).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Staff = require(ReplicatedStorage.Shared.Config.Staff)
local Net = require(ReplicatedStorage.Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local BuildService = require(script.Parent.BuildService)
local HypeService = require(script.Parent.HypeService)
local FullMoonService = require(script.Parent.FullMoonService)

local StaffService = {}

local RARITY_ORDER: { Types.StaffRarity } = { "Common", "Rare", "Epic", "Legendary" }

local rng = Random.new()
local started = false

--------------------------------------------------------------------------
-- Pure helpers (unit-tested in tests/Staff.spec.luau)
--------------------------------------------------------------------------

-- Maps a roll value in [0,1) to a rarity via the banner's cumulative odds.
-- Kept as a strongly-typed local (the result indexes rarity-keyed tables);
-- also exposed on the table for tests.
local function rollRarity(odds: { [Types.StaffRarity]: number }, rollValue: number): Types.StaffRarity
	local cumulative = 0
	local last: Types.StaffRarity = "Common"
	for _, rarity in RARITY_ORDER do
		local probability = odds[rarity]
		if probability ~= nil then
			last = rarity
			cumulative += probability
			if rollValue < cumulative then
				return rarity
			end
		end
	end
	return last -- rounding fallback (odds sum to 1)
end

function StaffService._rollRarity(odds: { [Types.StaffRarity]: number }, rollValue: number): Types.StaffRarity
	return rollRarity(odds, rollValue)
end

-- §5.2 — summed effects of the player's ASSIGNED staff.
function StaffService._staffBonuses(data: Types.PlayerData): { revenue: number, hype: number }
	local revenue, hype = 0, 0
	for _, entry in data.staff do
		if entry.assignedZone ~= nil then
			local effect = Staff.effects[entry.rarity]
			if effect ~= nil then
				revenue += effect.revenue
				hype += effect.hype
			end
		end
	end
	return { revenue = revenue, hype = hype }
end

-- Count of a given staff id in the roster (for the fusion threshold).
function StaffService._countById(data: Types.PlayerData, staffId: string): number
	local count = 0
	for _, entry in data.staff do
		if entry.staffId == staffId then
			count += 1
		end
	end
	return count
end

--------------------------------------------------------------------------
-- Internals
--------------------------------------------------------------------------

local function isIndex(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value >= 1
		and value == math.floor(value)
end

local function isZone(value: any): boolean
	-- 0 = unassign; otherwise a zone number.
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value >= 0
		and value == math.floor(value)
end

local function notify(player: Player, message: string)
	Net.Server.Fire("Notify", player, message)
end

local function grantStaff(data: Types.PlayerData, rarity: Types.StaffRarity): Staff.StaffDef?
	local pool = Staff.byRarity[rarity]
	if pool == nil or #pool == 0 then
		return nil
	end
	local staffId = pool[rng:NextInteger(1, #pool)]
	local entry: Types.StaffEntry = { staffId = staffId, rarity = rarity, assignedZone = nil }
	table.insert(data.staff, entry)
	return Staff.byId[staffId]
end

-- Serialises the roster for the client (display-only — §10.3.4).
local function pushStaffState(player: Player, data: Types.PlayerData)
	local roster = {}
	for index, entry in data.staff do
		table.insert(roster, {
			index = index,
			staffId = entry.staffId,
			rarity = entry.rarity,
			assignedZone = entry.assignedZone,
		})
	end
	Net.Server.Fire("StaffState", player, roster)
end

-- Recompute + push effects to BuildService/HypeService, then replicate roster.
local function applyEffects(player: Player, data: Types.PlayerData)
	local bonuses = StaffService._staffBonuses(data)
	BuildService.SetStaffMultiplier(player, data, 1 + bonuses.revenue)
	HypeService.SetStaffHype(player, data, bonuses.hype)
	pushStaffState(player, data)
end

--------------------------------------------------------------------------
-- Intent handlers (§10.3.1)
--------------------------------------------------------------------------

local function onRequestRoll(player: Player, bannerId: string)
	local banner = Staff.bannersById[bannerId]
	if banner == nil then
		notify(player, "Unknown recruitment banner.")
		return
	end

	local data = DataService.Get(player)
	if data == nil then
		return
	end

	local paid = if banner.costCurrency == "moonShards"
		then EconomyService.DebitMoonShards(player, banner.cost, "roll:" .. bannerId)
		else EconomyService.Debit(player, banner.cost, "roll:" .. bannerId)
	if not paid then
		local symbol = if banner.costCurrency == "moonShards" then "🌕" else "🐚"
		notify(player, `Not enough — {banner.displayName} costs {banner.cost} {symbol}.`)
		return
	end

	local rarity = rollRarity(banner.odds, rng:NextNumber())
	local def = grantStaff(data, rarity)
	if def == nil then
		return
	end

	applyEffects(player, data)
	notify(player, `Recruited {def.displayName} ({rarity})! ✨`)
end

local function onRequestAssign(player: Player, index: number, zone: number)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local entry = data.staff[index]
	if entry == nil then
		notify(player, "Unknown staff slot.")
		return
	end

	if zone == 0 then
		entry.assignedZone = nil
		applyEffects(player, data)
		return
	end

	-- §5.2 — staff assignable per unlocked zone only.
	local zoneKey = tostring(zone)
	if data.unlockedZones[zoneKey] ~= true then
		notify(player, "That zone is not unlocked yet.")
		return
	end
	entry.assignedZone = zoneKey
	applyEffects(player, data)
	notify(player, `Staff assigned to Zone {zone}.`)
end

local function onRequestFuse(player: Player, staffId: string)
	local def = Staff.byId[staffId]
	if def == nil then
		notify(player, "Unknown staff.")
		return
	end
	local nextRarity = Staff.fusionNext[def.rarity]
	if nextRarity == nil then
		notify(player, "Legendary staff cannot be fused further.")
		return
	end

	local data = DataService.Get(player)
	if data == nil then
		return
	end
	if StaffService._countById(data, staffId) < Economy.STAFF_FUSION_COUNT then
		notify(player, `Need {Economy.STAFF_FUSION_COUNT}× {def.displayName} to fuse.`)
		return
	end

	-- Consume the required duplicates (any assignment state), highest indices
	-- first so removal doesn't shift the survivors we still need.
	local removed = 0
	for i = #data.staff, 1, -1 do
		if removed >= Economy.STAFF_FUSION_COUNT then
			break
		end
		if data.staff[i].staffId == staffId then
			table.remove(data.staff, i)
			removed += 1
		end
	end

	local granted = grantStaff(data, nextRarity)
	applyEffects(player, data)
	if granted ~= nil then
		notify(player, `Fused into {granted.displayName} ({nextRarity})! 🔮`)
	end
end

--------------------------------------------------------------------------
-- Full Moon gate predicate (§2.3) — injected into FullMoonService
--------------------------------------------------------------------------

-- §2.3 — every unlocked zone needs at least one assigned staff.
function StaffService.HasStaffPerZone(player: Player): boolean
	local data = DataService.Get(player)
	if data == nil then
		return false
	end
	for zoneKey, unlocked in data.unlockedZones do
		if unlocked then
			local covered = false
			for _, entry in data.staff do
				if entry.assignedZone == zoneKey then
					covered = true
					break
				end
			end
			if not covered then
				return false
			end
		end
	end
	return true
end

--------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------

function StaffService.Init()
	if started then
		return
	end
	started = true

	Net.Server.Declare("StaffState")
	Net.Server.Handle("RequestRoll", { "string" }, onRequestRoll)
	Net.Server.Handle("RequestAssignStaff", { isIndex, isZone }, onRequestAssign)
	Net.Server.Handle("RequestFuseStaff", { "string" }, onRequestFuse)

	-- §2.3 — wire the real staff-per-zone gate into the Full Moon max multiplier.
	FullMoonService.SetStaffPredicate(StaffService.HasStaffPerZone)
end

function StaffService.TrackPlayer(player: Player, data: Types.PlayerData)
	applyEffects(player, data)
end

return StaffService
