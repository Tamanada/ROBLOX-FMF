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

-- One of "Common" | "Rare" | "Epic" | "Legendary". Kept as `string` (not a
-- singleton union) because Luau widens singleton literals to `string` once they
-- live in frozen config tables — the union would fight every config read.
-- Validity is enforced at runtime against Config/Staff membership.
export type StaffRarity = string

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

-- §6 — aggregate festival rating (1-5 stars) received from visitors.
export type FestivalRating = {
	sum: number,
	count: number,
}

-- §6 — per-day social state (reset when `day` changes): distinct hosts visited
-- (daily "Visit 3" quest), hosts already rated today (1 vote/host/day), and
-- whether today's visit quest reward was claimed.
export type SocialState = {
	day: number,
	visitedHosts: { [string]: boolean },
	ratedHosts: { [string]: boolean },
	questClaimed: boolean,
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
	-- §4 — unlocked zones ("1" always unlocked). Added in schema v2 (S4).
	unlockedZones: { [string]: boolean },
	-- §8.4.3 — granted Developer Product PurchaseIds (idempotent ProcessReceipt).
	-- §6 — festival rating + daily social state. All added in schema v3 (S5).
	purchaseHistory: { [string]: boolean },
	festivalRating: FestivalRating,
	social: SocialState,
	lastSeen: number,
}

return {}
