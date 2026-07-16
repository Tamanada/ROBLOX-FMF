# FULL MOON FESTIVAL 🌕

Tycoon Roblox — Koh Phangan. **[`docs/BLUEPRINT.md`](docs/BLUEPRINT.md) est le document contraignant** : architecture §10, règles serveur-autoritaire §10.3, économie §3–§4. Aucune déviation sans mise à jour préalable du Blueprint.

## État

### Sprint 0 (Fondations) ✅

| Tâche | Statut |
|---|---|
| Structure repo §10.2 + `default.project.json` (Rojo 7), Luau `--!strict` | ✅ |
| `shared/Util/Net.luau` — validation de types (+ rejet NaN/Infinity) + rate limiting 10 req/s/joueur (kick) | ✅ |
| `DataService` — ProfileStore (vendoré), session-locking, autosave 60 s, save on leave, migrations | ✅ |
| `PlotService` — 12 plots/serveur, attribution au join, libération au leave, reload équipements | ✅ |
| Tests TestEZ — Net (validation/rejet), DataService (défauts, migration, persistance) | ✅ |

### Sprint 1 (Boucle cœur) ✅

| Tâche | Statut |
|---|---|
| Catalogue Zone 1 — 13 items §4 (valeurs contraignantes, taux nuit) dans `shared/Config` | ✅ |
| `EconomyService` — portefeuille autoritaire, leaderstats display-only, audit anomalies §11.4 | ✅ |
| `HypeService` v1 — somme des bonus équipements, clamp 0-100, attribut répliqué | ✅ |
| `BuildService` — buy/upgrade/repair/collect (intents typés §10.3), campfire offert, bounds check | ✅ |
| Revenus — boucle d'accrual serveur (taux effectif ×(1+Hype/100)), offline 20 %/cap 8 h (§2.4) | ✅ |
| `UIController` client — HUD, boutique, panneau festival, collecte, toasts | ✅ |
| Tests TestEZ — matrice catalogue §4, formules EconomyMath, bounds/taux BuildService | ✅ |

**DoD S1 :** boucle achat→revenu→réinvestissement jouable. Amendement Blueprint §3.2 : solde de départ 750 Shells (hook D0 : campfire offert + 3 achats tier 1 immédiats). La validation « vivre une nuit complète » du hook D0 requiert le cycle jour/nuit (Sprint 2).

### Sprint 2 (Monde vivant) ✅

| Tâche | Statut |
|---|---|
| `EventService` — cycle jour/nuit §2.2 (16 min = 10 j / 6 n), phase répliquée (attributs Workspace), horloge par serveur | ✅ |
| Revenus nuit ×2 §2.2 — `BuildService` module l'accrual par le multiplicateur de phase (jour ×0.5 du taux nuit → nuit ×2) | ✅ |
| `NPCService` — foule de fêtards (arrivée→équipement→départ), densité §3.3 `×(1+Hype/50)` × phase, cap 40/plot §10.6, 1 seul Heartbeat, LOD > 50 studs | ✅ |
| `HypeService` v2 — modificateur propreté/decay §3.3 (+5 cleanup, −5/cycle si sale ou cassé), clamp 0-100 | ✅ |
| Beach Cleanup Flash §7 — 10 déchets après chaque nuit, 60 s, +5 Hype (ProximityPrompt, validé serveur) | ✅ |
| `AmbienceController` client §9 — lighting jour/nuit (tween), crossfade audio piloté Hype, HUD phase + bannière cleanup | ✅ |
| Tests TestEZ — cycle/phase/multiplicateur, Hype modifier, cleanup, cible de foule NPC (`tests/World.spec.luau`) | ✅ |

**DoD S2 :** « La plage vit, revenus nuit ×2 fonctionnels ». Décisions d'implémentation (dans le cadre de §10.2, sans changer de valeur contraignante) :
- Le cycle jour/nuit vit dans **`EventService`** — le service « monde vivant » de §7 (le Beach Cleanup y est un event §7). La météo / singes / VIP (§7) s'y ajoutent au Sprint 4.
- Les **NPC visualisent** le débit piloté par le Hype ; le revenu autoritatif reste l'accrual taux/min §4 de `BuildService` (économie serveur-autoritaire §10.3) — foule et revenu sont deux vues du même signal Hype, sans laisser le spawn NPC piloter (ni exploiter) l'économie.
- Le modificateur de propreté/decay du Hype est **runtime (non persisté)** — aucun bump de schéma `dataVersion`.
- Les `SoundId` d'ambiance sont laissés vides : boucles libres de droits assignées dans Studio via l'AssetRegistry (§9/§10.1 — jamais de musique commerciale réelle).

### Sprint 3 (Full Moon) ✅

| Tâche | Statut |
|---|---|
| `FullMoonService` — horloge UTC globale §10.5 (`os.time() % 7200 < 600`), event 10 min toutes les 2 h, synchro sans MessagingService | ✅ |
| Multiplicateurs §2.3 — revenus ×5 (gate) / ×2 (réduit) empilés sur jour/nuit dans `BuildService` ; spawn NPC ×3 (cap 40 §10.6) | ✅ |
| Gate d'accès §2.3 — Hype ≥ 80 % + tout réparé + staff/zone (prédicat enfichable, stub jusqu'à S4) | ✅ |
| **Moon Shards** §3.1 — monnaie dure earn-only, wallet `EconomyService` (`CreditMoonShards`, leaderstat), récompense fin d'event (5 éligible / 2 sinon) + `SaveNow` | ✅ |
| VFX / sky transform §9 — `AmbienceController` : lighting Full Moon + Bloom, bannière hero + compte à rebours, attributs Workspace répliqués | ✅ |
| Audit §11.4 — plafond élargi de l'enveloppe Full Moon ×5 (pas de faux positif sur les top festivals) | ✅ |
| Tests TestEZ — horloge UTC déterministe (preuve de synchro cross-serveur), multiplicateur/récompense, spawn ×3 (`tests/FullMoon.spec.luau`) | ✅ |

**DoD S3 :** « Event synchronisé vérifié sur 2 serveurs simultanés ». La synchro découle du fait que l'état est une **fonction pure de l'epoch UTC** (`os.time() % 7200`) : deux serveurs évaluant à la même seconde UTC obtiennent le même état, sans messagerie cross-serveur (§10.5) — c'est ce que prouvent de façon déterministe les helpers testés (`_isActiveAt` / `_secondsRemainingAt`). MessagingService (annonces + leaderboards cross-serveur) reste en v1.1 (§10.5).

**Amendements Blueprint §2.3 (17/07/2026) :** (1) récompense contraignante par Full Moon = **5 Moon Shards** si éligible au ×5, **2** sinon (le montant était non spécifié) ; (2) la sous-condition « 1 staff actif par zone » est **satisfaite par défaut** (prédicat enfichable) jusqu'à `StaffService` (Sprint 4) — les deux autres conditions du gate sont pleinement évaluées dès S3.

### Sprint 4 (Profondeur) ✅

| Tâche | Statut |
|---|---|
| `StaffService` §5 — recrutement 2 bannières (500 🐚 C/R, 5 🌕 Epic-min), **odds affichés en jeu** (§5.1/§11.2), assignation par zone, **fusion 3→1** (sink de doublons) | ✅ |
| Effets staff §5.2 — multiplicateur de revenu (poussé vers `BuildService`) + Hype (poussé vers `HypeService`), sans cycle de dépendances | ✅ |
| Repair/casse §4 — casse ambiante par cycle + tempête ; réparation via `RequestRepair` (S1) ; revenu 0 + malus Hype non réparé | ✅ |
| `EventService` §7 — **tempête** (alerte 60 s, 1-3 dégâts, −50 % 90 s), **singes** (vol du pool non collecté), **bateau VIP** (×1.5 revenus si Hype ≥ 50) | ✅ |
| **Zone 2 — Ban Tai** §4 — 13 items (tiers 3-6, 20k→400k), déblocage 75k 🐚 + Hype 60 ; schéma **v2 + migration** `unlockedZones` | ✅ |
| Full Moon gate §2.3 — prédicat « 1 staff/zone » **réellement câblé** (injection dans `FullMoonService`) | ✅ |
| Client — panneau recrutement (odds), collection staff (assign/fusion), boutique zone-aware + bouton de déblocage, Moon Shards au HUD | ✅ |
| Tests TestEZ — odds de bannière (somme = 1), roll de rareté, effets/fusion staff, gate zone 2, migration v2, catalogue zone 2 (`tests/Staff.spec.luau`) | ✅ |

**DoD S4 :** « Session 45 min sans friction, sinks fonctionnels ». Les sinks : rolls (Shells/Moon Shards) et fusion 3→1 des doublons ; la progression Zone 2 repousse le mur ; tempêtes/singes/casse créent la gestion de friction.

**Décisions & amendements S4 (17/07/2026) :**
- **Catalogue Zone 2** (§4) : le Blueprint nomme 7 des 13 items sans chiffres ; les 6 noms ajoutés + tous les nombres suivent la croissance §3.2 (contraignant, documenté dans `Config/Equipment.luau`).
- **Odds par bannière** (§5.1) : §5 donne la table globale (60/30/9/1) et 2 bannières mais pas le split par bannière → défini (Standard 75/25, Premium 90/10 Epic-min) et **affiché en jeu**.
- **`StaffRarity` = `string`** (pas union de singletons) : Luau élargit les littéraux singletons à `string` dans les tables `table.freeze` de config ; la validité est vérifiée au runtime contre `Config/Staff`.
- **Effet Legendary « +1 min Full Moon »** (§5.2) : **différé** (interagit avec l'horloge globale synchronisée §10.5) ; les effets Legendary revenu global + Hype sont livrés.
- **Approximation zone/global** : « revenu de zone » vs « global » collapse sur le taux mono-plot actuel (documenté ; à raffiner avec le split de taux par zone).

### Sprint 5 (Social & monétisation) ✅

| Tâche | Statut |
|---|---|
| `MonetizationService` §8 — **`ProcessReceipt` idempotent** (§8.4.3/§10.5 : claim du PurchaseId avant grant, `SaveNow`, retour `PurchaseGranted` sur retry sans double-grant), Game Passes (`UserOwnsGamePassAsync` + `PromptGamePassPurchaseFinished`) | ✅ |
| Effets §8.1/§8.2 — Auto-Collect (banque auto), VIP +25 % (mult. externe), Golden Boat +10 % NPC, packs de Shells, Hype Boost +20/30 min, Instant Repair All | ✅ |
| `SocialService` §6 — **visites inter-plots** (téléport), Festival Rating 1-5★ (1 vote/hôte/jour), quête quotidienne « Visit 3 », bonus ami +5 % | ✅ |
| Schéma **v3 + migration** — `purchaseHistory` (ledger idempotence), `festivalRating`, `social` (état quotidien) | ✅ |
| `BuildService` — multiplicateurs externes génériques (staff/ami/VIP), auto-collect, `RepairAll` | ✅ |
| Client — panneaux 💎 Store (prompts pass/produits) et 🌐 Festivals (visiter, noter, rentrer), Moon Shards au HUD | ✅ |
| Tests TestEZ — idempotence `ProcessReceipt`, intégrité catalogue §8, rating/quête/1-vote-jour, migration v3 (`tests/Monetization.spec.luau`, `tests/Social.spec.luau`) | ✅ |

**DoD S5 :** « Transaction Robux test validée, visite inter-plots validée ». La transaction Robux passe par `ProcessReceipt` idempotent, dont le cœur (`_claimPurchase`) est prouvé par test (pas de double-grant sur re-livraison). La visite inter-plots téléporte le visiteur vers la parcelle d'un autre joueur et enregistre la visite (quête quotidienne).

**Décisions & amendements S5 (17/07/2026) :**
- **IDs d'assets = `0` placeholders** : `gamePassId`/`productId` renseignés dans Studio (§10.1) ; `ProcessReceipt` clef par ces IDs → rien n'est accordé avant. Le pipeline est complet et testé.
- **Montants des packs de Shells** (non spécifiés §8.2) : 99→5k, 249→15k, 599→42k, 1 299→100k (`Config/Monetization.luau`).
- **`Config/Monetization.luau`** : nouveau fichier config (principe config-driven §10.3.3, hors liste illustrative §10.2).
- **Différés** : Extra Plot Slot (§8.1 — persistance multi-plot) et bonus « +10 % Shells sur achats en visite » (§6 — modèle de dépense inter-plot) ; la visite livre téléport + quête + rating + bonus ami.

### Sprint 6 (Polish & launch) ✅

| Tâche | Statut |
|---|---|
| **Zone 3 — Bottle Beach** §4 — 8 items (tiers 6-8, 300k→5M), déblocage 500k 🐚 + Hype 75 + (1 prestige **OU** 50 🌕) | ✅ |
| **Prestige "Season Reset"** §2.3 — au niveau max (Zone 3), reset festival → +10 %/prestige permanent (cap ×2.5) ; garde staff/🌕/pass/rating | ✅ |
| **Leaderboard** §6 — hub trié par note (top festivals en tête, rang affiché) | ✅ |
| **Onboarding** — panneau de bienvenue première session (boucle cœur en 4 étapes) | ✅ |
| Catalogue complet **34 items** (§4 — 13 + 13 + 8) ; multiplicateur prestige appliqué au join (mult. externe) | ✅ |
| Tests TestEZ — courbe prestige (+10 %/cap ×2.5), catalogue Zone 3, gate de déblocage (`tests/Prestige.spec.luau`) | ✅ |

**DoD S6 :** « Soft launch privé → itération metrics → launch public ». Le build de contenu est complet (3 zones, prestige, leaderboard, onboarding). Restent **hors-code** (Studio/marketing) : icônes + thumbnails + page produit, et le processus de soft-launch/itération metrics (KPIs §12).

**Amendement Blueprint §4 (17/07/2026) :** catalogue Zone 3 complet (3 noms ajoutés + chiffres par item, croissance §3.2).

---

## Roadmap §12 — état

| Sprint | Statut |
|---|---|
| S0 Fondations · S1 Boucle cœur · S2 Monde vivant · S3 Full Moon · S4 Profondeur · S5 Social & monétisation · S6 Polish & launch | ✅ livrés |

Restes hors-code pour le launch : IDs d'assets Robux (Game Passes / Dev Products) + audio libres de droits + modèles 3D à câbler dans Studio (§10.1), icônes/thumbnails/page produit, et cross-server v1.1 (MessagingService : annonces + leaderboards globaux, §10.5).

## Setup

```sh
# 1. Toolchain (une fois) — https://github.com/rojo-rbx/rokit
rokit install

# 2. Dépendances (TestEZ)
wally install

# 3. Sync vers Roblox Studio (plugin Rojo requis dans Studio)
rojo serve
```

Dans Studio : ouvrir un place vide → plugin Rojo → **Connect**. Studio ne sert qu'au placement 3D et à la publication (§10.1) ; tout le code vit ici.

## Lancer les tests

1. `wally install` puis `rojo serve` (le dossier `Packages/` doit être synchronisé).
2. Dans Studio, sélectionner **Workspace** → Attributes → ajouter un attribut booléen `FMF_RunTests` = `true`.
3. Play (F5) ou Run (F8) → résultats TestEZ dans l'Output.

Les specs (`tests/*.spec.luau`) sont `--!nonstrict` car TestEZ injecte `describe`/`it`/`expect` à l'exécution ; tout le code de production sous `src/` est `--!strict`.

## CI

`.github/workflows/ci.yml` : analyse statique Luau strict (`luau-lsp analyze` avec les définitions Roblox + sourcemap Rojo) et `stylua --check`. L'exécution TestEZ headless nécessite Roblox Studio (`run-in-roblox`) — non disponible sur les runners GitHub ; les specs se lancent dans Studio (voir ci-dessus).

## Notes d'implémentation

- **ProfileStore** (MadStudio) est vendoré dans `src/server/Packages/ProfileStore.luau`. Il gère nativement le mock mode en Studio sans accès API.
- Les CFrames d'équipements sont sérialisés en 12 composantes numériques, **relatives à l'origine du plot** (les DataStores ne stockent pas les CFrames).
- `DataService.SaveNow()` est le hook « save post-transaction Robux » (§10.4) que `MonetizationService` consommera au Sprint 5.
- Remote GitHub : [`Tamanada/ROBLOX-FMF`](https://github.com/Tamanada/ROBLOX-FMF) (§10.1).
