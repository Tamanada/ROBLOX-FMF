--!strict
-- shared/Config/Routes.luau — Blueprint §14.3 (transport NPC).
-- Fare 50 Shells, trajet 120 s, skip = fare total ×2 (le supplément débité
-- au skip vaut fare × (SKIP_FARE_MULTIPLIER - 1)). Valeurs serveur de
-- référence (§10.3.3) ; le client ne fait qu'afficher.

export type Waypoint = { x: number, y: number, z: number }

export type RouteDef = {
	id: string,
	vehicle: string, -- "songthaew" | "longtail" | "footpath"
	from: string,
	to: string,
	fare: number,
	durationSeconds: number,
	skipFareMultiplier: number,
	-- Chemin monde : [1] = point d'embarquement, [n] = point d'arrivée.
	path: { Waypoint },
}

local DEFAULT_FARE = 50
local DEFAULT_DURATION = 120
local DEFAULT_SKIP_MULTIPLIER = 2

local function waypoint(x: number, y: number, z: number): Waypoint
	return table.freeze({ x = x, y = y, z = z })
end

local function route(id: string, vehicle: string, from: string, to: string, path: { Waypoint }): RouteDef
	local isFootpath = vehicle == "footpath"
	return table.freeze({
		id = id,
		vehicle = vehicle,
		from = from,
		to = to,
		fare = if isFootpath then 0 else DEFAULT_FARE,
		durationSeconds = if isFootpath then 6 else DEFAULT_DURATION,
		skipFareMultiplier = if isFootpath then 1 else DEFAULT_SKIP_MULTIPLIER,
		path = table.freeze(path),
	})
end

-- Géographie §14.2 : Haad Rin hub (192, -140), Baan Tai sud (192, 520),
-- Thong Sala ouest (-320, 60), Haad Yuan est (760, 40), Haad Thien (760, -320).
local list: { RouteDef } = {
	-- Songthaew (terre)
	route("hr_to_bt", "songthaew", "haad_rin", "baan_tai", {
		waypoint(170, 2, -110),
		waypoint(120, 2, 200),
		waypoint(170, 2, 490),
	}),
	route("bt_to_hr", "songthaew", "baan_tai", "haad_rin", {
		waypoint(170, 2, 490),
		waypoint(120, 2, 200),
		waypoint(170, 2, -110),
	}),
	route("hr_to_ts", "songthaew", "haad_rin", "thong_sala", {
		waypoint(160, 2, -120),
		waypoint(-80, 2, -40),
		waypoint(-290, 2, 50),
	}),
	route("ts_to_hr", "songthaew", "thong_sala", "haad_rin", {
		waypoint(-290, 2, 50),
		waypoint(-80, 2, -40),
		waypoint(160, 2, -120),
	}),
	-- Longtail (mer) — les chemins passent au large (y = 1, sur l'eau).
	route("hr_to_hy", "longtail", "haad_rin", "haad_yuan", {
		waypoint(230, 1, -160),
		waypoint(520, 1, -60),
		waypoint(725, 1, 35),
	}),
	route("hy_to_hr", "longtail", "haad_yuan", "haad_rin", {
		waypoint(725, 1, 35),
		waypoint(520, 1, -60),
		waypoint(230, 1, -160),
	}),
	route("hr_to_ht", "longtail", "haad_rin", "haad_thien", {
		waypoint(230, 1, -160),
		waypoint(540, 1, -260),
		waypoint(725, 1, -310),
	}),
	route("ht_to_hr", "longtail", "haad_thien", "haad_rin", {
		waypoint(725, 1, -310),
		waypoint(540, 1, -260),
		waypoint(230, 1, -160),
	}),
	-- Sentier Haad Yuan <-> Haad Thien (§14.2 : marche, gratuit).
	route("hy_to_ht_walk", "footpath", "haad_yuan", "haad_thien", {
		waypoint(760, 2, 0),
		waypoint(760, 2, -280),
	}),
	route("ht_to_hy_walk", "footpath", "haad_thien", "haad_yuan", {
		waypoint(760, 2, -280),
		waypoint(760, 2, 0),
	}),
}

local byId: { [string]: RouteDef } = {}
for _, def in list do
	byId[def.id] = def
end

return table.freeze({
	DEFAULT_FARE = DEFAULT_FARE,
	DEFAULT_DURATION = DEFAULT_DURATION,
	DEFAULT_SKIP_MULTIPLIER = DEFAULT_SKIP_MULTIPLIER,
	list = table.freeze(list),
	byId = table.freeze(byId),
})
