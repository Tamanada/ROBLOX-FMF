--!strict
-- server/Services/FullMoonService.luau — Blueprint §2.3, §3.1, §10.5.
-- The Full Moon is the retention centrepiece:
--   * Global, UTC-synced clock (§10.5): the event is active when
--     os.time() % PERIOD < DURATION. Because every server derives the state
--     from the same UTC epoch, they converge with NO MessagingService in v1
--     (cross-server announcements/leaderboards are v1.1). This is what makes
--     the event "synchronised across all servers" (Roadmap §12 DoD) — the
--     helpers below are pure and unit-tested against fixed timestamps, which
--     is the deterministic proof of that synchronisation.
--   * Revenue multiplier (§2.3): ×5 when the max-gate is met, else ×2. Read
--     per player by BuildService; stacks on top of the day/night multiplier.
--   * Max-gate (§2.3): Hype ≥ 80 % + all equipment repaired + ≥1 staff active
--     per unlocked zone. The staff sub-condition defaults satisfied until
--     StaffService lands (S4) — see the Blueprint §2.3 amendment.
--   * Reward (§2.3 amendment): Moon Shards granted at event end to every
--     present player — MAX if eligible, BASE otherwise (§3.1 earn-only).
--   * Sky transform (§9): replicated Workspace attributes drive client VFX.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Net = require(ReplicatedStorage.Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local FullMoonService = {}

-- Replicated to clients for the sky transform (§9). Read-only display channel.
local ATTR_ACTIVE = "FMF_FullMoonActive"
local ATTR_ENDS_AT = "FMF_FullMoonEndsAt"

local tracked: { [Player]: boolean } = {}
local active = false
local started = false

--------------------------------------------------------------------------
-- Pure helpers (unit-tested in tests/FullMoon.spec.luau — the sync proof)
--------------------------------------------------------------------------

-- §10.5 — the event is active during the first DURATION seconds of every
-- PERIOD window, aligned to UTC (period boundaries are UTC multiples).
function FullMoonService._isActiveAt(unixTime: number): boolean
	return unixTime % Economy.FULL_MOON_PERIOD_SECONDS < Economy.FULL_MOON_DURATION_SECONDS
end

-- Seconds until the current event ends (0 when not active).
function FullMoonService._secondsRemainingAt(unixTime: number): number
	local intoWindow = unixTime % Economy.FULL_MOON_PERIOD_SECONDS
	if intoWindow < Economy.FULL_MOON_DURATION_SECONDS then
		return Economy.FULL_MOON_DURATION_SECONDS - intoWindow
	end
	return 0
end

-- Seconds until the next event starts (0 when already active).
function FullMoonService._secondsUntilNextAt(unixTime: number): number
	local intoWindow = unixTime % Economy.FULL_MOON_PERIOD_SECONDS
	if intoWindow < Economy.FULL_MOON_DURATION_SECONDS then
		return 0
	end
	return Economy.FULL_MOON_PERIOD_SECONDS - intoWindow
end

-- §2.3 — revenue multiplier: 1 outside the event, ×5 if eligible, else ×2.
function FullMoonService._revenueMultiplier(isActive: boolean, eligible: boolean): number
	if not isActive then
		return 1
	end
	return if eligible then Economy.FULL_MOON_REVENUE_MULTIPLIER_MAX else Economy.FULL_MOON_REVENUE_MULTIPLIER_REDUCED
end

-- §2.3 amendment — Moon Shards reward per event.
function FullMoonService._rewardFor(eligible: boolean): number
	return if eligible then Economy.FULL_MOON_SHARDS_MAX else Economy.FULL_MOON_SHARDS_BASE
end

--------------------------------------------------------------------------
-- Max-gate eligibility (§2.3)
--------------------------------------------------------------------------

local function allEquipmentRepaired(data: Types.PlayerData): boolean
	local slot = data.plots[Economy.MAIN_PLOT_SLOT]
	if slot == nil then
		return true
	end
	for _, entry in slot.equipment do
		if entry.broken then
			return false
		end
	end
	return true
end

-- §2.3 — staff-per-zone predicate, injected by StaffService (S4) so the gate
-- doesn't require StaffService (which requires FullMoonService). Defaults
-- satisfied until wired (Blueprint §2.3 amendment).
local staffPredicate: (player: Player) -> boolean = function()
	return true
end

function FullMoonService.SetStaffPredicate(predicate: (player: Player) -> boolean)
	staffPredicate = predicate
end

local function isEligible(player: Player): boolean
	local data = DataService.Get(player)
	if data == nil then
		return false
	end
	return data.hype >= Economy.FULL_MOON_HYPE_THRESHOLD and allEquipmentRepaired(data) and staffPredicate(player)
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------

function FullMoonService.IsActive(): boolean
	return active
end

-- BuildService stacks this on the day/night multiplier each accrual tick.
function FullMoonService.GetRevenueMultiplier(player: Player): number
	return FullMoonService._revenueMultiplier(active, isEligible(player))
end

--------------------------------------------------------------------------
-- Event transitions
--------------------------------------------------------------------------

local function replicate(now: number)
	Workspace:SetAttribute(ATTR_ACTIVE, active)
	if active then
		Workspace:SetAttribute(ATTR_ENDS_AT, now + math.floor(FullMoonService._secondsRemainingAt(now) + 0.5))
	else
		Workspace:SetAttribute(ATTR_ENDS_AT, now + math.floor(FullMoonService._secondsUntilNextAt(now) + 0.5))
	end
end

local function onEventStarted(now: number)
	active = true
	replicate(now)
	Net.Server.FireAll("Notify", "🌕 FULL MOON RISES — the island transforms!")
end

-- §2.3 — award Moon Shards to every present player, then bank immediately so a
-- crash can't rob a Full Moon reward.
local function onEventEnded(now: number)
	active = false
	replicate(now)
	for player in tracked do
		local data = DataService.Get(player)
		if data ~= nil then
			local reward = FullMoonService._rewardFor(isEligible(player))
			EconomyService.CreditMoonShards(player, reward, "fullmoon")
			data.stats.fullMoonsAttended += 1
			DataService.SaveNow(player)
			Net.Server.Fire("Notify", player, `Full Moon over — +{reward} 🌕 Moon Shards!`)
		end
	end
end

--------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------

function FullMoonService.Init()
	if started then
		return
	end
	started = true

	-- Adopt the current UTC state without awarding (a server booted mid-event
	-- still lets present players collect at the genuine end).
	local now = os.time()
	active = FullMoonService._isActiveAt(now)
	replicate(now)

	-- Clock driver: 1 s granularity is ample for a 10-minute event.
	task.spawn(function()
		while true do
			task.wait(1)
			local t = os.time()
			local shouldBeActive = FullMoonService._isActiveAt(t)
			if shouldBeActive ~= active then
				if shouldBeActive then
					onEventStarted(t)
				else
					onEventEnded(t)
				end
			end
		end
	end)
end

function FullMoonService.TrackPlayer(player: Player)
	tracked[player] = true
end

function FullMoonService.UntrackPlayer(player: Player)
	tracked[player] = nil
end

return FullMoonService
