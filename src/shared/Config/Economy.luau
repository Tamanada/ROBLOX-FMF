--!strict
-- shared/Config/Economy.luau — Blueprint §3 (économie chiffrée).
-- Sprint 0 carries ONLY infrastructure constants. Currency curves, paybacks
-- and multipliers land in Sprint 1 (Roadmap §12) — no gameplay before S1.

return table.freeze({
	-- §6 — Serveurs 12 joueurs, chacun sa parcelle.
	PLOTS_PER_SERVER = 12,

	-- §10.4 — Autosave : 60 s + save on leave + save post-transaction Robux.
	AUTOSAVE_INTERVAL_SECONDS = 60,

	-- §10.3.2 — max 10 requêtes/s/joueur, kick au-delà.
	NET_MAX_REQUESTS_PER_SECOND = 10,
})
