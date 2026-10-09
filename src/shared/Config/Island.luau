--!strict
-- shared/Config/Island.luau — Blueprint §14.2 (amendement S7).
-- Les 5 zones de l'île : méta-layer partagé par serveur. Les plots tycoon
-- (§6) vivent dans la zone haad_rin. Ids de venues NEUTRES (§14.5) : les
-- noms réels seront fictionnalisés à l'implémentation des venues ; seule
-- exception approuvée : Dancing Elephant Hostel (marque du fondateur).
-- §10.3.3 — réplication en lecture seule, le serveur fait foi.

export type VenueSlot = {
	id: string,
	displayName: string,
	-- false = décor/service (non comptabilisé dans les règles d'unlock).
	completable: boolean,
}

export type ActivitySlot = {
	id: string,
	displayName: string,
}

export type SpawnDef = { x: number, y: number, z: number, yawDeg: number }

export type ZoneDef = {
	id: string,
	displayName: string,
	spawn: SpawnDef,
	-- Anchor du décor placeholder (le spawn est posé dessus).
	groundRadius: number,
	groundColor: string,
	venues: { VenueSlot },
	activities: { ActivitySlot },
	boatOnly: boolean,
}

local function venue(id: string, displayName: string, completable: boolean): VenueSlot
	return table.freeze({ id = id, displayName = displayName, completable = completable })
end

local function activity(id: string, displayName: string): ActivitySlot
	return table.freeze({ id = id, displayName = displayName })
end

local zones: { ZoneDef } = {
	table.freeze({
		id = "haad_rin",
		displayName = "Haad Rin",
		spawn = table.freeze({ x = 192, y = 3, z = -140, yawDeg = 180 }),
		groundRadius = 60,
		groundColor = "#E8DCC0",
		venues = table.freeze({
			venue("dancing_elephant_hostel", "Dancing Elephant Hostel", false), -- check-in, spawn social
			venue("hr_venue_1", "Venue Haad Rin 1 (TBD)", true), -- futur club falaise (fictionnalisé)
			venue("hr_venue_2", "Venue Haad Rin 2 (TBD)", true), -- futur bar jardin (fictionnalisé)
			venue("hr_venue_3", "Venue Haad Rin 3 (TBD)", true), -- futur spot bord de mer (fictionnalisé)
			venue("hr_venue_4", "Venue Haad Rin 4 (TBD)", true), -- future street party (fictionnalisée)
		}),
		activities = table.freeze({
			activity("beach_volleyball", "Beach Volleyball"),
			activity("beach_frisbee", "Frisbee"),
			activity("beach_swim", "Baignade"),
		}),
		boatOnly = false,
	}),
	table.freeze({
		id = "baan_tai",
		displayName = "Baan Tai",
		spawn = table.freeze({ x = 192, y = 3, z = 520, yawDeg = 0 }),
		groundRadius = 45,
		groundColor = "#3c7a4a",
		venues = table.freeze({
			venue("bt_venue_1", "Venue jungle Baan Tai 1 (TBD)", true), -- fenêtre FULL_MOON_EVE (§14.4)
			venue("bt_venue_2", "Venue jungle Baan Tai 2 (TBD)", true), -- fenêtres HALF_MOON (§14.4)
		}),
		activities = table.freeze({}),
		boatOnly = false,
	}),
	table.freeze({
		id = "thong_sala",
		displayName = "Thong Sala",
		spawn = table.freeze({ x = -320, y = 3, z = 60, yawDeg = 90 }),
		groundRadius = 45,
		groundColor = "#b9ab8e",
		venues = table.freeze({}),
		activities = table.freeze({
			activity("main_pier_npc", "Main Pier"),
			activity("motorbike_rental_npc", "Location de motos"),
			activity("taxi_station_npc", "Station de taxis"),
		}),
		boatOnly = false,
	}),
	table.freeze({
		id = "haad_yuan",
		displayName = "Haad Yuan",
		spawn = table.freeze({ x = 760, y = 3, z = 40, yawDeg = -90 }),
		groundRadius = 45,
		groundColor = "#E8DCC0",
		venues = table.freeze({
			venue("hy_venue_1", "Venue Haad Yuan 1 (TBD)", true), -- futur garden party (fictionnalisé)
			venue("hy_venue_2", "Venue Haad Yuan 2 (TBD)", true), -- futur lounge jungle (fictionnalisé)
		}),
		activities = table.freeze({}),
		boatOnly = true,
	}),
	table.freeze({
		id = "haad_thien",
		displayName = "Haad Thien",
		spawn = table.freeze({ x = 760, y = 3, z = -320, yawDeg = 180 }),
		groundRadius = 40,
		groundColor = "#d9c9a8",
		venues = table.freeze({
			venue("ht_venue_1", "Venue Haad Thien (slot libre)", true),
		}),
		activities = table.freeze({}),
		boatOnly = false,
	}),
}

local byId: { [string]: ZoneDef } = {}
local venueZone: { [string]: string } = {}
local completableVenuesByZone: { [string]: { string } } = {}

for _, zone in zones do
	byId[zone.id] = zone
	local completable: { string } = {}
	for _, slot in zone.venues do
		venueZone[slot.id] = zone.id
		if slot.completable then
			table.insert(completable, slot.id)
		end
	end
	completableVenuesByZone[zone.id] = table.freeze(completable)
end

return table.freeze({
	HUB_ZONE = "haad_rin",
	list = table.freeze(zones),
	byId = table.freeze(byId),
	-- venueId -> zoneId (validation serveur de CompleteVenue).
	venueZone = table.freeze(venueZone),
	-- zoneId -> ids des venues comptabilisables (règles d'unlock §14.2).
	completableVenuesByZone = table.freeze(completableVenuesByZone),
})
