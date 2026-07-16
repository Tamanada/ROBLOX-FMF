--!strict
-- shared/Config/Equipment.luau — Blueprint §4 (catalogue v1 — BINDING values).
-- Zone 1 (Haad Rin, 13 items) ships in Sprint 1. Zone 2 (Ban Tai) lands in
-- Sprint 4, Zone 3 (Bottle Beach) in Sprint 6.
-- `revenuePerMinuteNight` is the §4 "Rev/min (nuit)" NIGHT rate (§2.2: day
-- runs at half once the day/night cycle exists).
-- §10.3.3 — replicated read-only; the server recomputes all authoritative
-- values from this module.

export type EquipmentDef = {
	id: string,
	displayName: string,
	tier: number,
	cost: number,
	revenuePerMinuteNight: number,
	hype: number,
	zone: number,
}

local function def(
	id: string,
	displayName: string,
	tier: number,
	cost: number,
	revenuePerMinuteNight: number,
	hype: number,
	zone: number
): EquipmentDef
	return table.freeze({
		id = id,
		displayName = displayName,
		tier = tier,
		cost = cost,
		revenuePerMinuteNight = revenuePerMinuteNight,
		hype = hype,
		zone = zone,
	})
end

-- §4 Zone 1 — Haad Rin (départ)
local list: { EquipmentDef } = {
	def("campfire", "Campfire", 0, 0, 2, 1, 1), -- offert
	def("smoothie_stand", "Smoothie Stand", 1, 100, 8, 2, 1),
	def("fruit_bucket_bar", "Fruit Bucket Bar", 1, 250, 14, 2, 1),
	def("beach_mat_lounge", "Beach Mat Lounge", 1, 400, 10, 3, 1),
	def("speaker_tower", "Bluetooth Speaker Tower", 2, 900, 22, 5, 1),
	def("uv_paint_station", "UV Paint Station", 2, 1500, 30, 6, 1),
	def("moon_swing_photo_spot", 'Photo Spot "Moon Swing"', 2, 2200, 26, 7, 1),
	def("juggling_circle", "Juggling Circle", 3, 4000, 45, 8, 1),
	def("fire_limbo", "Fire Limbo", 3, 6500, 60, 9, 1),
	def("small_dj_booth", "Small DJ Booth", 3, 10000, 85, 12, 1),
	def("lantern_release_deck", "Lantern Release Deck", 4, 18000, 110, 14, 1),
	def("neon_dance_floor", "Neon Dance Floor", 4, 30000, 160, 16, 1),
	def("main_stage_mk1", "Main Stage Mk I", 5, 55000, 260, 22, 1),
}

local byId: { [string]: EquipmentDef } = {}
for _, item in list do
	byId[item.id] = item
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
})
