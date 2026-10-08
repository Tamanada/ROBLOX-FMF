# APP GUARDIAN REPORT: installation + initial audit

- Project: FULL MOON FESTIVAL (Tamanada/ROBLOX-FMF)
- Version/commit: df21a14b3c03805b9790d4f98f85d1d1237947ed (main)
- Environment: local repo audit on David's Windows machine; no live Roblox server available in this session
- Date: 2026-10-08
- Status: RELEASE UNVERIFIED (static gates PASS with evidence; mandatory runtime gates not executable in this environment)

## Evidence collected (VERIFIED in this session)

- VERIFIED: luau-lsp 1.36.0 strict analysis at df21a14: PASS, zero diagnostics (local run, pinned defs, Rojo sourcemap).
- VERIFIED: StyLua check at df21a14: PASS.
- VERIFIED: CI (GitHub Actions) green on the latest pushed run; the repo was 5 commits ahead of origin/main at audit start (see G-001).
- FACT (code inspection): ProcessReceipt idempotence pattern present (claim PurchaseId before grant, PurchaseGranted on known id, NotProcessedYet without profile).
- FACT (code inspection): session locking, Net validation incl. NaN/Infinity rejection, 10 req/s kick, integer-only wallet, audit window per Blueprint 11.4.
- FACT: no free-text input surface in src; Blueprint 11.3 satisfied by absence.

## Area status

| Area | Status | Basis |
| --- | --- | --- |
| Functional | UNVERIFIED | TestEZ suites exist (9 spec files) but require Studio; not executed here |
| Security | PASS (static) / UNVERIFIED (runtime) | invariants verified in code and specs; no live attack pass |
| Data | PASS (static) / UNVERIFIED (runtime) | schema v3 + migration chain + specs; no live DataStore round trip |
| Accounting | PASS (static) / UNVERIFIED (runtime) | invariants + idempotence in code; no test purchase executed |
| UX | UNVERIFIED | requires Studio/device sessions |
| Performance | UNVERIFIED | budget documented (Blueprint 10.6); no live measurement |
| Regression | PASS (static) | analysis + style at HEAD; CI green on pushed history |

## Findings

ID: G-001
Area: Process
Severity: P3
Status: RESOLVED (pushed during this audit)
Scenario: main was 5 commits ahead of origin/main; unpushed work had no CI coverage.
Expected: every commit reaches origin and CI.
Actual: 5 local-only commits at audit start.
Evidence: git status -sb (ahead 5), GitHub Actions run list.
Recommended fix: push after each working session.
Release impact: none once pushed.

ID: G-002
Area: Business rules
Severity: P3
Status: OPEN, founder decision required
Scenario: Blueprint 3.2 payback target (tier 1: 2-3 min) contradicts the binding section 4 rates (about 12.5 min).
Evidence: Smoothie Stand 100 Shells at 8 Shells/min.
Recommended fix: amend 3.2 to define payback as measured with live multipliers, calibrate in playtest.
Release impact: none at runtime; documentation consistency only.

ID: G-003
Area: Test infrastructure
Severity: UNVERIFIED
Status: OPEN
Scenario: TestEZ cannot run headless in CI; runtime evidence depends on manual Studio runs.
Recommended fix: record a Studio TestEZ output in guardian/reports/ per release; evaluate run-in-roblox on a self-hosted runner later.
Release impact: blocks certification (keeps status UNVERIFIED) until a recorded Studio run exists.

## Required actions before a release certification

1. Run the full TestEZ suite in Studio and record the output here.
2. Verify Full Moon sync on 2 simultaneous servers (S3 DoD).
3. Execute one test Robux purchase with a forced retry (S5 DoD).
4. Confirm place publication status and place id in guardian/APP.md.

## Certification

RELEASE UNVERIFIED. No blocking finding; mandatory runtime evidence is missing by environment limitation, not by failure. Never convert UNVERIFIED to PASS.
