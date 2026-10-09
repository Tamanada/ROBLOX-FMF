--!nonstrict
-- tests/Island.spec.luau — Sprint 7 (§14) : matrice des règles d'unlock,
-- math du cycle lunaire (alignée sur la fenêtre d'event §2.3), intégrité
-- des configs Island/Routes, migration v4.
-- Nonstrict: TestEZ injects describe/it/expect globals at runtime.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local Island = require(ReplicatedStorage.Shared.Config.Island)
	local Routes = require(ReplicatedStorage.Shared.Config.Routes)
	local Unlocks = require(ReplicatedStorage.Shared.Config.Unlocks)
	local UnlockRules = require(ReplicatedStorage.Shared.Util.UnlockRules)
	local MoonCycle = require(ReplicatedStorage.Shared.Util.MoonCycle)
	local Economy = require(ReplicatedStorage.Shared.Config.Economy)
	local FullMoonService = require(ServerScriptService.Server.Services.FullMoonService)
	local DataService = require(ServerScriptService.Server.Services.DataService)

	local function freshProgress()
		return { completedVenues = {}, zoneVisits = {} }
	end

	local function isUnlocked(zoneId, progress)
		return UnlockRules.isZoneUnlocked(zoneId, Unlocks.rules, progress, Island.completableVenuesByZone)
	end

	describe("règles d'unlock (§14.2 — matrice contraignante)", function()
		it("Haad Rin est toujours débloquée", function()
			expect(isUnlocked("haad_rin", freshProgress())).to.equal(true)
		end)

		it("Baan Tai s'ouvre à 2 venues de Haad Rin, pas avant", function()
			local progress = freshProgress()
			expect(isUnlocked("baan_tai", progress)).to.equal(false)
			progress.completedVenues.hr_venue_1 = true
			expect(isUnlocked("baan_tai", progress)).to.equal(false)
			progress.completedVenues.hr_venue_2 = true
			expect(isUnlocked("baan_tai", progress)).to.equal(true)
		end)

		it("les venues non comptabilisables ne comptent pas (hostel)", function()
			local progress = freshProgress()
			progress.completedVenues.dancing_elephant_hostel = true
			progress.completedVenues.hr_venue_1 = true
			expect(isUnlocked("baan_tai", progress)).to.equal(false)
		end)

		it("Thong Sala exige 1 venue Haad Rin ET 1 venue Baan Tai", function()
			local progress = freshProgress()
			progress.completedVenues.hr_venue_1 = true
			expect(isUnlocked("thong_sala", progress)).to.equal(false)
			progress.completedVenues.bt_venue_1 = true
			expect(isUnlocked("thong_sala", progress)).to.equal(true)
		end)

		it("Haad Yuan exige les 4 venues de Haad Rin", function()
			local progress = freshProgress()
			progress.completedVenues.hr_venue_1 = true
			progress.completedVenues.hr_venue_2 = true
			progress.completedVenues.hr_venue_3 = true
			expect(isUnlocked("haad_yuan", progress)).to.equal(false)
			progress.completedVenues.hr_venue_4 = true
			expect(isUnlocked("haad_yuan", progress)).to.equal(true)
		end)

		it("Haad Thien exige d'avoir visité Haad Yuan", function()
			local progress = freshProgress()
			expect(isUnlocked("haad_thien", progress)).to.equal(false)
			progress.zoneVisits.haad_yuan = 1
			expect(isUnlocked("haad_thien", progress)).to.equal(true)
		end)

		it("une zone inconnue ou une règle inconnue est verrouillée (fail-closed)", function()
			expect(isUnlocked("zone_fantome", freshProgress())).to.equal(false)
			expect(UnlockRules.isRequirementMet({ kind = "wtf" }, freshProgress(), Island.completableVenuesByZone)).to.equal(
				false
			)
		end)
	end)

	describe("MoonCycle (§14.4 — même horloge que l'event §2.3)", function()
		it("les segments couvrent exactement une période", function()
			local previousEnd = 0
			for _, segment in MoonCycle.SEGMENTS do
				expect(segment.startOffset).to.equal(previousEnd)
				expect(segment.endOffset > segment.startOffset).to.equal(true)
				previousEnd = segment.endOffset
			end
			expect(previousEnd).to.equal(Economy.FULL_MOON_PERIOD_SECONDS)
		end)

		it("FULL_MOON coïncide exactement avec la fenêtre d'event", function()
			for _, offset in { 0, 1, 299, 599 } do
				expect(MoonCycle.GetPhase(offset).phase).to.equal("FULL_MOON")
				expect(FullMoonService._isActiveAt(offset)).to.equal(true)
			end
			for _, offset in { 600, 601, 3600, 7199 } do
				expect(MoonCycle.GetPhase(offset).phase).never.to.equal("FULL_MOON")
				expect(FullMoonService._isActiveAt(offset)).to.equal(false)
			end
		end)

		it("HALF_MOON apparaît deux fois, symétrique autour de la pleine lune", function()
			local halves = {}
			for _, segment in MoonCycle.SEGMENTS do
				if segment.phase == "HALF_MOON" then
					table.insert(halves, segment)
				end
			end
			expect(#halves).to.equal(2)
			-- miroir autour de la pleine lune (t = 0 mod période) :
			-- [a, b] et [période - b, période - a]
			local period = Economy.FULL_MOON_PERIOD_SECONDS
			expect(halves[1].startOffset).to.equal(period - halves[2].endOffset)
			expect(halves[1].endOffset).to.equal(period - halves[2].startOffset)
			-- fenêtres de même durée
			expect(halves[1].endOffset - halves[1].startOffset).to.equal(halves[2].endOffset - halves[2].startOffset)
		end)

		it("FULL_MOON_EVE est le bloc juste avant FULL_MOON (fenêtre Jungle)", function()
			local lastSegment = MoonCycle.SEGMENTS[#MoonCycle.SEGMENTS]
			expect(lastSegment.phase).to.equal("FULL_MOON_EVE")
			expect(lastSegment.endOffset).to.equal(Economy.FULL_MOON_PERIOD_SECONDS)
			expect(MoonCycle.GetPhase(lastSegment.startOffset).phase).to.equal("FULL_MOON_EVE")
		end)

		it("GetPhase retourne des bornes absolues cohérentes", function()
			local now = 7200 * 1000 + 2000 -- NEW_MOON window? 2000 -> HALF_MOON (1500-2700)
			local info = MoonCycle.GetPhase(now)
			expect(info.phase).to.equal("HALF_MOON")
			expect(info.startsAt).to.equal(7200 * 1000 + 1500)
			expect(info.endsAt).to.equal(7200 * 1000 + 2700)
		end)

		it("GetNextPhaseAt trouve la prochaine fenêtre (et la courante quand on est dedans)", function()
			-- depuis POST_FULL (700) : prochaine FULL = début du cycle suivant
			expect(MoonCycle.GetNextPhaseAt("FULL_MOON", 700)).to.equal(7200)
			-- depuis POST_FULL : prochaine HALF = 1500 (première fenêtre)
			expect(MoonCycle.GetNextPhaseAt("HALF_MOON", 700)).to.equal(1500)
			-- entre les deux fenêtres HALF (3000) : prochaine HALF = 4500
			expect(MoonCycle.GetNextPhaseAt("HALF_MOON", 3000)).to.equal(4500)
			-- dedans (100, FULL active) : début de la fenêtre courante
			expect(MoonCycle.GetNextPhaseAt("FULL_MOON", 100)).to.equal(0)
			-- phase inconnue : erreur bruyante
			expect(function()
				MoonCycle.GetNextPhaseAt("BLOOD_MOON", 0)
			end).to.throw()
		end)
	end)

	describe("intégrité des configs île et routes (§14.2 / §14.3)", function()
		it("l'île compte 5 zones aux ids uniques", function()
			expect(#Island.list).to.equal(5)
			local seen = {}
			for _, zone in Island.list do
				expect(seen[zone.id]).never.to.be.ok()
				seen[zone.id] = true
			end
			expect(seen.haad_rin and seen.baan_tai and seen.thong_sala and seen.haad_yuan and seen.haad_thien).to.equal(
				true
			)
		end)

		it("Haad Rin a exactement 4 venues comptabilisables + le hostel", function()
			expect(#Island.completableVenuesByZone.haad_rin).to.equal(4)
			expect(Island.venueZone.dancing_elephant_hostel).to.equal("haad_rin")
		end)

		it("chaque règle d'unlock référence des zones existantes", function()
			for zoneId, requirements in Unlocks.rules do
				expect(Island.byId[zoneId]).to.be.ok()
				for _, requirement in requirements do
					if requirement.zone ~= nil then
						expect(Island.byId[requirement.zone]).to.be.ok()
					end
				end
			end
		end)

		it("8 routes de transport (fare 50, 120 s, skip x2) + 2 sentiers gratuits", function()
			local vehicles, footpaths = 0, 0
			for _, route in Routes.list do
				expect(Island.byId[route.from]).to.be.ok()
				expect(Island.byId[route.to]).to.be.ok()
				expect(#route.path >= 2).to.equal(true)
				if route.vehicle == "footpath" then
					footpaths += 1
					expect(route.fare).to.equal(0)
				else
					vehicles += 1
					expect(route.fare).to.equal(50)
					expect(route.durationSeconds).to.equal(120)
					expect(route.skipFareMultiplier).to.equal(2)
				end
			end
			expect(vehicles).to.equal(8)
			expect(footpaths).to.equal(2)
		end)

		it("chaque route de transport a sa route retour", function()
			for _, route in Routes.list do
				if route.vehicle ~= "footpath" then
					local hasReverse = false
					for _, other in Routes.list do
						if other.from == route.to and other.to == route.from and other.vehicle == route.vehicle then
							hasReverse = true
						end
					end
					expect(hasReverse).to.equal(true)
				end
			end
		end)

		it("Haad Yuan est bateau uniquement", function()
			for _, route in Routes.list do
				if route.to == "haad_yuan" then
					expect(route.vehicle == "longtail" or route.vehicle == "footpath").to.equal(true)
				end
			end
			expect(Island.byId.haad_yuan.boatOnly).to.equal(true)
		end)
	end)

	describe("schéma v4 (§14.6)", function()
		it("le template porte island et DATA_VERSION = 4", function()
			expect(DataService.DATA_VERSION).to.equal(4)
			expect(DataService.TEMPLATE.dataVersion).to.equal(4)
			expect(type(DataService.TEMPLATE.island)).to.equal("table")
			expect(type(DataService.TEMPLATE.island.completedVenues)).to.equal("table")
			expect(type(DataService.TEMPLATE.island.zoneVisits)).to.equal("table")
		end)

		it("la migration v3 -> v4 ajoute island sans toucher au reste", function()
			local data: any = { dataVersion = 3, shells = 777 }
			DataService.Migrate(data)
			expect(data.dataVersion).to.equal(4)
			expect(type(data.island)).to.equal("table")
			expect(data.shells).to.equal(777)
		end)
	end)
end
