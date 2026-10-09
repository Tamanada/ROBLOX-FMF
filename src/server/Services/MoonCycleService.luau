--!strict
-- server/Services/MoonCycleService.luau — Blueprint §14.4.
-- Fait tourner le cycle lunaire accéléré côté serveur : détecte les
-- transitions de phase (math pure dans shared/Util/MoonCycle, dérivée du
-- même os.time() % période que FullMoonService §10.5), réplique la phase
-- courante en attributs Workspace (display-only §10.3.4) et pousse un
-- événement de transition aux clients. Les venues consommeront GetPhase /
-- GetNextPhaseAt dans un sprint ultérieur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MoonCycle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("MoonCycle"))
local Net = require(ReplicatedStorage.Shared.Util.Net)

local MoonCycleService = {}

local ATTR_PHASE = "FMF_MoonPhase"
local ATTR_ENDS_AT = "FMF_MoonPhaseEndsAt"

local started = false

-- Passthroughs serveur (les autres services n'ont pas à connaître le module).
function MoonCycleService.GetPhase(): MoonCycle.PhaseInfo
	return MoonCycle.GetPhase(nil)
end

function MoonCycleService.GetNextPhaseAt(phase: string): number
	return MoonCycle.GetNextPhaseAt(phase, nil)
end

local function publish(info: MoonCycle.PhaseInfo)
	Workspace:SetAttribute(ATTR_PHASE, info.phase)
	Workspace:SetAttribute(ATTR_ENDS_AT, info.endsAt)
end

function MoonCycleService.Init()
	if started then
		return
	end
	started = true

	Net.Server.Declare("MoonPhaseChanged")

	local current = MoonCycle.GetPhase(nil)
	publish(current)

	task.spawn(function()
		while true do
			task.wait(1)
			local info = MoonCycle.GetPhase(nil)
			if info.phase ~= current.phase or info.startsAt ~= current.startsAt then
				current = info
				publish(info)
				Net.Server.FireAll("MoonPhaseChanged", info.phase, info.endsAt)
			end
		end
	end)
end

return MoonCycleService
