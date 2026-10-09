--!strict
-- shared/Util/MoonCycle.luau — Blueprint §14.4 (cycle lunaire accéléré).
-- 1 cycle in-game = 1 période Full Moon réelle (§10.5) : tout est dérivé du
-- MÊME os.time() % FULL_MOON_PERIOD_SECONDS que FullMoonService, donc la
-- phase FULL_MOON coïncide EXACTEMENT avec la fenêtre d'event §2.3
-- ([0, FULL_MOON_DURATION_SECONDS) de chaque période) sur tous les serveurs.
-- Module pur : toutes les fonctions acceptent un `now` explicite pour les
-- tests (défaut os.time()).

local Economy = require(script.Parent.Parent.Config.Economy)

local MoonCycle = {}

export type Phase = string
-- "FULL_MOON" | "POST_FULL" | "HALF_MOON" | "NEW_MOON" | "FULL_MOON_EVE"

export type Segment = {
	phase: Phase,
	startOffset: number, -- secondes depuis le début du cycle (début = event Full Moon)
	endOffset: number,
}

export type PhaseInfo = {
	phase: Phase,
	startsAt: number, -- epoch UTC
	endsAt: number, -- epoch UTC
}

local PERIOD = Economy.FULL_MOON_PERIOD_SECONDS -- 7200
local FULL_DURATION = Economy.FULL_MOON_DURATION_SECONDS -- 600

-- §14.4 — découpage d'un cycle (somme = PERIOD, vérifié par les tests).
-- HALF_MOON apparaît deux fois, symétrique autour de la pleine lune ;
-- FULL_MOON_EVE est la fenêtre "Jungle Experience", juste avant FULL_MOON.
local SEGMENTS: { Segment } = table.freeze({
	table.freeze({ phase = "FULL_MOON", startOffset = 0, endOffset = FULL_DURATION }),
	table.freeze({ phase = "POST_FULL", startOffset = FULL_DURATION, endOffset = 1500 }),
	table.freeze({ phase = "HALF_MOON", startOffset = 1500, endOffset = 2700 }),
	table.freeze({ phase = "NEW_MOON", startOffset = 2700, endOffset = 4500 }),
	table.freeze({ phase = "HALF_MOON", startOffset = 4500, endOffset = 5700 }),
	table.freeze({ phase = "FULL_MOON_EVE", startOffset = 5700, endOffset = PERIOD }),
})

MoonCycle.SEGMENTS = SEGMENTS
MoonCycle.PERIOD_SECONDS = PERIOD

function MoonCycle.GetPhase(now: number?): PhaseInfo
	local time = now or os.time()
	local into = time % PERIOD
	local cycleStart = time - into

	for _, segment in SEGMENTS do
		if into >= segment.startOffset and into < segment.endOffset then
			return {
				phase = segment.phase,
				startsAt = cycleStart + segment.startOffset,
				endsAt = cycleStart + segment.endOffset,
			}
		end
	end

	-- Unreachable (les segments couvrent [0, PERIOD)) ; garde-fou strict.
	error("[MoonCycle] no segment covers offset " .. tostring(into))
end

-- Epoch UTC du prochain début de `phase`. Si `now` est DANS une fenêtre de
-- cette phase, retourne le début de la fenêtre courante (les appelants
-- détectent "actif" via GetPhase).
function MoonCycle.GetNextPhaseAt(phase: Phase, now: number?): number
	local time = now or os.time()
	local into = time % PERIOD
	local cycleStart = time - into

	local best: number? = nil
	for _, segment in SEGMENTS do
		if segment.phase == phase then
			local candidate: number
			if into >= segment.startOffset and into < segment.endOffset then
				candidate = cycleStart + segment.startOffset
			elseif into < segment.startOffset then
				candidate = cycleStart + segment.startOffset
			else
				candidate = cycleStart + PERIOD + segment.startOffset
			end
			if best == nil or candidate < best then
				best = candidate
			end
		end
	end

	if best == nil then
		error(`[MoonCycle] unknown phase "{phase}"`)
	end
	return best
end

return MoonCycle
