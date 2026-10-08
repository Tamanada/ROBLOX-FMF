# GUARDIAN CONTRACT: SECURITY (FULL MOON FESTIVAL)

Version: 1.0, 2026-10-08, commit df21a14.

## Security model

- CONFIRMED (Blueprint 10.3): server-authoritative everywhere. The client sends intents only; all economic values are computed server side; replicated values are display-only.

## Attack surface

- FACT: every client-to-server channel goes through the Net wrapper (src/shared/Util/Net.luau). Remotes are declared via Net.Server.Handle / Net.Server.Callback; the full inventory is the set of call sites of those two functions in src/server/Services.
- FACT (Net.luau): per-remote typed argument specs; wrong types and extra arguments are dropped and logged; NaN and Infinity numbers are rejected (accept/reject matrix in tests/Net.spec.luau).
- FACT (Net.luau): one shared rate limiter per player across ALL remotes, 10 requests per second in a rolling window; exceeding it kicks the player (Blueprint 10.3.2).
- FACT (BuildService): ownership and legality re-checks per intent: catalogue id, zone unlocked, plot bounds (NaN positions fail), balance via EconomyService.Debit, upgrade path, broken state.
- FACT (DataService): ProfileStore session locking; a second concurrent session is refused and the player is kicked; covered by DataService.spec against a mock store.

## Economic abuse monitoring

- FACT (EconomyService, Blueprint 11.4): per-player 60 s audit window; credits above theoretical rate x3 + 500 produce an [FMF][AUDIT] warn for human review. Review before any ban and before any economy patch.

## Compliance (Blueprint 11)

- FACT: no free-text input surface exists in src (no TextBox anywhere); section 11.3 (FilterStringAsync) is satisfied by absence. RULE: any future feature that displays player text MUST route it through TextService:FilterStringAsync before display.
- CONFIRMED (11.1): zero alcohol, drugs, gambling, suggestive content; fruit buckets only; no commercial music; no real people or business names. A compliance check is required for every new content batch (equipment names, staff lore, icons, audio).
- CONFIRMED (5.1, 11.2): gacha-style rolls display probabilities in game; no direct Robux rolls.

## Out of scope / UNVERIFIED

- UNVERIFIED: live exploit attempts against a running server (replay, flooding past the limiter, serialized CFrame abuse) have not been executed in this environment; they require a Studio or live test server. See TESTS.md gates.
- UNKNOWN: Roblox account/place permissions (collaborators, API keys) are outside the repo; manage them on the Creator Dashboard.
