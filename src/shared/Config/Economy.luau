--!strict
-- shared/Config/Economy.luau — Blueprint §2, §3, §10.
-- Single source of truth for every economic constant — services never
-- hardcode numbers (§10.3.3: replicated configs are read-only references;
-- the server recomputes every authoritative value from here).

return table.freeze({
	-- §6 — Serveurs 12 joueurs, chacun sa parcelle.
	PLOTS_PER_SERVER = 12,

	-- §10.4 — Autosave : 60 s + save on leave + save post-transaction Robux.
	AUTOSAVE_INTERVAL_SECONDS = 60,

	-- §10.3.2 — max 10 requêtes/s/joueur, kick au-delà.
	NET_MAX_REQUESTS_PER_SECOND = 10,

	-- Save-slot key inside PlayerData.plots ("Extra Plot Slot" pass adds
	-- more slots in Sprint 5 — §8.1).
	MAIN_PLOT_SLOT = "main",

	-- §3.2 (amendement Sprint 1, 2026-07-16) — starting balance enabling
	-- the D0 hook: free campfire + 3 immediate tier-1 purchases
	-- (100 + 250 + 400 = 750); the economic wall starts at tier 2.
	STARTING_SHELLS = 750,

	-- §4 — chaque équipement a 3 niveaux d'upgrade (revenu ×1.5/niveau,
	-- coût = 60 % du prix d'achat/niveau) ; réparation = 10 % du prix.
	UPGRADE_STEPS = 3,
	UPGRADE_REVENUE_MULTIPLIER = 1.5,
	UPGRADE_COST_RATIO = 0.6,
	REPAIR_COST_RATIO = 0.1,

	-- §3.3 — spend = base × (1 + Hype/100). Applied to equipment rates in
	-- S1; per-NPC spend takes over when NPCService lands (Sprint 2).
	HYPE_SPEND_DIVISOR = 100,

	-- §2.2 — revenus nuit ×2. Catalogue §4 rates are NIGHT rates: the night
	-- phase pays them in full (×1), the day phase pays half (×0.5) so night is
	-- ×2 of day. DAY_REVENUE_MULTIPLIER is kept in lockstep with
	-- NIGHT_REVENUE_MULTIPLIER (= 1 / NIGHT_REVENUE_MULTIPLIER).
	NIGHT_REVENUE_MULTIPLIER = 2,
	DAY_REVENUE_MULTIPLIER = 0.5,

	-- §2.2 — cycle jour/nuit : 16 minutes (10 min jour / 6 min nuit). Per
	-- server (the global Full Moon clock in §10.5 is a separate S3 concern).
	DAY_DURATION_SECONDS = 600,
	NIGHT_DURATION_SECONDS = 360,
	-- Convenience total; MUST equal DAY + NIGHT (asserted in tests).
	CYCLE_DURATION_SECONDS = 960,

	-- §2.4 — revenus offline : 20 % du taux actif, cap 8 heures. The "active
	-- rate" basis is the headline night rate (same basis as the audit ceiling).
	OFFLINE_RATE = 0.2,
	OFFLINE_CAP_SECONDS = 8 * 3600,

	-- Server-side revenue accrual tick (0.1 min).
	REVENUE_TICK_SECONDS = 6,

	------------------------------------------------------------------
	-- §3.3 — Hype dynamics (Sprint 2: cleanliness + per-cycle decay)
	------------------------------------------------------------------
	-- spawnRate = base × (1 + Hype/50) — NPC frequency divisor.
	HYPE_SPAWN_DIVISOR = 50,
	-- −5 pts/cycle si plage sale ou équipement cassé non réparé.
	HYPE_DECAY_PER_CYCLE = 5,
	-- Bounds for the runtime cleanliness/decay accumulator (equipment Hype is
	-- unbounded-summed then the whole thing is clamped 0-100 by HypeService).
	HYPE_MODIFIER_MIN = -20,
	HYPE_MODIFIER_MAX = 20,

	------------------------------------------------------------------
	-- §7 — Beach Cleanup Flash (après chaque nuit)
	------------------------------------------------------------------
	CLEANUP_TRASH_COUNT = 10,
	CLEANUP_WINDOW_SECONDS = 60,
	CLEANUP_HYPE_BONUS = 5,

	------------------------------------------------------------------
	-- §2.1 / §3.3 / §10.6 — NPC partygoers (living crowd)
	------------------------------------------------------------------
	-- Hard cap per plot (§10.6). Movement freezes beyond the LOD radius.
	NPC_MAX_PER_PLOT = 40,
	NPC_ANIMATION_LOD_STUDS = 50,
	-- Crowd target = base × (1 + Hype/HYPE_SPAWN_DIVISOR) × phase density,
	-- clamped to NPC_MAX_PER_PLOT. Night is a dense crowd (§2.2), day is calm.
	NPC_SPAWN_BASE = 12,
	NPC_NIGHT_DENSITY = 1.0,
	NPC_DAY_DENSITY = 0.4,
	-- Movement + lifecycle (waypoint walker, no PathfindingService — §10.6).
	NPC_WALK_SPEED = 9,
	NPC_STAY_SECONDS = 7,
	NPC_TOPUP_INTERVAL_SECONDS = 1.5,
	NPC_MAX_SPAWNS_PER_TOPUP = 3,

	------------------------------------------------------------------
	-- §2.3 / §10.5 — FULL MOON EVENT (global, UTC-synced)
	------------------------------------------------------------------
	-- Every 2 h real-time, aligned to UTC multiples of the period (00:00,
	-- 02:00 … UTC) via os.time() % PERIOD — all servers converge with no
	-- MessagingService in v1 (§10.5). Duration 10 min.
	FULL_MOON_PERIOD_SECONDS = 7200,
	FULL_MOON_DURATION_SECONDS = 600,
	-- Revenue multiplier during the event: ×5 if the max-gate is met, else ×2.
	FULL_MOON_REVENUE_MULTIPLIER_MAX = 5,
	FULL_MOON_REVENUE_MULTIPLIER_REDUCED = 2,
	-- Partygoer spawn ×3 during the event (still capped at NPC_MAX_PER_PLOT).
	FULL_MOON_SPAWN_MULTIPLIER = 3,
	-- §2.3 max-gate: Hype ≥ 80 % + all repaired + ≥1 staff/zone (staff stubbed
	-- until StaffService, S4 — see Blueprint §2.3 amendment).
	FULL_MOON_HYPE_THRESHOLD = 80,
	-- §2.3 amendment (2026-07-17) — Moon Shards granted per event to each
	-- present player: MAX if eligible for the ×5 gate, BASE otherwise.
	FULL_MOON_SHARDS_MAX = 5,
	FULL_MOON_SHARDS_BASE = 2,
})
