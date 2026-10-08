# GUARDIAN CONTRACT: TESTS (FULL MOON FESTIVAL)

Version: 1.0, 2026-10-08, commit df21a14.

## How to run

Static (local, same as CI):

```text
rojo sourcemap default.project.json -o sourcemap.json
curl -sLO https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.36.0/scripts/globalTypes.d.luau
luau-lsp analyze --defs=globalTypes.d.luau --defs=testez.d.luau --sourcemap=sourcemap.json --ignore "Packages/**" --ignore "**/Packages/**" src tests
stylua --check src tests
```

Important: globalTypes.d.luau MUST come from the luau-lsp version tag matching the binary (1.36.0). The main branch defs use newer syntax and silently fail to load on older binaries.

Runtime (TestEZ, Studio only):

1. wally install, then rojo serve and connect the Rojo plugin in Studio.
2. Set the Workspace attribute FMF_RunTests = true.
3. Run (F8). Results print in the Output window. TestEZ specs are nonstrict by design (TestEZ injects describe/it/expect); all production code is strict.

## Suite inventory (FACT, tests/)

- Net.spec.luau: argument validation accept/reject matrix (incl. NaN/Infinity), rate limiter window behavior.
- DataService.spec.luau: v3 template defaults, migration chain, persistence across sessions, session locking, reconcile.
- Economy.spec.luau: binding Blueprint 4 catalogue matrix, economy formulas, plot bounds, plot rate.
- World.spec.luau, FullMoon.spec.luau, Staff.spec.luau, Social.spec.luau, Monetization.spec.luau, Prestige.spec.luau: per-system invariants (cycle math, FM gate and shard grants, fusion, ratings, idempotent receipts, prestige caps).
- Mocks/: MockProfileStore (in-memory store with session locks).

## Evidence limits

- FACT: CI runs static analysis only. TestEZ does NOT run headless on GitHub runners; runtime evidence must come from a Studio run, recorded (screenshot or pasted output) in guardian/reports/.

## Mandatory release gates

1. Static: luau-lsp strict analysis + StyLua PASS (CI green).
2. Full TestEZ suite PASS in Studio, output recorded.
3. Full Moon synchronization observed on 2 simultaneous servers (Blueprint 12, S3 DoD).
4. One test Robux purchase in Studio, including a forced ProcessReceipt retry, no double grant (S5 DoD).
5. Compliance checklist (Blueprint 11) on any new content since the last release.
6. No open P0/P1, no mandatory UNVERIFIED.
