# GUARDIAN CONTRACT: ACCOUNTING (FULL MOON FESTIVAL)

Version: 1.0, 2026-10-08, commit df21a14.
The in-game economy is treated with accounting discipline: integer currency, validated mutations, idempotent money-adjacent operations, reconciliation tests.

## Invariants

- FACT (EconomyService): Shells are integers. Credit and Debit validate every amount (finite, integer, >= 0) and refuse otherwise. Debit refuses on insufficient balance and performs no partial write.
- FACT (BuildService): fractional revenue accrues in a runtime pool and is floored to an integer on collect; the leftover pool is banked on leave so nothing is lost between sessions.
- FACT (EconomyService): stats.totalEarned counts only earned reasons (collect, offline), never purchased Shells.
- CONFIRMED (Blueprint 3.1): Moon Shards are earn-only. Grant paths: Full Moon events, achievements, prestige. Any code path selling Shards for Robux is a P0.
- FACT (DataService): schema is versioned (DATA_VERSION 3) with an ordered migration chain that errors loudly on a missing step; template and migrations are covered by DataService.spec.

## Robux money path (Blueprint 8.4)

- FACT (MonetizationService): ProcessReceipt claims the PurchaseId in the profile BEFORE granting; a retry with a known PurchaseId returns PurchaseGranted without double-granting; an unavailable profile returns NotProcessedYet. Static evidence: src/server/Services/MonetizationService.luau.
- FACT (DataService.SaveNow): an immediate save follows every Robux grant (Blueprint 10.4).
- UNVERIFIED: a real test purchase in Studio (including a forced retry) has not been executed in this environment. Mandatory release gate, see TESTS.md.

## Reconciliation

- FACT: tests/Economy.spec.luau holds the binding catalogue matrix (Blueprint 4) and the formula suite (upgrade cost, revenue per level, repair, Hype multiplier, offline cap). A config value drifting from the Blueprint fails the suite.
- RULE: before any economy patch, re-run the Economy and Monetization suites and review open [FMF][AUDIT] flags. Audit before banning, audit before patching (Blueprint 11.4).
