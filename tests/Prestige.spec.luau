--!nonstrict
-- tests/Prestige.spec.luau — Sprint 6 launch build (§2.3 prestige, §4 Zone 3).
-- Nonstrict: TestEZ injects describe/it/expect globals at runtime.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local Economy = require(ReplicatedStorage.Shared.Config.Economy)
	local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
	local BuildService = require(ServerScriptService.Server.Services.BuildService)

	describe("prestige multiplier (§2.3 — +10 %/prestige, cap ×2.5)", function()
		it("adds 10 % per prestige from a base of 1", function()
			expect(BuildService._prestigeMultiplier(0)).to.equal(1)
			expect(BuildService._prestigeMultiplier(1)).to.equal(1.1)
			expect(BuildService._prestigeMultiplier(5)).to.equal(1.5)
		end)

		it("caps at ×2.5", function()
			expect(BuildService._prestigeMultiplier(15)).to.equal(2.5)
			expect(BuildService._prestigeMultiplier(100)).to.equal(2.5)
		end)

		it("uses the binding constants", function()
			expect(Economy.PRESTIGE_MULTIPLIER_PER).to.equal(0.1)
			expect(Economy.PRESTIGE_MULTIPLIER_CAP).to.equal(2.5)
			expect(Economy.PRESTIGE_REQUIRED_ZONE).to.equal(3)
		end)
	end)

	describe("Zone 3 — Bottle Beach (§4)", function()
		it("has 8 items (tiers 6-8, 300k→5M)", function()
			local zone3, minCost, maxCost = 0, math.huge, 0
			for _, def in Equipment.list do
				if def.zone == 3 then
					zone3 += 1
					expect(def.tier >= 6 and def.tier <= 8).to.equal(true)
					minCost = math.min(minCost, def.cost)
					maxCost = math.max(maxCost, def.cost)
				end
			end
			expect(zone3).to.equal(8)
			expect(minCost).to.equal(300000)
			expect(maxCost).to.equal(5000000)
		end)

		it("full catalogue is 34 items (§4 — 13 + 13 + 8)", function()
			expect(#Equipment.list).to.equal(34)
		end)

		it("unlock gate needs 500k Shells + Hype 75 + prestige/50 shards", function()
			local req = Economy.ZONE_UNLOCKS[3]
			expect(req.shells).to.equal(500000)
			expect(req.hype).to.equal(75)
			expect(req.requiresPrestige).to.equal(1)
			expect(req.altMoonShards).to.equal(50)
		end)
	end)
end
