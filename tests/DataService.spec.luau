--!nonstrict
-- tests/DataService.spec.luau — défauts v1 & migrations (§10.4), plus le
-- cycle session/persistance contre le mock ProfileStore.
-- Nonstrict: TestEZ injects describe/it/expect globals at runtime.

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Players = game:GetService("Players")

	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local DataService = require(ServerScriptService.Server.Services.DataService)
	local Economy = require(ReplicatedStorage.Shared.Config.Economy)
	local MockProfileStore = require(script.Parent.Mocks.MockProfileStore)

	local function makeMockPlayer(userId)
		local player = {
			UserId = userId,
			Name = `TestPlayer{userId}`,
			Parent = Players, -- DataService checks `player.Parent ~= Players`
		}
		function player:Kick(message)
			self.kickedWith = message or "(no message)"
		end
		return player
	end

	beforeEach(function()
		DataService._resetForTests()
		DataService.Init({ profileStore = MockProfileStore, storeName = "TestPlayerData" })
	end)

	describe("TEMPLATE (défauts du schéma v2 — §10.4)", function()
		it("carries every field with its default", function()
			local template = DataService.TEMPLATE
			expect(template.dataVersion).to.equal(2)
			-- §3.2 amendment (Sprint 1): starting balance enables the D0 hook.
			expect(template.shells).to.equal(Economy.STARTING_SHELLS)
			expect(template.moonShards).to.equal(0)
			expect(template.hype).to.equal(0)
			expect(template.prestigeCount).to.equal(0)
			expect(type(template.plots)).to.equal("table")
			expect(type(template.staff)).to.equal("table")
			expect(template.stats.totalEarned).to.equal(0)
			expect(template.stats.fullMoonsAttended).to.equal(0)
			expect(template.stats.visits).to.equal(0)
			expect(type(template.passes)).to.equal("table")
			-- §4 (schema v2) — Zone 1 unlocked from the start.
			expect(type(template.unlockedZones)).to.equal("table")
			expect(template.unlockedZones["1"]).to.equal(true)
			expect(template.lastSeen).to.equal(0)
		end)

		it("matches DATA_VERSION", function()
			expect(DataService.TEMPLATE.dataVersion).to.equal(DataService.DATA_VERSION)
		end)
	end)

	describe("migrations (MigrateTo / Migrate)", function()
		it("is a no-op when data is already at the target version", function()
			local data = { dataVersion = 1, shells = 99 }
			DataService.Migrate(data)
			expect(data.dataVersion).to.equal(1)
			expect(data.shells).to.equal(99)
		end)

		it("applies chained migrations in order and stamps dataVersion", function()
			local calls = {}
			local data: any = { dataVersion = 1 }

			DataService.MigrateTo(data, 3, {
				[2] = function(d)
					table.insert(calls, 2)
					d.addedInV2 = true
				end,
				[3] = function(d)
					table.insert(calls, 3)
					d.addedInV3 = true
				end,
			})

			expect(data.dataVersion).to.equal(3)
			expect(#calls).to.equal(2)
			expect(calls[1]).to.equal(2)
			expect(calls[2]).to.equal(3)
			expect(data.addedInV2).to.equal(true)
			expect(data.addedInV3).to.equal(true)
		end)

		it("errors loudly when a migration step is missing", function()
			expect(function()
				DataService.MigrateTo({ dataVersion = 1 }, 3, {})
			end).to.throw()
		end)

		it("treats a missing dataVersion as version 1", function()
			local data: any = {}
			DataService.MigrateTo(data, 2, {
				[2] = function(d)
					d.patched = true
				end,
			})
			expect(data.dataVersion).to.equal(2)
			expect(data.patched).to.equal(true)
		end)
	end)

	describe("session lifecycle (mock ProfileStore)", function()
		it("gives a brand-new player the template defaults", function()
			local player = makeMockPlayer(1)
			local profile = DataService.LoadAsync(player)
			expect(profile).to.be.ok()

			local data = DataService.Get(player)
			expect(data).to.be.ok()
			expect(data.shells).to.equal(Economy.STARTING_SHELLS)
			expect(data.dataVersion).to.equal(DataService.DATA_VERSION)

			DataService.Release(player)
		end)

		it("persists data between two sessions (DoD Sprint 0)", function()
			local firstSession = makeMockPlayer(2)
			DataService.LoadAsync(firstSession)

			local data = DataService.Get(firstSession)
			data.shells = 1234
			data.stats.visits = 7
			DataService.Release(firstSession)
			expect(DataService.Get(firstSession)).never.to.be.ok()

			local secondSession = makeMockPlayer(2) -- same UserId, fresh join
			DataService.LoadAsync(secondSession)

			local reloaded = DataService.Get(secondSession)
			expect(reloaded).to.be.ok()
			expect(reloaded.shells).to.equal(1234)
			expect(reloaded.stats.visits).to.equal(7)

			DataService.Release(secondSession)
		end)

		it("refuses a second concurrent session and kicks (session-locking)", function()
			local sessionA = makeMockPlayer(3)
			expect(DataService.LoadAsync(sessionA)).to.be.ok()

			local sessionB = makeMockPlayer(3)
			local profileB = DataService.LoadAsync(sessionB)
			expect(profileB).never.to.be.ok()
			expect(sessionB.kickedWith).to.be.ok()

			DataService.Release(sessionA)
		end)

		it("reconciles missing keys on an old, incomplete save", function()
			-- Seed a save missing most v1 keys (as if written by an older build).
			local store = MockProfileStore._lastStore
			store:_seed("Player_4", { dataVersion = 1, shells = 50 })

			local player = makeMockPlayer(4)
			DataService.LoadAsync(player)

			local data = DataService.Get(player)
			expect(data.shells).to.equal(50) -- existing value kept
			expect(data.moonShards).to.equal(0) -- missing keys filled in
			expect(data.stats.visits).to.equal(0)
			expect(type(data.passes)).to.equal("table")
			-- §4 — the v1→v2 migration unlocks Zone 1 and stamps the version.
			expect(data.dataVersion).to.equal(2)
			expect(data.unlockedZones["1"]).to.equal(true)

			DataService.Release(player)
		end)
	end)
end
