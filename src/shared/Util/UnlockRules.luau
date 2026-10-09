--!strict
-- shared/Util/UnlockRules.luau — Blueprint §14.2.
-- Évaluateur PUR des règles d'unlock de zones : aucune dépendance Roblox,
-- unit-testé dans tests/Island.spec.luau. L'enforcement (téléports,
-- embarquements) reste dans UnlockService côté serveur (§10.3). Les zones
-- débloquées sont recalculées depuis les faits persistés (§14.6), jamais
-- stockées en dur.

local UnlockRules = {}

export type IslandProgress = {
	completedVenues: { [string]: boolean },
	zoneVisits: { [string]: number },
}

export type Requirement = {
	kind: string,
	zone: string?,
	count: number?,
}

local function countCompletedInZone(
	progress: IslandProgress,
	zoneVenues: { string }?
): number
	if zoneVenues == nil then
		return 0
	end
	local total = 0
	for _, venueId in zoneVenues do
		if progress.completedVenues[venueId] == true then
			total += 1
		end
	end
	return total
end

-- Une exigence satisfaite ?
function UnlockRules.isRequirementMet(
	requirement: Requirement,
	progress: IslandProgress,
	completableVenuesByZone: { [string]: { string } }
): boolean
	if requirement.kind == "always" then
		return true
	elseif requirement.kind == "venuesInZone" then
		local zone = requirement.zone
		local needed = requirement.count or 0
		if zone == nil then
			return false
		end
		return countCompletedInZone(progress, completableVenuesByZone[zone]) >= needed
	elseif requirement.kind == "zoneVisited" then
		local zone = requirement.zone
		local needed = requirement.count or 1
		if zone == nil then
			return false
		end
		return (progress.zoneVisits[zone] or 0) >= needed
	end
	-- Exigence inconnue = verrouillé (fail-closed, jamais fail-open).
	return false
end

-- Une zone est débloquée quand TOUTES ses exigences sont satisfaites.
-- Une zone sans règle est verrouillée (fail-closed).
function UnlockRules.isZoneUnlocked(
	zoneId: string,
	rules: { [string]: { Requirement } },
	progress: IslandProgress,
	completableVenuesByZone: { [string]: { string } }
): boolean
	local requirements = rules[zoneId]
	if requirements == nil then
		return false
	end
	for _, requirement in requirements do
		if not UnlockRules.isRequirementMet(requirement, progress, completableVenuesByZone) then
			return false
		end
	end
	return true
end

return UnlockRules
