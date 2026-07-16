--!strict
-- shared/Util/EconomyMath.luau — pure economic formulas (Blueprint §2.4,
-- §3.3, §4). Shared so the client can DISPLAY prices, while the server
-- recomputes every authoritative value from the same source (§10.3.3).
-- All functions are pure — unit-tested in tests/Economy.spec.luau.

local Economy = require(script.Parent.Parent.Config.Economy)

local EconomyMath = {}

-- §4 — 3 upgrade levels: purchase = level 1, max = level 4.
function EconomyMath.maxLevel(): number
	return 1 + Economy.UPGRADE_STEPS
end

-- §4 — each upgrade level costs 60 % of the purchase price.
function EconomyMath.upgradeCost(purchaseCost: number): number
	return math.floor(purchaseCost * Economy.UPGRADE_COST_RATIO + 0.5)
end

-- §4 — repair costs 10 % of the purchase price.
function EconomyMath.repairCost(purchaseCost: number): number
	return math.floor(purchaseCost * Economy.REPAIR_COST_RATIO + 0.5)
end

-- §4 — revenue ×1.5 per upgrade level above 1.
function EconomyMath.revenuePerMinute(nightRate: number, level: number): number
	return nightRate * Economy.UPGRADE_REVENUE_MULTIPLIER ^ (level - 1)
end

-- §3.3 — spend = base × (1 + Hype/100), applied to the equipment rate in S1.
function EconomyMath.effectiveRate(nightRate: number, level: number, hype: number): number
	return EconomyMath.revenuePerMinute(nightRate, level) * (1 + hype / Economy.HYPE_SPEND_DIVISOR)
end

-- §2.4 — offline: 20 % of the active rate, capped at 8 hours. Floors to an
-- integer Shell amount (currency is always integer).
function EconomyMath.offlineEarnings(ratePerMinute: number, elapsedSeconds: number): number
	if ratePerMinute <= 0 or elapsedSeconds <= 0 then
		return 0
	end
	local seconds = math.min(elapsedSeconds, Economy.OFFLINE_CAP_SECONDS)
	return math.floor((ratePerMinute / 60) * seconds * Economy.OFFLINE_RATE)
end

return EconomyMath
