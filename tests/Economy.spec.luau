--!nonstrict
-- tests/Economy.spec.luau — economy math matches the Blueprint (§2.4, §3.3,
-- §4). The catalogue matrix below is copied from the BINDING §4 table — if
-- a config value drifts from the Blueprint, these specs fail.
-- Nonstrict: TestEZ injects describe/it/expect globals at runtime.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
	local Economy = require(ReplicatedStorage.Shared.Config.Economy)
	local EconomyMath = require(ReplicatedStorage.Shared.Util.EconomyMath)
	local BuildService = require(ServerScriptService.Server.Services.BuildService)

	describe("catalogue Zone 1 (§4 — matrice contraignante)", function()
		-- { id, tier, cost, revPerMinNight, hype }
		local expected = {
			{ "campfire", 0, 0, 2, 1 },
			{ "smoothie_stand", 1, 100, 8, 2 },
			{ "fruit_bucket_bar", 1, 250, 14, 2 },
			{ "beach_mat_lounge", 1, 400, 10, 3 },
			{ "speaker_tower", 2, 900, 22, 5 },
			{ "uv_paint_station", 2, 1500, 30, 6 },
			{ "moon_swing_photo_spot", 2, 2200, 26, 7 },
			{ "juggling_circle", 3, 4000, 45, 8 },
			{ "fire_limbo", 3, 6500, 60, 9 },
			{ "small_dj_booth", 3, 10000, 85, 12 },
			{ "lantern_release_deck", 4, 18000, 110, 14 },
			{ "neon_dance_floor", 4, 30000, 160, 16 },
			{ "main_stage_mk1", 5, 55000, 260, 22 },
		}

		it("contains exactly the 13 Zone 1 items", function()
			expect(#Equipment.list).to.equal(13)
			for _, def in Equipment.list do
				expect(def.zone).to.equal(1)
			end
		end)

		it("matches the §4 table value for value", function()
			for _, row in expected do
				local id, tier, cost, rev, hype = row[1], row[2], row[3], row[4], row[5]
				local def = Equipment.byId[id]
				expect(def).to.be.ok()
				expect(def.tier).to.equal(tier)
				expect(def.cost).to.equal(cost)
				expect(def.revenuePerMinuteNight).to.equal(rev)
				expect(def.hype).to.equal(hype)
			end
		end)
	end)

	describe("EconomyMath (§4 upgrades/réparation, §3.3 Hype, §2.4 offline)", function()
		it("upgrade cost = 60% of the purchase price", function()
			expect(EconomyMath.upgradeCost(100)).to.equal(60)
			expect(EconomyMath.upgradeCost(1500)).to.equal(900)
			expect(EconomyMath.upgradeCost(55000)).to.equal(33000)
		end)

		it("max level = purchase + 3 upgrade steps", function()
			expect(EconomyMath.maxLevel()).to.equal(4)
		end)

		it("revenue x1.5 per upgrade level", function()
			expect(EconomyMath.revenuePerMinute(8, 1)).to.equal(8)
			expect(EconomyMath.revenuePerMinute(8, 2)).to.equal(12)
			expect(EconomyMath.revenuePerMinute(8, 3)).to.equal(18)
			expect(EconomyMath.revenuePerMinute(8, 4)).to.equal(27)
		end)

		it("repair cost = 10% of the purchase price", function()
			expect(EconomyMath.repairCost(1500)).to.equal(150)
			expect(EconomyMath.repairCost(0)).to.equal(0)
		end)

		it("effective rate applies the §3.3 Hype multiplier (1 + Hype/100)", function()
			expect(EconomyMath.effectiveRate(8, 1, 0)).to.equal(8)
			expect(EconomyMath.effectiveRate(8, 1, 50)).to.equal(12)
			expect(EconomyMath.effectiveRate(8, 2, 100)).to.equal(24)
		end)

		it("offline earnings = 20% of the active rate", function()
			-- 60 Shells/min for 1h offline -> 60 * 60 * 0.2 = 720
			expect(EconomyMath.offlineEarnings(60, 3600)).to.equal(720)
		end)

		it("offline earnings cap at 8 hours", function()
			local capped = EconomyMath.offlineEarnings(60, Economy.OFFLINE_CAP_SECONDS)
			expect(EconomyMath.offlineEarnings(60, 20 * 3600)).to.equal(capped)
			expect(capped).to.equal(5760)
		end)

		it("offline earnings handle degenerate inputs", function()
			expect(EconomyMath.offlineEarnings(0, 3600)).to.equal(0)
			expect(EconomyMath.offlineEarnings(60, -5)).to.equal(0)
		end)
	end)

	describe("BuildService pure helpers (§10.3.2 bounds, plot rate)", function()
		local plotSize = Vector3.new(96, 1, 96)

		it("accepts positions inside the plot", function()
			expect(BuildService._isWithinPlotBounds(Vector3.new(0, 3, 0), plotSize)).to.equal(true)
			expect(BuildService._isWithinPlotBounds(Vector3.new(44, 0, -44), plotSize)).to.equal(true)
		end)

		it("rejects positions outside the X/Z bounds", function()
			expect(BuildService._isWithinPlotBounds(Vector3.new(60, 3, 0), plotSize)).to.equal(false)
			expect(BuildService._isWithinPlotBounds(Vector3.new(0, 3, -47), plotSize)).to.equal(false)
		end)

		it("rejects positions below ground or above the build height", function()
			expect(BuildService._isWithinPlotBounds(Vector3.new(0, -1, 0), plotSize)).to.equal(false)
			expect(BuildService._isWithinPlotBounds(Vector3.new(0, 51, 0), plotSize)).to.equal(false)
		end)

		it("rejects NaN positions (exploit payload)", function()
			expect(BuildService._isWithinPlotBounds(Vector3.new(0 / 0, 3, 0), plotSize)).to.equal(false)
		end)

		it("computes the plot rate from working equipment, Hype included", function()
			local data: any = {
				hype = 0,
				plots = {
					main = {
						equipment = {
							{ id = "campfire", level = 1, cframe = {}, broken = false },
						},
					},
				},
			}
			expect(BuildService._computeRatePerMinute(data)).to.equal(2)

			table.insert(data.plots.main.equipment, {
				id = "smoothie_stand",
				level = 2,
				cframe = {},
				broken = false,
			})
			expect(BuildService._computeRatePerMinute(data)).to.equal(14) -- 2 + 8*1.5

			data.hype = 50
			expect(BuildService._computeRatePerMinute(data)).to.equal(21) -- 14 * 1.5
		end)

		it("broken equipment earns nothing (§4)", function()
			local data: any = {
				hype = 0,
				plots = {
					main = {
						equipment = {
							{ id = "smoothie_stand", level = 1, cframe = {}, broken = true },
							{ id = "campfire", level = 1, cframe = {}, broken = false },
						},
					},
				},
			}
			expect(BuildService._computeRatePerMinute(data)).to.equal(2)
		end)
	end)
end
