--!strict
-- shared/Config/Unlocks.luau — Blueprint §14.2 (unlock progressif v1).
-- Un seul module à régler. Chaque zone porte une liste d'exigences TOUTES
-- requises (ET logique). Évaluation pure dans shared/Util/UnlockRules.luau,
-- enforcement serveur dans UnlockService (§10.3).

export type Requirement = {
	kind: string, -- "always" | "venuesInZone" | "zoneVisited"
	zone: string?,
	count: number?,
}

local function req(kind: string, zone: string?, count: number?): Requirement
	return table.freeze({ kind = kind, zone = zone, count = count })
end

local rules: { [string]: { Requirement } } = {
	-- §14.2 — Haad Rin : toujours débloquée.
	haad_rin = table.freeze({ req("always", nil, nil) }),
	-- 2 des 4 venues de Haad Rin complétées.
	baan_tai = table.freeze({ req("venuesInZone", "haad_rin", 2) }),
	-- 1 venue Haad Rin + 1 venue Baan Tai.
	thong_sala = table.freeze({
		req("venuesInZone", "haad_rin", 1),
		req("venuesInZone", "baan_tai", 1),
	}),
	-- Les 4 venues de Haad Rin.
	haad_yuan = table.freeze({ req("venuesInZone", "haad_rin", 4) }),
	-- Avoir visité Haad Yuan au moins une fois.
	haad_thien = table.freeze({ req("zoneVisited", "haad_yuan", 1) }),
}

return table.freeze({
	rules = table.freeze(rules),
})
