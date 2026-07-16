--!nonstrict
-- tests/Social.spec.luau — Sprint 5 social (§6). Pure helpers for the daily
-- reset, rating average, visit-quest counting, and the 1-vote/day rule.
-- Nonstrict: TestEZ injects describe/it/expect globals at runtime.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local Economy = require(ReplicatedStorage.Shared.Config.Economy)
	local SocialService = require(ServerScriptService.Server.Services.SocialService)

	describe("social config (§6)", function()
		it("uses the binding values", function()
			expect(Economy.VISIT_QUEST_TARGET).to.equal(3)
			expect(Economy.RATING_MIN).to.equal(1)
			expect(Economy.RATING_MAX).to.equal(5)
			expect(Economy.FRIEND_BONUS_MULTIPLIER).to.equal(1.05)
		end)
	end)

	describe("daily index (§6 — per-day reset)", function()
		it("buckets unix time into UTC days", function()
			expect(SocialService._todayIndex(0)).to.equal(0)
			expect(SocialService._todayIndex(Economy.SECONDS_PER_DAY - 1)).to.equal(0)
			expect(SocialService._todayIndex(Economy.SECONDS_PER_DAY)).to.equal(1)
			expect(SocialService._todayIndex(Economy.SECONDS_PER_DAY * 3 + 500)).to.equal(3)
		end)
	end)

	describe("festival rating (§6 — 1-5 stars)", function()
		it("averages the ratings, 0 when unrated", function()
			expect(SocialService._averageRating({ sum = 0, count = 0 })).to.equal(0)
			expect(SocialService._averageRating({ sum = 12, count = 3 })).to.equal(4)
			expect(SocialService._averageRating({ sum = 9, count = 2 })).to.equal(4.5)
		end)
	end)

	describe("visit quest + 1-vote/day (§6)", function()
		it("counts distinct hosts visited today", function()
			local social: any = { visitedHosts = { ["10"] = true, ["20"] = true } }
			expect(SocialService._visitedCount(social)).to.equal(2)
			social.visitedHosts["30"] = true
			expect(SocialService._visitedCount(social)).to.equal(3)
		end)

		it("allows one rating per host per day", function()
			local social: any = { ratedHosts = {} }
			expect(SocialService._canRate(social, "42")).to.equal(true)
			social.ratedHosts["42"] = true
			expect(SocialService._canRate(social, "42")).to.equal(false)
			expect(SocialService._canRate(social, "43")).to.equal(true)
		end)
	end)
end
