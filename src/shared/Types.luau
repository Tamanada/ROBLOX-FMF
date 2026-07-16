--!strict
-- shared/Types.luau — schéma de données v1 (Blueprint §10.4)
-- DataStores cannot persist CFrame values: equipment CFrames are serialized
-- as 12 numeric components, RELATIVE to the plot origin (plot-agnostic saves).

export type SerializedCFrame = { number }

-- §2.2 — the two phases of the 16-minute day/night cycle. Replicated to
-- clients as a Workspace attribute so ambiance (§9) tracks the server clock.
export type CyclePhase = "Day" | "Night"

export type EquipmentInstance = {
	id: string,
	level: number,
	cframe: SerializedCFrame,
	broken: boolean,
}

export type PlotData = {
	equipment: { EquipmentInstance },
}

export type StaffRarity = "Common" | "Rare" | "Epic" | "Legendary"

export type StaffEntry = {
	staffId: string,
	rarity: StaffRarity,
	assignedZone: string?,
}

export type PlayerStats = {
	totalEarned: number,
	fullMoonsAttended: number,
	visits: number,
}

export type PlayerData = {
	dataVersion: number,
	shells: number,
	moonShards: number,
	hype: number,
	prestigeCount: number,
	plots: { [string]: PlotData },
	staff: { StaffEntry },
	stats: PlayerStats,
	passes: { [string]: boolean },
	lastSeen: number,
}

return {}
