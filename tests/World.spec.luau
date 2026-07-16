--!nonstrict
-- tests/World.spec.luau — Sprint 2 living world (§2.2 cycle, §3.3 Hype
-- dynamics, §7 beach cleanup, §2.1/§10.6 NPC crowd). Values are asserted
-- against the BINDING Blueprint: if a constant drifts, these specs fail.
-- Nonstrict: TestEZ injects describe/it/expect globals at runtime.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local Economy = require(ReplicatedStorage.Shared.Config.Economy)
	local EventService = require(ServerScriptService.Server.Services.EventService)
	local HypeService = require(ServerScriptService.Server.Services.HypeService)
	local NPCService = require(ServerScriptService.Server.Services.NPCService)

	describe("day/night cycle constants (§2.2 — 16 min = 10 day / 6 night)", function()
		it("day + night sum to the 16-minute cycle", function()
			expect(Economy.DAY_DURATION_SECONDS).to.equal(600)
			expect(Economy.NIGHT_DURATION_SECONDS).to.equal(360)
			expect(Economy.CYCLE_DURATION_SECONDS).to.equal(960)
			expect(Economy.DAY_DURATION_SECONDS + Economy.NIGHT_DURATION_SECONDS).to.equal(16 * 60)
		end)

		it("night pays x2 of day (§2.2)", function()
			expect(Economy.NIGHT_REVENUE_MULTIPLIER).to.equal(2)
			expect(Economy.DAY_REVENUE_MULTIPLIER * Economy.NIGHT_REVENUE_MULTIPLIER).to.equal(1)
		end)
	end)

	describe("EventService phase helpers (§2.2)", function()
		it("is Day for the first 10 minutes, Night after", function()
			expect(EventService._phaseAt(0)).to.equal("Day")
			expect(EventService._phaseAt(599)).to.equal("Day")
			expect(EventService._phaseAt(600)).to.equal("Night")
			expect(EventService._phaseAt(959)).to.equal("Night")
		end)

		it("computes the remaining time to the next boundary", function()
			expect(EventService._phaseRemaining(0)).to.equal(600)
			expect(EventService._phaseRemaining(599)).to.equal(1)
			expect(EventService._phaseRemaining(600)).to.equal(360)
			expect(EventService._phaseRemaining(959)).to.equal(1)
		end)

		it("night pays the catalogue rate in full, day pays half", function()
			local night = EventService._revenueMultiplierFor("Night")
			local day = EventService._revenueMultiplierFor("Day")
			expect(night).to.equal(1)
			expect(day).to.equal(Economy.DAY_REVENUE_MULTIPLIER)
			expect(night / day).to.equal(2) -- the §2.2 x2 relationship
		end)
	end)

	describe("Beach Cleanup Flash (§7 — 10 déchets / 60 s / +5 Hype)", function()
		it("uses the binding §7 values", function()
			expect(Economy.CLEANUP_TRASH_COUNT).to.equal(10)
			expect(Economy.CLEANUP_WINDOW_SECONDS).to.equal(60)
			expect(Economy.CLEANUP_HYPE_BONUS).to.equal(5)
		end)

		it("completes only once the trash threshold is met", function()
			expect(EventService._isCleanupComplete(9, 10)).to.equal(false)
			expect(EventService._isCleanupComplete(10, 10)).to.equal(true)
			expect(EventService._isCleanupComplete(11, 10)).to.equal(true)
		end)
	end)

	describe("HypeService dynamics (§3.3 — cleanliness/decay modifier)", function()
		it("bounds the modifier to its configured range", function()
			expect(HypeService._clampModifier(30)).to.equal(Economy.HYPE_MODIFIER_MAX)
			expect(HypeService._clampModifier(-30)).to.equal(Economy.HYPE_MODIFIER_MIN)
			expect(HypeService._clampModifier(7)).to.equal(7)
		end)

		it("composes and clamps final Hype to 0-100", function()
			expect(HypeService._composeHype(50, 5)).to.equal(55)
			expect(HypeService._composeHype(0, -20)).to.equal(0)
			expect(HypeService._composeHype(120, 0)).to.equal(100)
		end)

		it("sums the Hype of non-broken equipment only (§4)", function()
			local data: any = {
				plots = {
					main = {
						equipment = {
							{ id = "campfire", level = 1, cframe = {}, broken = false }, -- +1
							{ id = "smoothie_stand", level = 1, cframe = {}, broken = false }, -- +2
						},
					},
				},
			}
			expect(HypeService._equipmentBonus(data)).to.equal(3)
			data.plots.main.equipment[2].broken = true
			expect(HypeService._equipmentBonus(data)).to.equal(1)
		end)
	end)

	describe("NPCService crowd target (§3.3 spawnRate, §10.6 cap)", function()
		it("scales with Hype (1 + Hype/50) and floors", function()
			-- base 12, night density 1.0
			expect(NPCService._spawnTarget(0, true)).to.equal(12)
			expect(NPCService._spawnTarget(100, true)).to.equal(36) -- 12 * (1 + 100/50)
		end)

		it("night is a denser crowd than day (§2.2)", function()
			expect(NPCService._spawnTarget(0, false)).to.equal(4) -- floor(12 * 0.4)
			expect(NPCService._spawnTarget(0, true) > NPCService._spawnTarget(0, false)).to.equal(true)
		end)

		it("never exceeds the per-plot hard cap of 40 (§10.6)", function()
			expect(NPCService._spawnTarget(1000, true)).to.equal(Economy.NPC_MAX_PER_PLOT)
			expect(Economy.NPC_MAX_PER_PLOT).to.equal(40)
		end)
	end)
end
