--!strict
-- shared/Config/Equipment.luau — Blueprint §4 (catalogue v1, 34 items).
-- Populated in Sprint 1 (Zone 1, 13 items), Sprint 4 (Zone 2) and
-- Sprint 6 (Zone 3). Sprint 0: type definition + empty catalogue only.
-- §10.3.3 — replicated configs are read-only references; the server
-- recomputes every authoritative value.

export type EquipmentDef = {
	id: string,
	displayName: string,
	tier: number,
	cost: number,
	revenuePerMinuteNight: number,
	hype: number,
	zone: number,
}

local catalogue: { [string]: EquipmentDef } = {}

return table.freeze(catalogue)
