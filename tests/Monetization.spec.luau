--!nonstrict
-- tests/Monetization.spec.luau — Sprint 5 monetization (§8, §10.5).
-- The idempotency core is the compliance-critical piece (§8.4.3): a retried
-- receipt must NOT double-grant. Also checks config integrity + §8.4 rules.
-- Nonstrict: TestEZ injects describe/it/expect globals at runtime.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
	local MonetizationService = require(ServerScriptService.Server.Services.MonetizationService)

	describe("ProcessReceipt idempotency (§8.4.3 / §10.5)", function()
		it("grants a new PurchaseId exactly once", function()
			local history = {}
			-- First delivery of this receipt → claim succeeds (caller grants).
			expect(MonetizationService._claimPurchase(history, "purchase-1")).to.equal(true)
			expect(history["purchase-1"]).to.equal(true)
			-- Roblox re-delivers the SAME receipt → already granted, no re-grant.
			expect(MonetizationService._claimPurchase(history, "purchase-1")).to.equal(false)
			expect(MonetizationService._claimPurchase(history, "purchase-1")).to.equal(false)
		end)

		it("treats distinct PurchaseIds independently", function()
			local history = {}
			expect(MonetizationService._claimPurchase(history, "a")).to.equal(true)
			expect(MonetizationService._claimPurchase(history, "b")).to.equal(true)
			expect(MonetizationService._claimPurchase(history, "a")).to.equal(false)
		end)

		it("survives a rolled-back claim (grant failed → retry can succeed)", function()
			local history = {}
			expect(MonetizationService._claimPurchase(history, "x")).to.equal(true)
			history["x"] = nil -- caller rolled back after a failed grant
			expect(MonetizationService._claimPurchase(history, "x")).to.equal(true)
		end)
	end)

	describe("catalogue integrity (§8.1, §8.2)", function()
		it("has the five Game Passes at their Blueprint prices (§8.1)", function()
			expect(Monetization.passById.auto_collect.robux).to.equal(249)
			expect(Monetization.passById.vip_islander.robux).to.equal(399)
			expect(Monetization.passById.pyro_master.robux).to.equal(299)
			expect(Monetization.passById.golden_boat.robux).to.equal(199)
			expect(Monetization.passById.extra_plot.robux).to.equal(349)
		end)

		it("has the four Shell packs at their Blueprint tiers (§8.2)", function()
			local tiers = { 99, 249, 599, 1299 }
			local found = {}
			for _, product in Monetization.products do
				if product.effect == "shells" then
					found[product.robux] = product.amount
				end
			end
			for _, robux in tiers do
				expect(found[robux]).to.be.ok()
				expect(found[robux] > 0).to.equal(true) -- accelerator, not exclusive
			end
		end)

		it("every product effect is deterministic (§8.4.2 — no paid loot boxes)", function()
			local allowed = { shells = true, hypeBoost = true, repairAll = true }
			for _, product in Monetization.products do
				expect(allowed[product.effect]).to.equal(true)
			end
		end)
	end)
end
