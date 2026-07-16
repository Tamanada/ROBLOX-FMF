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

	-- §2.2 — revenus nuit ×2. Catalogue §4 rates are NIGHT rates; Sprint 1
	-- runs at the night basis until the day/night cycle lands in Sprint 2.
	NIGHT_REVENUE_MULTIPLIER = 2,

	-- §2.4 — revenus offline : 20 % du taux actif, cap 8 heures.
	OFFLINE_RATE = 0.2,
	OFFLINE_CAP_SECONDS = 8 * 3600,

	-- Server-side revenue accrual tick (0.1 min).
	REVENUE_TICK_SECONDS = 6,
})
