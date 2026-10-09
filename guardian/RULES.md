# GUARDIAN CONTRACT: RULES (FULL MOON FESTIVAL)

Version: 1.0, 2026-10-08. CONFIRMED = binding (Blueprint or founder-approved amendment). These rules are testable invariants.

## Currencies

- CONFIRMED (Blueprint 3.1): Shells are the soft currency, buyable via Developer Products. Moon Shards are earn-only and must NEVER be sold for Robux.
- CONFIRMED (3.2 amendment, 2026-07-16): starting balance is 750 Shells.
- FACT (EconomyService): Shells amounts are integers only; NaN, Infinity, negatives and fractions are rejected at the wallet boundary.

## Economy curves

- CONFIRMED (Blueprint 4): each equipment has 3 upgrade steps (max level 4), revenue x1.5 per level, upgrade cost 60 percent of purchase price per level, repair cost 10 percent, broken equipment earns 0 and carries a Hype malus.
- CONFIRMED (2.2): catalogue rates are night rates; day pays x0.5; night is x2 of day. Cycle 960 s (600 day, 360 night).
- CONFIRMED (2.4): offline earnings are 20 percent of the active rate, capped at 8 hours.
- CONFIRMED (3.3): Hype 0-100; spawnRate base x (1 + Hype/50); spend base x (1 + Hype/100); decay 5 points per cycle when dirty or broken.
- NON-CONFORMING, OPEN (recorded 2026-07-16): Blueprint 3.2 states tier 1 payback of 2-3 minutes, but the binding section 4 values give about 12.5 minutes (Smoothie Stand 100 / 8 per min). Founder decision required; do not change code or Blueprint without it.

## Full Moon

- CONFIRMED (2.3, 10.5): event every 7200 s aligned to UTC via os.time() modulo, duration 600 s, all servers converge without MessagingService.
- CONFIRMED (2.3): max multiplier x5 requires Hype >= 80, all equipment repaired, at least 1 staff per unlocked zone; otherwise x2. Spawn x3 during the event.
- CONFIRMED (2.3 amendment, 2026-07-17): Moon Shards per event: 5 if eligible for the max gate, else 2.

## Zones and prestige

- CONFIRMED (4): Zone 2 unlock 75000 Shells + Hype 60. Zone 3 unlock 500000 Shells + Hype 75 + 1 prestige OR 50 Moon Shards.
- CONFIRMED (2.3): prestige grants a permanent +10 percent revenue per prestige, capped at x2.5, and requires reaching Zone 3.

## Staff

- CONFIRMED (5): roll 500 Shells (Common/Rare pool) or 5 Moon Shards (Epic guaranteed minimum). Drop rates 60/30/9/1 MUST be displayed in game. No direct Robux rolls. Fusion: 3 duplicates into 1 higher rarity.

## Island map and transport (S7, Blueprint 14 — added 2026-10-09)

- CONFIRMED (14.2): 5 island zones; Haad Rin always unlocked; Baan Tai at 2 Haad Rin venues; Thong Sala at 1 Haad Rin + 1 Baan Tai venue; Haad Yuan at all 4 Haad Rin venues; Haad Thien after 1 Haad Yuan visit. Unlocks are recomputed from persisted facts, never stored.
- CONFIRMED (14.3): transport fare 50 Shells per route, trip 120 s, skip total = fare x2. All boarding checks and debits are server side.
- CONFIRMED (14.4): in-game moon cycle = one real Full Moon period (7200 s); FULL_MOON phase equals the 2.3 event window exactly.
- CONFIRMED (14.5): neutral venue ids until fictionalized names land; Dancing Elephant Hostel approved (founder-owned brand). No third-party real business names, ever (11.1).

## Monetization

- CONFIRMED (8.4): no gameplay-critical content exclusive to Robux; no direct paid loot boxes; every Developer Product goes through idempotent ProcessReceipt.
- CONFIRMED (8.2): Shell pack pricing is indexed on 15-20 minutes of equivalent farming, never more.
