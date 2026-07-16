--!strict
-- shared/Config/Events.luau — Blueprint §7 (événements & monde vivant).
-- Populated in Sprint 3 (Full Moon) and Sprint 4 (météo, singes, VIP).
-- Sprint 0: type definition only.

export type EventDef = {
	id: string,
	displayName: string,
	-- average seconds between occurrences (nil = clock-driven, e.g. Full Moon §10.5)
	averageIntervalSeconds: number?,
}

local catalogue: { [string]: EventDef } = {}

return table.freeze(catalogue)
