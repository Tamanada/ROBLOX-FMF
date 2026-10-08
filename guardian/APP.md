# GUARDIAN CONTRACT: APP (FULL MOON FESTIVAL)

Version: 1.0, installed 2026-10-08 at commit df21a14.
Every claim is tagged FACT, INFERENCE, CONFIRMED, UNKNOWN or VERIFIED.

## Identity

- FACT: FULL MOON FESTIVAL (FMF), a Roblox tycoon / social simulation. Repo: github.com/Tamanada/ROBLOX-FMF, branch main.
- FACT: The binding design document is docs/BLUEPRINT.md v1.0 plus its dated amendments (starting balance, Zone 2/3 tables, Full Moon shards). No deviation without a Blueprint update first.
- FACT: Sprints S0 to S6 of the roadmap (Blueprint section 12) are implemented per README status tables.

## Stack

- FACT: Luau strict mode enforced via .luaurc (languageMode strict) and CI analysis.
- FACT: Rojo 7.4.4, wally (TestEZ 0.4.1), rokit toolchain (rokit.toml). Studio is used only for 3D placement and publishing (Blueprint 10.1).
- FACT: Persistence: ProfileStore (MadStudio), vendored at src/server/Packages/ProfileStore.luau with a nolint header patch, otherwise unmodified.
- FACT: 11 server services in src/server/Services: DataService, PlotService, EconomyService, HypeService, BuildService, NPCService, StaffService, EventService, FullMoonService, SocialService, MonetizationService.
- FACT: CI (.github/workflows/ci.yml): luau-lsp 1.36.0 strict analysis with pinned type defs + StyLua check. TestEZ is NOT executed in CI (no Studio on hosted runners).

## Environments

- FACT: There is no staging/production split in the repo. The published Roblox place is the production surface.
- FACT: Commit df21a14 wires live Game Pass and Developer Product ids into shared/Config/Monetization.luau.
- UNKNOWN, REQUIRES CONFIRMATION: whether the place is already published and public, and its place id.

## Critical entities and workflows

- Player profile (PlayerData v3): shells, moonShards, hype, prestigeCount, plots/equipment, staff, stats, passes, lastSeen.
- Join pipeline: session lock, plot assignment (12 per server), free campfire, equipment reload.
- Core loop: buy, upgrade, repair, revenue accrual, manual collect, reinvest.
- World: 16 min day/night cycle, cleanup flash, storms, monkeys, VIP boat, NPC crowd.
- Full Moon: global UTC clock every 7200 s, 10 min event, gated multipliers, Moon Shard grants.
- Social: visits, 1-5 star ratings, friend bonus. Monetization: 5 Game Passes, Shell packs, Hype Boost, Instant Repair.
