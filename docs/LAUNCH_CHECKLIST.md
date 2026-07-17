# FULL MOON FESTIVAL — Checklist Soft Launch → Launch Public (S6)

> Livrable Sprint 6 (§12 — DoD : « Soft launch privé → itération metrics → launch
> public »). Ordre d'exécution contraignant. Chaque section bloque la suivante.

---

## A. Build & publication Studio

- [ ] `rojo build default.project.json -o FullMoonFestival.rbxlx` (ou sync live
  `rojo serve` + plugin) — Studio = placement 3D et publication uniquement (§10.1).
- [ ] Placement 3D : plots, hub, lune à l'horizon, longtail boats, falaises Haad Rin
  stylisées (§9 landmarks) — évocation, pas de reproduction.
- [ ] Vérifier `StreamingEnabled = true` sur le place publié (§10.6).
- [ ] Lancer les specs TestEZ dans Studio (runner `tests/`) — **0 échec requis**.
- [ ] File → Publish to Roblox → place **privé** (l'expérience reste non listée
  jusqu'à la section E).

## B. Game Settings (Creator Hub / Studio)

- [ ] Nom + description + genre + appareils : copier depuis `docs/STORE_PAGE.md` §1-2.
- [ ] Icône 512×512 + thumbnails 1920×1080 : upload selon briefs `STORE_PAGE.md` §3-4.
- [ ] Questionnaire Age Guidelines : répondre « aucun » partout (violence, sang,
  romance, gambling…) — attendu : Minimal/All ages (§11.1).
- [ ] **Enable Studio Access to API Services** : ON (requis ProfileStore/DataStores §10.4).
- [ ] Third-party sales / teleports : OFF (aucun besoin, surface d'attaque en moins).
- [ ] Private servers : OFF au soft launch (réévaluer post-launch).

## C. Monétisation — création des produits & câblage des IDs

Créer sur le Creator Hub (Associated Items), puis **coller chaque ID dans
`src/shared/Config/Monetization.luau`** (les `0` sont des placeholders volontaires :
rien n'est accordé tant que les vrais IDs ne sont pas en place).

**Game Passes (§8.1) :**

| id config | Nom affiché | Robux | Champ à remplir |
|---|---|---|---|
| `auto_collect` | Auto-Collect | 249 | `gamePassId` |
| `vip_islander` | VIP Islander | 399 | `gamePassId` |
| `pyro_master` | Pyro Master | 299 | `gamePassId` |
| `golden_boat` | Golden Longtail Boat | 199 | `gamePassId` |
| `extra_plot` | Extra Plot Slot | 349 | `gamePassId` |

**Developer Products (§8.2) :**

| id config | Nom affiché | Robux | Champ à remplir |
|---|---|---|---|
| `shells_small` | Handful of Shells | 99 | `productId` |
| `shells_medium` | Bag of Shells | 249 | `productId` |
| `shells_large` | Chest of Shells | 599 | `productId` |
| `shells_huge` | Hoard of Shells | 1299 | `productId` |
| `hype_boost` | Hype Boost (+20, 30m) | 49 | `productId` |
| `repair_all` | Instant Repair All | 25 | `productId` |

- [ ] 5 Game Passes créés, IDs collés, commit `chore(launch): wire real Game Pass ids`.
- [ ] 6 Dev Products créés, IDs collés, commit idem.
- [ ] **Transaction Robux test en jeu** (DoD S5 §12) : acheter `repair_all` (25 R$) sur
  un compte test → grant persisté, puis relancer le prompt → `PurchaseGranted` sans
  double-grant (idempotence §8.4/§10.5). Vérifier le log serveur.

## D. Passe de conformité finale (§11 — bloquant)

- [ ] Sweep contenu : zéro alcool/drogue/gambling/suggestif ; fruit buckets partout.
- [ ] Audio : uniquement boucles libres de droits (§9) — aucun ID audio non vérifié.
- [ ] Probabilités de recrutement staff affichées en jeu (§5.1/§11.2).
- [ ] Aucun texte libre joueur affiché sans `TextService:FilterStringAsync` (§11.3).
- [ ] Logs transactions anormales actifs (delta Shells > seuil/min → flag, §11.4).

## E. Soft launch privé (1-2 semaines)

- [ ] Passer l'expérience en accessible par lien/amis (non listée).
- [ ] Cohorte : 10-30 joueurs de confiance (amis + communauté), mix PC/mobile.
- [ ] Brancher le suivi des KPIs (§12) — dashboard Creator Hub Analytics :
  - D1 retention ≥ **25 %**
  - Session moyenne ≥ **18 min**
  - Joueurs présents à ≥ 1 Full Moon ≥ **40 %**
  - ARPDAU, ratio earn/buy Moon Shards
- [ ] Vérifier le hook D0 < 15 min (DoD S1) sur les sessions réelles.
- [ ] Collecter les frictions (onboarding, mobile UI, perfs 30 FPS bas de gamme §10.6).
- [ ] Itérer : chaque changement d'économie passe par un amendement Blueprint AVANT
  le patch (§3 contraignant, audit §11.4).

## F. Critères de passage en launch public

Tous requis :

- [ ] KPIs §12 atteints ou tendance claire sur la cohorte soft launch.
- [ ] 0 bug bloquant ouvert ; 0 anomalie de transaction non expliquée.
- [ ] Perfs validées : 60 FPS PC / 30 FPS mobile bas de gamme (§10.6).
- [ ] 2 serveurs simultanés vérifiés synchro Full Moon (DoD S3, re-check).
- [ ] Page produit finale (icône/thumbnails éventuellement itérées) uploadée.
- [ ] Basculer l'expérience en **Public** + annonce communauté.

## G. Post-launch immédiat (v1.1, rappels Blueprint)

- MessagingService pour annonces cross-server + leaderboards globaux
  (MemoryStore + OrderedDataStore) — §10.5.
- Effet `extra_plot` (2e slot de sauvegarde) — différé S5, pass déjà vendu ⚠️ :
  ne pas activer la vente du pass tant que l'effet n'est pas livré, OU l'étiqueter
  clairement « coming soon » en jeu. Décision à acter par amendement §8.1.
