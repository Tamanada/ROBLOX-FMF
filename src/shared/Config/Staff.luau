--!strict
-- shared/Config/Staff.luau — Blueprint §5 (staff collection).
-- §5.1 / §11.2 — drop rates are DISPLAYED in-game (regulated-gacha
-- transparency); no direct Robux rolls. The client reads BANNERS.odds to show
-- exact probabilities, so this module is the single source of truth for them.
-- §5.2 — rarity effects. Zone-scoped vs global bonuses collapse to the plot
-- rate in the current single-plot rate model (documented approximation, to be
-- refined when per-zone rate splitting lands); Legendary's global revenue +
-- Hype are applied. Legendary "+1 min Full Moon duration" (§5.2) is deferred —
-- it interacts with the §10.5 global-sync clock and is a follow-up.
--
-- Per-banner odds are a Sprint 4 amendment (2026-07-17): §5 gives the overall
-- rarity table (60/30/9/1) and two banners (500 Shells C/R, 5 Moon Shards
-- Epic-min) but not the per-banner split — defined here and shown in-game.

-- "Common" | "Rare" | "Epic" | "Legendary" — plain `string` (see the note in
-- shared/Types.luau on why singleton unions can't survive frozen config tables).
export type StaffRarity = string

export type StaffDef = {
	id: string,
	displayName: string,
	rarity: StaffRarity,
	description: string,
}

export type RarityEffect = {
	-- Fractional revenue bonus per assigned staff (added into the plot rate
	-- multiplier) and flat Hype bonus (§5.2).
	revenue: number,
	hype: number,
}

export type BannerDef = {
	id: string,
	displayName: string,
	-- "shells" | "moonShards" (plain string — same widening reason).
	costCurrency: string,
	cost: number,
	-- rarity -> probability; MUST sum to 1 and every rarity must have a roster.
	odds: { [StaffRarity]: number },
}

-- §5.2 — effect magnitudes by rarity.
local EFFECTS: { [StaffRarity]: RarityEffect } = {
	Common = { revenue = 0.05, hype = 0 },
	Rare = { revenue = 0.10, hype = 3 },
	Epic = { revenue = 0.20, hype = 8 },
	Legendary = { revenue = 0.15, hype = 15 },
}

-- §5.2 — fusion chain: 3 duplicates → 1 of the next rarity (Legendary caps).
local FUSION_NEXT: { [StaffRarity]: StaffRarity } = {
	Common = "Rare",
	Rare = "Epic",
	Epic = "Legendary",
}

local function def(id: string, displayName: string, rarity: StaffRarity, description: string): StaffDef
	return table.freeze({
		id = id,
		displayName = displayName,
		rarity = rarity,
		description = description,
	})
end

-- §5.2 — roster (named examples + variety for the fusion sink).
local list: { StaffDef } = {
	-- Common (auto-clean / single-equipment boost)
	def("bartender", "Bartender", "Common", "Pours smoothies a little faster."),
	def("cleaner", "Cleaner", "Common", "Tidies the beach between sets."),
	def("beach_vendor", "Beach Vendor", "Common", "Sells fruit buckets along the sand."),
	def("ticket_taker", "Ticket Taker", "Common", "Welcomes arrivals at the pier."),
	-- Rare (+zone revenue, +Hype)
	def("fire_juggler", "Fire Juggler", "Rare", "Draws a crowd with spinning flames."),
	def("percussionist", "Percussionist", "Rare", "Keeps the tribal rhythm going."),
	def("poi_spinner", "Poi Spinner", "Rare", "Glowing poi trails light the night."),
	def("bongo_player", "Bongo Player", "Rare", "Sunset bongo circles by the fire."),
	-- Epic (+zone revenue, +Hype, aura)
	def("resident_dj", "Resident DJ", "Epic", "Reads the crowd and lifts the set."),
	def("fire_show_master", "Fire Show Master", "Epic", "Headlines the nightly fire show."),
	def("aerial_dancer", "Aerial Silk Dancer", "Epic", "Soars above the stage on silks."),
	-- Legendary (island lore — no real people)
	def("moon_shaman", "The Moon Shaman", "Legendary", "Blesses the festival under the full moon."),
	def("island_legend", "Island Legend", "Legendary", "The spirit of a hundred moon parties."),
}

local byId: { [string]: StaffDef } = {}
local byRarity: { [StaffRarity]: { string } } = {
	Common = {},
	Rare = {},
	Epic = {},
	Legendary = {},
}
for _, item in list do
	byId[item.id] = item
	table.insert(byRarity[item.rarity], item.id)
end

-- §5.1 — the two recruitment banners with in-game-displayed odds.
local BANNERS: { BannerDef } = {
	table.freeze({
		id = "standard",
		displayName = "Standard Roll",
		costCurrency = "shells",
		cost = 500,
		odds = table.freeze({ Common = 0.75, Rare = 0.25 }),
	}),
	table.freeze({
		id = "premium",
		displayName = "Premium Roll",
		costCurrency = "moonShards",
		cost = 5,
		-- Epic guaranteed minimum (§5.1).
		odds = table.freeze({ Epic = 0.9, Legendary = 0.1 }),
	}),
}

local bannersById: { [string]: BannerDef } = {}
for _, banner in BANNERS do
	bannersById[banner.id] = banner
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
	byRarity = table.freeze(byRarity),
	effects = table.freeze(EFFECTS),
	fusionNext = table.freeze(FUSION_NEXT),
	banners = table.freeze(BANNERS),
	bannersById = table.freeze(bannersById),
})
