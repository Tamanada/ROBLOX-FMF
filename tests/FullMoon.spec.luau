--!nonstrict
-- tests/FullMoon.spec.luau — Sprint 3 Full Moon (§2.3, §3.1, §10.5).
-- The clock helpers are pure functions of the UTC epoch, so any two servers
-- evaluating at the same UTC second reach the SAME state with no cross-server
-- messaging — this determinism is the S3 DoD ("synchronised across servers").
-- Nonstrict: TestEZ injects describe/it/expect globals at runtime.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local Economy = require(ReplicatedStorage.Shared.Config.Economy)
	local FullMoonService = require(ServerScriptService.Server.Services.FullMoonService)

	local PERIOD = Economy.FULL_MOON_PERIOD_SECONDS
	local DURATION = Economy.FULL_MOON_DURATION_SECONDS

	describe("Full Moon constants (§2.3, §10.5)", function()
		it("fires every 2 h for 10 min", function()
			expect(PERIOD).to.equal(7200)
			expect(DURATION).to.equal(600)
		end)

		it("uses the binding multipliers and gate", function()
			expect(Economy.FULL_MOON_REVENUE_MULTIPLIER_MAX).to.equal(5)
			expect(Economy.FULL_MOON_REVENUE_MULTIPLIER_REDUCED).to.equal(2)
			expect(Economy.FULL_MOON_SPAWN_MULTIPLIER).to.equal(3)
			expect(Economy.FULL_MOON_HYPE_THRESHOLD).to.equal(80)
		end)
	end)

	describe("UTC clock (§10.5 — deterministic cross-server sync)", function()
		it("is active only in the first 10 min of every 2 h window", function()
			expect(FullMoonService._isActiveAt(0)).to.equal(true)
			expect(FullMoonService._isActiveAt(DURATION - 1)).to.equal(true)
			expect(FullMoonService._isActiveAt(DURATION)).to.equal(false)
			expect(FullMoonService._isActiveAt(PERIOD - 1)).to.equal(false)
			expect(FullMoonService._isActiveAt(PERIOD)).to.equal(true)
		end)

		it("aligns event starts to UTC multiples of the period (all servers agree)", function()
			for _, k in { 1, 7, 42, 1000 } do
				local base = k * PERIOD
				expect(FullMoonService._isActiveAt(base)).to.equal(true) -- window opens
				expect(FullMoonService._isActiveAt(base - 1)).to.equal(false) -- just before
				expect(FullMoonService._isActiveAt(base + DURATION)).to.equal(false) -- just after close
			end
		end)

		it("counts down the remaining and next-start times", function()
			expect(FullMoonService._secondsRemainingAt(0)).to.equal(DURATION)
			expect(FullMoonService._secondsRemainingAt(DURATION - 1)).to.equal(1)
			expect(FullMoonService._secondsRemainingAt(DURATION)).to.equal(0)

			expect(FullMoonService._secondsUntilNextAt(0)).to.equal(0) -- active now
			expect(FullMoonService._secondsUntilNextAt(DURATION)).to.equal(PERIOD - DURATION)
			expect(FullMoonService._secondsUntilNextAt(PERIOD - 1)).to.equal(1)
		end)
	end)

	describe("multiplier & reward gate (§2.3)", function()
		it("revenue is x1 off-event, x5 eligible, x2 reduced", function()
			expect(FullMoonService._revenueMultiplier(false, false)).to.equal(1)
			expect(FullMoonService._revenueMultiplier(false, true)).to.equal(1)
			expect(FullMoonService._revenueMultiplier(true, true)).to.equal(5)
			expect(FullMoonService._revenueMultiplier(true, false)).to.equal(2)
		end)

		it("Moon Shards reward is 5 when eligible, else 2 (§2.3 amendment)", function()
			expect(FullMoonService._rewardFor(true)).to.equal(5)
			expect(FullMoonService._rewardFor(false)).to.equal(2)
		end)
	end)
end
