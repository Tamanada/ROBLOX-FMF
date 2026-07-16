--!strict
-- server/Services/HypeService.luau — Blueprint §3.3 (ressource maîtresse).
-- v2 (Sprint 2): Hype = clamp(equipmentBonus + modifier, 0, 100), where
--   * equipmentBonus = Σ hype of non-broken equipment (v1),
--   * modifier       = runtime cleanliness/decay accumulator (§3.3):
--       + CLEANUP_HYPE_BONUS when the Beach Cleanup Flash is completed (§7),
--       − HYPE_DECAY_PER_CYCLE per cycle if the beach is dirty OR any
--         equipment is broken and unrepaired.
-- The modifier is EPHEMERAL (session runtime only) — it is not persisted, so
-- no PlayerData schema bump is needed. `data.hype` stores the computed value
-- and is replicated as a display-only player attribute (§10.3.4).
-- Later versions per §3.3: staff actifs (S4), décor, uptime musique,
-- éligibilité multiplicateur Full Moon (S3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)

local HypeService = {}

-- Per-player cleanliness/decay accumulator (default 0). Cleared on leave.
local modifiers: { [Player]: number } = {}
-- §5.2 — per-player Hype from assigned staff (pushed by StaffService, S4).
local staffHype: { [Player]: number } = {}
-- §8.2 — timed Hype Boost product (+N for a while). Token guards overlap.
local boosts: { [Player]: number } = {}
local boostToken: { [Player]: number } = {}

--------------------------------------------------------------------------
-- Pure helpers (unit-tested in tests/World.spec.luau)
--------------------------------------------------------------------------

-- §3.3 — the accumulator is bounded before it folds into the 0-100 clamp.
function HypeService._clampModifier(value: number): number
	return math.clamp(value, Economy.HYPE_MODIFIER_MIN, Economy.HYPE_MODIFIER_MAX)
end

-- §3.3 — final Hype from its components (equipment + cleanliness/decay + staff
-- + timed boost).
function HypeService._composeHype(equipmentBonus: number, modifier: number, staff: number, boost: number): number
	return math.clamp(equipmentBonus + modifier + staff + boost, 0, 100)
end

-- Σ hype of non-broken equipment (broken equipment contributes 0 — §4).
function HypeService._equipmentBonus(data: Types.PlayerData): number
	local total = 0
	local slot = data.plots[Economy.MAIN_PLOT_SLOT]
	if slot ~= nil then
		for _, entry in slot.equipment do
			if not entry.broken then
				local def = Equipment.byId[entry.id]
				if def ~= nil then
					total += def.hype
				end
			end
		end
	end
	return total
end

--------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------

function HypeService.Init() end

function HypeService.CleanupPlayer(player: Player)
	modifiers[player] = nil
	staffHype[player] = nil
	boosts[player] = nil
	boostToken[player] = nil
end

--------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------

-- Recomputes the festival's Hype from equipment + the runtime modifier and
-- writes it to the profile + the replicated attribute. Returns the new score.
function HypeService.Recompute(player: Player, data: Types.PlayerData): number
	local hype = HypeService._composeHype(
		HypeService._equipmentBonus(data),
		modifiers[player] or 0,
		staffHype[player] or 0,
		boosts[player] or 0
	)
	data.hype = hype
	player:SetAttribute("Hype", hype)
	return hype
end

-- §8.2 — Hype Boost product: +amount for `duration` seconds, then it lapses.
-- The token guards against an earlier boost's timer clearing a newer one.
function HypeService.AddTimedBoost(player: Player, data: Types.PlayerData, amount: number, duration: number)
	boosts[player] = amount
	local token = (boostToken[player] or 0) + 1
	boostToken[player] = token
	HypeService.Recompute(player, data)

	task.delay(duration, function()
		if boostToken[player] == token then
			boosts[player] = nil
			HypeService.Recompute(player, data)
		end
	end)
end

-- §5.2 — StaffService pushes the summed Hype of assigned staff here, then this
-- recomputes. Kept separate from the equipment sum so staff can be re-derived
-- without touching the base.
function HypeService.SetStaffHype(player: Player, data: Types.PlayerData, bonus: number)
	staffHype[player] = bonus
	HypeService.Recompute(player, data)
end

-- §7 — Beach Cleanup Flash success: bump the cleanliness modifier by +bonus
-- (bounded), then recompute. Called by EventService.
function HypeService.AddCleanupBonus(player: Player, data: Types.PlayerData, bonus: number)
	modifiers[player] = HypeService._clampModifier((modifiers[player] or 0) + bonus)
	HypeService.Recompute(player, data)
end

-- §3.3 — per-cycle decay: −HYPE_DECAY_PER_CYCLE if the beach is dirty OR any
-- equipment is broken. A clean, fully-repaired festival takes no penalty.
-- Called by EventService at each cycle boundary.
function HypeService.ApplyCycleDecay(player: Player, data: Types.PlayerData, isDirty: boolean, hasBroken: boolean)
	if isDirty or hasBroken then
		modifiers[player] = HypeService._clampModifier((modifiers[player] or 0) - Economy.HYPE_DECAY_PER_CYCLE)
		HypeService.Recompute(player, data)
	end
end

function HypeService.Get(data: Types.PlayerData): number
	return data.hype
end

return HypeService
