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

	-- §4 Zone 2 — Ban Tai (déblocage : 75 000 Shells + Hype 60).
	-- 13 items, tiers 3-6, coûts 20k→400k. The Blueprint names 7 items and
	-- gives ranges only; the full table (6 added names + per-item numbers,
	-- following §3.2 cost/revenue growth) is a Sprint 4 amendment (2026-07-17).
	def("pier_boat_taxi_upgrade", "Pier & Boat Taxi Upgrade", 3, 20000, 95, 10, 2),
	def("coconut_cafe", "Coconut Café", 3, 28000, 120, 11, 2),
	def("glow_body_art_studio", "Glow Body Art Studio", 3, 38000, 150, 12, 2),
	def("trampoline_net", "Trampoline Net", 4, 52000, 190, 14, 2),
	def("beach_volley_arena", "Beach Volley Arena", 4, 70000, 235, 15, 2),
	def("silent_disco_dome", "Silent Disco Dome", 4, 95000, 290, 17, 2),
	def("hammock_grove", "Hammock Grove", 4, 125000, 350, 16, 2),
	def("drone_light_show_pad", "Drone Light Show Pad", 5, 160000, 430, 20, 2),
	def("tiki_torch_promenade", "Tiki Torch Promenade", 5, 200000, 520, 21, 2),
	def("lantern_river_walk", "Lantern River Walk", 5, 250000, 620, 23, 2),
	def("neon_surf_ramp", "Neon Surf Ramp", 5, 300000, 720, 24, 2),
	def("sunset_yoga_deck", "Sunset Yoga Deck", 6, 350000, 820, 25, 2),
	def("main_stage_mk2", "Main Stage Mk II", 6, 400000, 950, 30, 2),

	-- §4 Zone 3 — Bottle Beach (déblocage : 500 000 Shells + Hype 75 + 1 prestige
	-- OU 50 Moon Shards). 8 items, tiers 6-8, coûts 300k→5M. The Blueprint names
	-- 5 items and gives ranges only; the full table (3 added names + per-item
	-- numbers, §3.2 growth) is a Sprint 6 amendment (2026-07-17).
	def("bioluminescent_lagoon", "Bioluminescent Lagoon", 6, 300000, 720, 26, 3),
	def("treehouse_vip_deck", "Treehouse VIP Deck", 6, 450000, 980, 28, 3),
	def("infinity_fire_show_arena", "Infinity Fire Show Arena", 7, 700000, 1400, 32, 3),
	def("sky_lantern_grounds", "Sky Lantern Festival Grounds", 7, 1100000, 2000, 35, 3),
	def("moonlit_tide_pools", "Moonlit Tide Pools", 7, 1600000, 2700, 34, 3),
	def("cliffside_sound_garden", "Cliffside Sound Garden", 8, 2400000, 3600, 38, 3),
	def("full_moon_amphitheater", "Full Moon Amphitheater", 8, 3500000, 5000, 45, 3),
	def("celestial_main_stage", "Celestial Main Stage", 8, 5000000, 7000, 50, 3),
}

local byId: { [string]: EquipmentDef } = {}
for _, item in list do
	byId[item.id] = item
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
})
