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
