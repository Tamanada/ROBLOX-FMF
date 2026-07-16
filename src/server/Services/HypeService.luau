--!strict
-- server/Services/HypeService.luau — Blueprint §3.3 (ressource maîtresse).
-- v1 (Sprint 1): Hype = clamp(somme des bonus Hype des équipements posés
-- non cassés, 0, 100) — server-computed, replicated as a display-only
-- player attribute (§10.3.4).
-- Later versions per §3.3: propreté (S2), staff actifs (S4), décor,
-- uptime musique, decay −5/cycle (S2, avec le cycle jour/nuit),
-- éligibilité multiplicateur Full Moon (S3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)

local HypeService = {}

function HypeService.Init() end

-- Recomputes the festival's Hype from its equipment and writes it to the
-- profile + the replicated attribute. Returns the new score.
function HypeService.Recompute(player: Player, data: Types.PlayerData): number
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

	local hype = math.clamp(total, 0, 100)
	data.hype = hype
	player:SetAttribute("Hype", hype)
	return hype
end

function HypeService.Get(data: Types.PlayerData): number
	return data.hype
end

return HypeService
