--!strict
-- shared/Config/Staff.luau — Blueprint §5 (staff collection).
-- Populated in Sprint 4 (Roadmap §12). Sprint 0: type definition only.
-- §5.1 / §11.2 — drop rates are displayed in-game; no direct Robux rolls.

export type StaffDef = {
	id: string,
	displayName: string,
	rarity: "Common" | "Rare" | "Epic" | "Legendary",
	description: string,
}

local catalogue: { [string]: StaffDef } = {}

return table.freeze(catalogue)
