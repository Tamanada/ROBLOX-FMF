--!nonstrict
-- tests/Staff.spec.luau — Sprint 4 staff collection (§5). Verifies the roll
-- odds are self-consistent and DISPLAYABLE (§5.1/§11.2 compliance), the rarity
-- roll maps values correctly, effect sums (§5.2), and the fusion count sink.
-- Nonstrict: TestEZ injects describe/it/expect globals at runtime.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local Economy = require(ReplicatedStorage.Shared.Config.Economy)
	local Staff = require(ReplicatedStorage.Shared.Config.Staff)
	local StaffService = require(ServerScriptService.Server.Services.StaffService)

	describe("recruitment banners (§5.1 — displayed odds, no Robux)", function()
		it("has the two Blueprint banners at the binding costs", function()
			local standard = Staff.bannersById.standard
			local premium = Staff.bannersById.premium
			expect(standard.costCurrency).to.equal("shells")
			expect(standard.cost).to.equal(500)
			expect(premium.costCurrency).to.equal("moonShards")
			expect(premium.cost).to.equal(5)
		end)

		it("every banner's odds sum to 1 and only list rarities with a roster", function()
			for _, banner in Staff.banners do
				local total = 0
				for rarity, probability in banner.odds do
					total += probability
					expect(#Staff.byRarity[rarity] > 0).to.equal(true)
				end
				expect(total).to.equal(1)
			end
		end)

		it("premium guarantees at least Epic (§5.1)", function()
			local premium = Staff.bannersById.premium
			expect(premium.odds.Common).never.to.be.ok()
			expect(premium.odds.Rare).never.to.be.ok()
			expect(premium.odds.Epic).to.be.ok()
		end)
	end)

	describe("rarity roll (§5.1 odds)", function()
		it("maps the roll value through cumulative standard odds", function()
			local odds = Staff.bannersById.standard.odds -- Common 0.75, Rare 0.25
			expect(StaffService._rollRarity(odds, 0)).to.equal("Common")
			expect(StaffService._rollRarity(odds, 0.74)).to.equal("Common")
			expect(StaffService._rollRarity(odds, 0.75)).to.equal("Rare")
			expect(StaffService._rollRarity(odds, 0.999)).to.equal("Rare")
		end)

		it("maps the premium banner (Epic/Legendary)", function()
			local odds = Staff.bannersById.premium.odds -- Epic 0.9, Legendary 0.1
			expect(StaffService._rollRarity(odds, 0)).to.equal("Epic")
			expect(StaffService._rollRarity(odds, 0.89)).to.equal("Epic")
			expect(StaffService._rollRarity(odds, 0.9)).to.equal("Legendary")
		end)
	end)

	describe("effects (§5.2) and fusion sink (§5.2)", function()
		it("sums the revenue/Hype of ASSIGNED staff only", function()
			local data: any = {
				staff = {
					{ staffId = "resident_dj", rarity = "Epic", assignedZone = "1" }, -- +20% rev, +8 Hype
					{ staffId = "fire_juggler", rarity = "Rare", assignedZone = "2" }, -- +10% rev, +3 Hype
					{ staffId = "cleaner", rarity = "Common", assignedZone = nil }, -- unassigned → 0
				},
			}
			local bonuses = StaffService._staffBonuses(data)
			expect(bonuses.revenue).to.equal(0.3)
			expect(bonuses.hype).to.equal(11)
		end)

		it("counts duplicates for the fusion threshold (§5.2 — 3 → 1)", function()
			expect(Economy.STAFF_FUSION_COUNT).to.equal(3)
			local data: any = {
				staff = {
					{ staffId = "bartender", rarity = "Common", assignedZone = nil },
					{ staffId = "bartender", rarity = "Common", assignedZone = "1" },
					{ staffId = "bartender", rarity = "Common", assignedZone = nil },
					{ staffId = "cleaner", rarity = "Common", assignedZone = nil },
				},
			}
			expect(StaffService._countById(data, "bartender")).to.equal(3)
			expect(StaffService._countById(data, "cleaner")).to.equal(1)
		end)

		it("fusion chain climbs one rarity and caps at Legendary (§5.2)", function()
			expect(Staff.fusionNext.Common).to.equal("Rare")
			expect(Staff.fusionNext.Rare).to.equal("Epic")
			expect(Staff.fusionNext.Epic).to.equal("Legendary")
			expect(Staff.fusionNext.Legendary).never.to.be.ok()
		end)
	end)

	describe("Zone 2 unlock gate (§4)", function()
		it("uses the binding requirements (75k Shells + Hype 60)", function()
			expect(Economy.ZONE_UNLOCKS[2].shells).to.equal(75000)
			expect(Economy.ZONE_UNLOCKS[2].hype).to.equal(60)
		end)
	end)
end
