--!nonstrict
-- tests/Net.spec.luau — validation & rejet du wrapper Net (§10.3).
-- Nonstrict: TestEZ injects describe/it/expect globals at runtime.
-- Production code under src/ stays --!strict.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Net = require(ReplicatedStorage.Shared.Util.Net)

	describe("Net._validate (type-check des arguments)", function()
		it("accepts arguments matching the spec", function()
			local ok, reason = Net._validate({ "string", "number" }, table.pack("smoothie_stand", 5))
			expect(ok).to.equal(true)
			expect(reason).never.to.be.ok()
		end)

		it("rejects a wrong primitive type", function()
			local ok, reason = Net._validate({ "string" }, table.pack(42))
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
		end)

		it("rejects a missing required argument", function()
			local ok = Net._validate({ "string", "number" }, table.pack("only_one"))
			expect(ok).to.equal(false)
		end)

		it("rejects extra arguments beyond the spec", function()
			local ok, reason = Net._validate({ "string" }, table.pack("a", "b"))
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
		end)

		it('accepts nil for an optional argument ("number?")', function()
			local ok = Net._validate({ "string", "number?" }, table.pack("dance_floor"))
			expect(ok).to.equal(true)
		end)

		it("still type-checks an optional argument when it is provided", function()
			local ok = Net._validate({ "number?" }, table.pack("not_a_number"))
			expect(ok).to.equal(false)
		end)

		it("rejects NaN for a number argument (exploit payload)", function()
			local ok, reason = Net._validate({ "number" }, table.pack(0 / 0))
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
		end)

		it("rejects Infinity and -Infinity for a number argument", function()
			-- extra parens truncate _validate's multi-return to one value
			expect((Net._validate({ "number" }, table.pack(math.huge)))).to.equal(false)
			expect((Net._validate({ "number" }, table.pack(-math.huge)))).to.equal(false)
		end)

		it("still accepts ordinary finite numbers (zero, negative, float)", function()
			expect((Net._validate({ "number" }, table.pack(0)))).to.equal(true)
			expect((Net._validate({ "number" }, table.pack(-12.5)))).to.equal(true)
		end)

		it("validates Roblox types via typeof (Vector3, CFrame)", function()
			local ok = Net._validate({ "Vector3", "CFrame" }, table.pack(Vector3.new(1, 2, 3), CFrame.new()))
			expect(ok).to.equal(true)

			local bad = Net._validate({ "Vector3" }, table.pack(CFrame.new()))
			expect(bad).to.equal(false)
		end)

		it("supports custom predicate checkers", function()
			local function isPositiveNumber(value)
				return type(value) == "number" and value > 0
			end

			local ok = Net._validate({ isPositiveNumber }, table.pack(7))
			expect(ok).to.equal(true)

			local bad = Net._validate({ isPositiveNumber }, table.pack(-3))
			expect(bad).to.equal(false)
		end)

		it("rejects (without throwing) when a custom predicate errors", function()
			local function explosive(_value)
				error("boom")
			end

			local ok, reason = Net._validate({ explosive }, table.pack("anything"))
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
		end)
	end)

	describe("Net._createLimiter (rate limiting 10 req/s/joueur — §10.3.2)", function()
		local function makeClock()
			local t = 0
			return {
				now = function()
					return t
				end,
				advance = function(delta)
					t += delta
				end,
			}
		end

		it("allows exactly 10 requests within one second", function()
			local clock = makeClock()
			local limiter = Net._createLimiter(Net.MAX_REQUESTS_PER_SECOND, clock.now)

			for i = 1, 10 do
				expect(limiter.check("player1")).to.equal(true)
			end
		end)

		it("blocks the 11th request inside the same window", function()
			local clock = makeClock()
			local limiter = Net._createLimiter(Net.MAX_REQUESTS_PER_SECOND, clock.now)

			for _ = 1, 10 do
				limiter.check("player1")
			end
			expect(limiter.check("player1")).to.equal(false)
		end)

		it("resets once the 1-second window has elapsed", function()
			local clock = makeClock()
			local limiter = Net._createLimiter(Net.MAX_REQUESTS_PER_SECOND, clock.now)

			for _ = 1, 11 do
				limiter.check("player1")
			end
			expect(limiter.check("player1")).to.equal(false)

			clock.advance(1.05)
			expect(limiter.check("player1")).to.equal(true)
		end)

		it("tracks each player independently", function()
			local clock = makeClock()
			local limiter = Net._createLimiter(Net.MAX_REQUESTS_PER_SECOND, clock.now)

			for _ = 1, 11 do
				limiter.check("spammer")
			end
			expect(limiter.check("spammer")).to.equal(false)
			expect(limiter.check("innocent")).to.equal(true)
		end)

		it("clear() forgets a player's window (leave cleanup)", function()
			local clock = makeClock()
			local limiter = Net._createLimiter(Net.MAX_REQUESTS_PER_SECOND, clock.now)

			for _ = 1, 11 do
				limiter.check("player1")
			end
			expect(limiter.check("player1")).to.equal(false)

			limiter.clear("player1")
			expect(limiter.check("player1")).to.equal(true)
		end)
	end)
end
