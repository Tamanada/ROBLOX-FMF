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
local DataService = require(script.Parent.DataService)

local EconomyService = {}

-- Reasons that count toward stats.totalEarned (§10.4). Robux Shell packs
-- (Sprint 5) are purchases, not earnings.
local EARNED_REASONS: { [string]: boolean } = {
	collect = true,
	offline = true,
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

local function updateDisplay(player: Player, data: Types.PlayerData)
	local leaderstats = player:FindFirstChild("leaderstats")
	local shells = if leaderstats ~= nil then leaderstats:FindFirstChild("Shells") else nil
	if shells ~= nil and shells:IsA("IntValue") then
		shells.Value = data.shells
	end
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

	local ceiling = window.theoreticalRatePerMinute * AUDIT_RATE_HEADROOM + AUDIT_FLAT_HEADROOM
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
