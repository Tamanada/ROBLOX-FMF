--!strict
-- server/Services/EconomyService.luau — Blueprint §3, §10.3, §11.4.
-- Authoritative Shells wallet. ALL balance mutations go through
-- Credit()/Debit() — amounts are validated (finite, integer, >= 0), the
-- balance lives in the ProfileStore profile, and leaderstats replication
-- is display-only (§10.3.4).
-- §11.4 — anomaly audit: any player credited more than the theoretical
-- max per minute is flagged for review (never auto-banned).
-- Moon Shards operations arrive with FullMoonService (Sprint 3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local DataService = require(script.Parent.DataService)

local EconomyService = {}

-- Reasons that count toward stats.totalEarned (§10.4). Robux Shell packs
-- ("devproduct") are purchases, not earnings, so they're excluded.
local EARNED_REASONS: { [string]: boolean } = {
	collect = true,
	offline = true,
	quest = true, -- §6 daily visit quest reward
}

type AuditWindow = {
	windowStart: number,
	credited: number,
	theoreticalRatePerMinute: number,
}

local audit: { [Player]: AuditWindow } = {}

-- Audit headroom: collect batching means a single credit can legitimately
-- bundle several minutes of accrual.
local AUDIT_RATE_HEADROOM = 3
local AUDIT_FLAT_HEADROOM = 500

local function isValidAmount(amount: number): boolean
	return type(amount) == "number"
		and amount == amount -- NaN
		and amount ~= math.huge
		and amount >= 0
		and amount == math.floor(amount) -- Shells are always integers
end

local function updateStat(player: Player, statName: string, value: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = if leaderstats ~= nil then leaderstats:FindFirstChild(statName) else nil
	if stat ~= nil and stat:IsA("IntValue") then
		stat.Value = value
	end
end

local function updateDisplay(player: Player, data: Types.PlayerData)
	updateStat(player, "Shells", data.shells)
end

local function auditCredit(player: Player, amount: number)
	local window = audit[player]
	if window == nil then
		return
	end

	local now = os.clock()
	if now - window.windowStart >= 60 then
		window.windowStart = now
		window.credited = 0
	end
	window.credited += amount

	-- §2.3 — the Full Moon legitimately pays up to ×5 the base rate, so the
	-- ceiling must include that envelope on top of the collect-batching headroom
	-- (else top festivals trip the flag every Full Moon). Still catches
	-- order-of-magnitude injection exploits (§11.4).
	local ceiling = window.theoreticalRatePerMinute * AUDIT_RATE_HEADROOM * Economy.FULL_MOON_REVENUE_MULTIPLIER_MAX
		+ AUDIT_FLAT_HEADROOM
	if window.credited > ceiling then
		-- §11.4 — flag, audit before any action.
		warn(
			`[FMF][AUDIT] {player.Name} ({player.UserId}) credited {window.credited} Shells `
				.. `in <60s (theoretical rate {math.floor(window.theoreticalRatePerMinute)}/min) — review required`
		)
	end
end

function EconomyService.Init() end

function EconomyService.SetupPlayer(player: Player, data: Types.PlayerData)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local shells = Instance.new("IntValue")
	shells.Name = "Shells"
	shells.Value = data.shells
	shells.Parent = leaderstats

	-- §3.1 — Moon Shards: hard, earn-only currency (never sold for Robux).
	local moonShards = Instance.new("IntValue")
	moonShards.Name = "MoonShards"
	moonShards.Value = data.moonShards
	moonShards.Parent = leaderstats

	leaderstats.Parent = player

	audit[player] = {
		windowStart = os.clock(),
		credited = 0,
		theoreticalRatePerMinute = 0,
	}
end

-- BuildService reports the current plot revenue rate so the audit ceiling
-- tracks what the player can legitimately earn.
function EconomyService.SetTheoreticalRate(player: Player, ratePerMinute: number)
	local window = audit[player]
	if window ~= nil then
		window.theoreticalRatePerMinute = ratePerMinute
	end
end

function EconomyService.GetShells(player: Player): number?
	local data = DataService.Get(player)
	return if data ~= nil then data.shells else nil
end

-- §2.3 — after a direct balance change (e.g. Prestige reset), refresh the
-- display from the profile.
function EconomyService.RefreshDisplay(player: Player)
	local data = DataService.Get(player)
	if data ~= nil then
		updateDisplay(player, data)
		updateStat(player, "MoonShards", data.moonShards)
	end
end

function EconomyService.GetMoonShards(player: Player): number?
	local data = DataService.Get(player)
	return if data ~= nil then data.moonShards else nil
end

-- §3.1 — Moon Shards are earn-only (Full Moon events, achievements, prestige).
-- No Debit path yet — spending arrives with StaffService/cosmetics (S4+).
function EconomyService.CreditMoonShards(player: Player, amount: number, reason: string): boolean
	if not isValidAmount(amount) then
		warn(`[EconomyService] invalid moon shard credit ({tostring(amount)}) for {player.Name} [{reason}]`)
		return false
	end
	if amount == 0 then
		return true
	end

	local data = DataService.Get(player)
	if data == nil then
		return false
	end

	data.moonShards += amount
	updateStat(player, "MoonShards", data.moonShards)
	return true
end

-- §3.1 — spend earned Moon Shards (staff Premium rolls, cosmetics). Earn-only
-- refers to Robux (never bought); spending in-game is intended.
function EconomyService.DebitMoonShards(player: Player, amount: number, reason: string): boolean
	if not isValidAmount(amount) then
		warn(`[EconomyService] invalid moon shard debit ({tostring(amount)}) for {player.Name} [{reason}]`)
		return false
	end

	local data = DataService.Get(player)
	if data == nil then
		return false
	end
	if data.moonShards < amount then
		return false
	end

	data.moonShards -= amount
	updateStat(player, "MoonShards", data.moonShards)
	return true
end

function EconomyService.Credit(player: Player, amount: number, reason: string): boolean
	if not isValidAmount(amount) then
		warn(`[EconomyService] invalid credit amount ({tostring(amount)}) for {player.Name} [{reason}]`)
		return false
	end
	if amount == 0 then
		return true
	end

	local data = DataService.Get(player)
	if data == nil then
		return false
	end

	data.shells += amount
	if EARNED_REASONS[reason] then
		data.stats.totalEarned += amount
	end

	auditCredit(player, amount)
	updateDisplay(player, data)
	return true
end

-- Returns false when the amount is invalid OR the balance is insufficient —
-- callers must treat false as "nothing happened".
function EconomyService.Debit(player: Player, amount: number, reason: string): boolean
	if not isValidAmount(amount) then
		warn(`[EconomyService] invalid debit amount ({tostring(amount)}) for {player.Name} [{reason}]`)
		return false
	end

	local data = DataService.Get(player)
	if data == nil then
		return false
	end
	if data.shells < amount then
		return false
	end

	data.shells -= amount
	updateDisplay(player, data)
	return true
end

function EconomyService.CleanupPlayer(player: Player)
	audit[player] = nil
end

return EconomyService
