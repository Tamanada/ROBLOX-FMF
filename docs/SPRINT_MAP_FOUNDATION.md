# Sprint 7 — Island Map Foundation + NPC Transport (récap)

Référence contraignante : Blueprint §14 (amendement du 09/10/2026). Statut : livré, venues et activités restent des placeholders (non-goals respectés).

## Ce qui a été construit

- **5 zones** (`Config/Island.luau`) : Haad Rin (hub, spawn, plots, Dancing Elephant Hostel + 4 slots de venues neutres + 3 activités plage), Baan Tai (2 slots), Thong Sala (3 slots NPC), Haad Yuan (bateau uniquement, 2 slots), Haad Thien (1 slot libre). Chaque zone est un dossier Workspace/Island/<id> généré par `IslandZoneService` : sol, panneau, pads étiquetés.
- **Transport NPC** (`TransportService`) : stations songthaew et longtail avec chauffeur bloc et ProximityPrompt. Chaîne serveur à l'embarquement : zone courante, unlock destination, débit du fare, siège verrouillé (WalkSpeed et saut à 0), trajet par waypoints 120 s, skip payant, dépose au spawn. Un clone de véhicule par trajet : plusieurs joueurs voyagent en parallèle.
- **Sentiers** Haad Yuan <-> Haad Thien : pads ProximityPrompt gratuits, unlock vérifié.
- **Unlock progressif** (`UnlockService` + `Util/UnlockRules` pur) : règles §14.2 dans `Config/Unlocks.luau`, évaluées depuis les faits persistés (schéma v4 : `island.completedVenues`, `island.zoneVisits`). Liste débloquée répliquée en attribut `FMF_UnlockedZones` (display-only).
- **MoonCycle** (`Util/MoonCycle` pur + `MoonCycleService`) : FULL_MOON (0-600 s) coïncide exactement avec l'event §2.3, POST_FULL 900 s, HALF_MOON 1200 s, NEW_MOON 1800 s, HALF_MOON 1200 s, FULL_MOON_EVE 1500 s (fenêtre Jungle). HUD chip avec compte à rebours.
- **Dev Panel** (`DebugAdminService` + `DevPanelController`) : valider une venue, reset la progression. Allowlist UserId VIDE pour l'instant, donc utilisable uniquement en Studio.
- **Client** : `MapController` (5 zones, verrouillées grisées mais visibles, itinéraires dérivés des routes), `TransportController` (bandeau + skip), `MoonCycleController`.

## Config à régler (source de vérité unique)

| Quoi | Où |
|---|---|
| Fares, durées, multiplicateur skip, chemins des véhicules | `src/shared/Config/Routes.luau` |
| Règles d'unlock | `src/shared/Config/Unlocks.luau` |
| Zones, venues, activités, spawns | `src/shared/Config/Island.luau` |
| Découpage des phases lunaires | `src/shared/Util/MoonCycle.luau` (SEGMENTS) |
| Allowlist du Dev Panel | `src/server/Services/DebugAdminService.luau` (TODO UserId David) |

## Comment tester (Studio)

1. `wally install` puis `rojo serve`, connecter le plugin, Play (F5).
2. En Studio, le Dev Panel est automatiquement autorisé : bouton DEV en bas à droite.
3. Smoke test transport : au spawn (Haad Rin), rejoindre la station songthaew ou longtail (prompts au bord de la zone). Vérifier : destination verrouillée refusée avec message, fare débité (leaderstats -50), siège verrouillé, bandeau + countdown, skip (+50), dépose au spawn destination.
4. Parcours d'unlock complet : DEV -> valider hr_venue_1 et hr_venue_2 (Baan Tai se débloque, notification), puis bt_venue_1 (Thong Sala), puis hr_venue_3 et hr_venue_4 (Haad Yuan), voyager vers Haad Yuan (Haad Thien se débloque par la visite), sentier vers Haad Thien.
5. Persistance : quitter, relancer, vérifier que venues complétées et zones débloquées sont conservées (ProfileStore v4).
6. Specs : attribut Workspace `FMF_RunTests = true` puis Run (F8) : `tests/Island.spec.luau` couvre la matrice d'unlock, la math MoonCycle, l'intégrité des configs et la migration v4.

## Limites connues

- Les routes des véhicules sont des polylignes simples (pas de pathfinding, non-goal S7) : le tracé final sera ajusté avec le terrain Studio.
- `CompleteVenue` est une API module serveur ; le seul chemin client passe par le Dev Panel (allowlist). Les venues réelles l'appelleront directement dans leurs sprints.
- Allowlist vide tant que David n'a pas fourni son UserId Roblox (profil Roblox : le numéro dans l'URL `roblox.com/users/<ID>/profile`).
