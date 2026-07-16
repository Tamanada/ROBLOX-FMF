# FULL MOON FESTIVAL — BLUEPRINT & GAME DESIGN DOCUMENT v1.0

> **Statut : document contraignant (binding).** Toute implémentation dans Roblox Studio / Claude Code doit se conformer à ce document. Toute déviation exige une mise à jour préalable du Blueprint.
> **Plateforme :** Roblox (PC, mobile, tablette, console)
> **Genre :** Tycoon / Simulation sociale
> **Langue du jeu :** Anglais (marché global), architecture i18n prête pour FR/TH
> **Auteur :** Alan August — Koh Phangan, Thaïlande
> **Version :** 1.0 — Juillet 2026

---

## §1 — VISION & PILIERS

### 1.1 Pitch
Tu débarques sur une plage vide de Koh Phangan avec un feu de camp et un stand de smoothies. Construis, gère et fais grandir le plus grand festival de pleine lune de l'île. Chaque nuit, la fête monte. Toutes les deux heures, la **Full Moon** transforme l'île entière — si ton festival est prêt.

### 1.2 Piliers de design (non négociables)
1. **La fête se construit** — chaque équipement posé change visiblement l'ambiance (lumière, son, foule). Le joueur doit *voir* et *entendre* sa progression.
2. **Le rendez-vous Full Moon** — événement global synchronisé en temps réel sur tous les serveurs. L'attente crée la rétention (mécanique halving NAVA PEACE appliquée au gameplay).
3. **L'hospitalité comme gameplay** — le Hype (satisfaction des fêtards) est la ressource maîtresse. Le revenu est une conséquence de l'expérience, jamais l'inverse.
4. **Social = croissance** — visiter le festival d'un autre joueur profite aux deux. Chaque joueur est un ambassadeur (boucle Staylo).
5. **Family-friendly strict** — zéro alcool, drogue, gambling, contenu suggestif. Smoothies, fruit buckets, lanternes, feu, néon, musique. Conformité Roblox Community Standards = condition d'existence du jeu.

### 1.3 Références de marché
- Boucle tycoon moderne : progression par zones + prestige (pas de simple conveyor tycoon).
- Ambiance sociale : hangouts plage/festival à fort succès sur la plateforme.
- Collection : recrutement de staff à rareté (soft gacha, sans loot boxes payantes directes — conformité réglementaire).

---

## §2 — BOUCLE DE GAMEPLAY

### 2.1 Boucle courte (minute)
1. Les fêtards (NPC) débarquent par bateau-taxi → fréquentation proportionnelle au **Hype**.
2. Ils consomment aux équipements (smoothie bar, UV paint, photo spot…) → génèrent des **Shells** (monnaie soft).
3. Le joueur collecte (manuel, ou auto-collect via Game Pass).
4. Le joueur réinvestit : nouvel équipement, upgrade, staff.

### 2.2 Boucle moyenne (session ~20 min)
- **Cycle jour/nuit : 16 minutes** (10 min jour / 6 min nuit).
- **Jour :** construction, réparations, nettoyage de plage (mini-tâche : ramasser les déchets post-fête → bonus Hype), préparation.
- **Nuit :** revenus ×2, foule dense, ambiance maximale, mini-events aléatoires.

### 2.3 Boucle longue (rétention)
- **FULL MOON EVENT : toutes les 2 heures temps réel, synchronisé sur tous les serveurs** (00:00, 02:00, 04:00 UTC…). Durée : 10 minutes.
  - Multiplicateur revenus ×5, spawn de fêtards ×3, ciel transformé (lune géante, océan phosphorescent).
  - **Condition d'accès au multiplicateur max :** Hype ≥ 80 % + tous les équipements réparés + au moins 1 staff actif par zone débloquée. Sinon multiplicateur réduit (×2).
  - Récompense exclusive : **Moon Shards** (monnaie dure soft-earnable), utilisée pour le staff Legendary et les cosmétiques d'île.
- **Prestige ("Season Reset") :** au niveau max d'une plage, le joueur peut "immortaliser" son festival (statue + badge + multiplicateur permanent +10 % par prestige, cap ×2.5) et recommencer avec bonus.

### 2.4 Anti-idle / AFK
- Revenus offline : 20 % du taux actif, cap 8 heures (encourage le retour 2-3×/jour).
- Auto-collect Game Pass : collecte automatique en jeu, ne change pas le taux offline.

---

## §3 — ÉCONOMIE (CHIFFRÉE, CONTRAIGNANTE)

### 3.1 Monnaies
| Monnaie | Source | Usage | Achetable Robux ? |
|---|---|---|---|
| **Shells** 🐚 | Équipements, quêtes, visites sociales | Équipements, upgrades, staff C/R | Oui (Dev Products) |
| **Moon Shards** 🌕 | Full Moon Events, achievements, prestige | Staff Epic/Legendary, cosmétiques d'île, skins | Non (earn-only) — crédibilité long terme |

**Règle contraignante :** Moon Shards jamais vendus contre Robux. C'est la monnaie de statut. La vendre tuerait la boucle Full Moon.

### 3.2 Courbe économique cible
- Payback d'un équipement tier 1 : **2-3 min de jeu actif**.
- Payback tier 5 : **45-60 min**.
- Croissance des coûts : ×1.9 par tier ; croissance des revenus : ×1.6 par tier (écart volontaire → le joueur "sent" le mur → motivation staff/upgrades/Game Pass).
- Première session (D0) : le joueur doit poser **au moins 4 équipements** et vivre **une nuit complète** en < 15 minutes. C'est le hook.

### 3.3 Le Hype (ressource maîtresse)
- Score 0-100 par festival. Calcul serveur : `Hype = f(diversité des équipements, propreté, staff actifs, décor, uptime musique)`.
- Effets : taux de spawn NPC (`spawnRate = base × (1 + Hype/50)`), dépense moyenne par NPC (`spend = base × (1 + Hype/100)`), éligibilité multiplicateur Full Moon.
- Décroissance : −5 pts/cycle si plage sale ou équipement cassé non réparé. Le Hype se **gère**, il ne s'accumule pas passivement.

---

## §4 — ÉQUIPEMENTS (CATALOGUE v1 — 34 ITEMS)

Format : Nom | Tier | Coût (Shells) | Revenu/min (nuit) | Hype | Zone min.

### Zone 1 — Haad Rin (départ)
| Équipement | Tier | Coût | Rev/min | Hype |
|---|---|---|---|---|
| Campfire (offert) | 0 | 0 | 2 | +1 |
| Smoothie Stand | 1 | 100 | 8 | +2 |
| Fruit Bucket Bar | 1 | 250 | 14 | +2 |
| Beach Mat Lounge | 1 | 400 | 10 | +3 |
| Bluetooth Speaker Tower | 2 | 900 | 22 | +5 |
| UV Paint Station | 2 | 1 500 | 30 | +6 |
| Photo Spot "Moon Swing" | 2 | 2 200 | 26 | +7 |
| Juggling Circle | 3 | 4 000 | 45 | +8 |
| Fire Limbo | 3 | 6 500 | 60 | +9 |
| Small DJ Booth | 3 | 10 000 | 85 | +12 |
| Lantern Release Deck | 4 | 18 000 | 110 | +14 |
| Neon Dance Floor | 4 | 30 000 | 160 | +16 |
| Main Stage Mk I | 5 | 55 000 | 260 | +22 |

### Zone 2 — Ban Tai (déblocage : 75 000 Shells + Hype 60)
Pier & Boat Taxi Upgrade, Coconut Café, Glow Body Art Studio, Trampoline Net, Silent Disco Dome, Drone Light Show Pad, Main Stage Mk II… (13 items, tiers 3-6, coûts 20k → 400k)

### Zone 3 — Bottle Beach (déblocage : 500 000 Shells + Hype 75 + 1 prestige OU 50 Moon Shards)
Infinity Fire Show Arena, Bioluminescent Lagoon, Treehouse VIP Deck, Full Moon Amphitheater, Sky Lantern Festival Grounds… (8 items, tiers 6-8, coûts 300k → 5M)

**Règle contraignante :** chaque équipement a 3 niveaux d'upgrade (revenu ×1.5/niveau, coût = 60 % du prix d'achat/niveau) et un état **Repair** (casse aléatoire pondérée par les events météo, coût réparation = 10 % du prix, non réparé = revenu 0 + malus Hype).

---

## §5 — STAFF (COLLECTION)

### 5.1 Recrutement
- **Recruitment Board** sur la jetée. Roll : 500 Shells (Common/Rare) ou 5 Moon Shards (Epic garanti min.).
- **Conformité :** les probabilités de drop sont **affichées en jeu** (transparence type gacha réglementé). Aucun roll direct en Robux.

### 5.2 Raretés & rôles
| Rareté | Drop | Exemple | Effet type |
|---|---|---|---|
| Common (60 %) | Bartender, Cleaner | +5 % revenu d'un équipement / auto-clean lent |
| Rare (30 %) | Fire Juggler, Percussionniste | +10 % revenu de zone, +3 Hype |
| Epic (9 %) | Resident DJ, Fire Show Master | +20 % revenu de zone, +8 Hype, aura visuelle |
| Legendary (1 %) | **The Moon Shaman**, **Island Legend** | +15 % revenu global, +15 Hype, effet Full Moon (+1 min de durée d'event pour le serveur) |

- Staff assignable par zone. Fusion : 3 doublons → 1 rareté supérieure (sink de doublons).
- Les Legendary ont un lore lié à l'île (clin d'œil aux vraies légendes de Phangan, sans personnes réelles).

---

## §6 — SOCIAL & MULTIJOUEUR

- **Serveurs 12 joueurs**, chacun sa parcelle (plot system classique, téléport entre plots).
- **Visite :** dépenser chez un autre joueur → le visiteur gagne +10 % Shells sur ses achats là-bas, l'hôte encaisse 100 %. Quête quotidienne "Visit 3 festivals".
- **Festival Rating :** les visiteurs peuvent noter (1-5 étoiles, 1 vote/joueur/jour). Top festivals affichés dans le hub → statut social = moteur de rétention.
- **Co-op Full Moon :** pendant l'event, un leaderboard de serveur (revenus cumulés) donne un bonus collectif si le serveur atteint un objectif commun → coopération spontanée.
- **Groupes/amis :** bonus +5 % revenus si un ami est sur le serveur (viralité organique).

---

## §7 — ÉVÉNEMENTS & MONDE VIVANT

| Event | Fréquence | Effet |
|---|---|---|
| Tempête tropicale | ~1/45 min, annoncée 60 s avant | 1-3 équipements endommagés, revenus −50 % pendant 90 s. Contre : Storm Shelter (équipement défensif) |
| Singes voleurs | ~1/20 min | Volent des Shells non collectés → urgence de collecte, mini-chasse amusante |
| Bateau VIP | ~1/30 min si Hype ≥ 50 | 5 NPC "VIP" dépensent ×10 |
| Beach Cleanup Flash | Après chaque nuit | Ramasser 10 déchets en 60 s → +5 Hype |
| **FULL MOON** | Toutes les 2 h temps réel | Voir §2.3 |
| Events saisonniers | Calendrier live-ops | Songkran (avril, water fight), Loy Krathong (novembre, lanternes flottantes), New Year Countdown |

---

## §8 — MONÉTISATION

### 8.1 Game Passes (achat unique)
| Pass | Prix (Robux) | Effet |
|---|---|---|
| Auto-Collect | 249 | Collecte automatique |
| VIP Islander | 399 | +25 % Shells, chat tag, spawn VIP, zone lounge du hub |
| Pyro Master | 299 | Effets pyrotechniques exclusifs sur les stages |
| Golden Longtail Boat | 199 | Bateau-taxi doré (pur flex) + arrivées NPC +10 % |
| Extra Plot Slot | 349 | 2e sauvegarde de festival |

### 8.2 Developer Products (répétables)
- Packs de Shells (4 paliers : 99 / 249 / 599 / 1 299 Robux) — **prix indexés sur ~15-20 min de farming équivalent, jamais plus** (pay-to-accelerate, pas pay-to-win).
- Hype Boost +20 pendant 30 min (49 Robux).
- Instant Repair All (25 Robux).

### 8.3 Cosmétiques
- Skins d'équipements (stages, dance floors), thèmes d'île (Neon Jungle, Zen Sunset, Cyber Moon), traînées d'avatar UV.
- Payables en Moon Shards (earn) **ou** Robux (skip) — double voie systématique.

### 8.4 Règles contraignantes
1. Aucun contenu gameplay-critique exclusif aux Robux.
2. Aucune loot box payante directe.
3. Tout Dev Product passe par **ProcessReceipt avec idempotence** (voir §10) — même rigueur que ton infra Stripe/NOWPayments.

---

## §9 — DIRECTION ARTISTIQUE & AUDIO

- **Palette :** nuit tropicale — bleu profond #0B1D3A, sable lunaire #E8DCC0, néons cyan #00E5FF / magenta #FF2E92 / lime #B4FF39, or lunaire #FFD166. (Cohérent avec l'ADN Mission Control de MOON-RZ : navy + gold, déclinaison festival.)
- **Style :** low-poly stylisé + éclairage Future (neon emissive, god rays lunaires, océan phosphorescent la nuit de Full Moon). Le low-poly garantit les perfs mobile (≥ 60 % du trafic Roblox).
- **Audio :** boucles libres de droits par zone (chill jour / house-tribal nuit), montée d'intensité pilotée par le Hype. **Jamais de musique commerciale réelle** (copyright + modération).
- **Landmarks :** lune géante à l'horizon (scale dynamique pendant l'event), longtail boats, falaises de Haad Rin stylisées. Évocation, pas reproduction : aucun nom de commerce réel de l'île.

---

## §10 — ARCHITECTURE TECHNIQUE (CONTRAIGNANTE)

### 10.1 Stack & workflow
- **Luau strict mode** (`--!strict`) partout.
- **Rojo 7** + repo GitHub (`github.com/Tamanada/ROBLOX-FMF`) → développement dans Claude Code, sync vers Studio. Studio = placement 3D et publication uniquement.
- Gestion des assets 3D : Toolbox filtré + assets custom ; IDs centralisés dans un module `AssetRegistry`.

### 10.2 Structure du repo

```
full-moon-festival/
├── default.project.json          # Rojo mapping
├── docs/BLUEPRINT.md             # ce document
├── src/
│   ├── server/                   # ServerScriptService
│   │   ├── Services/
│   │   │   ├── EconomyService.luau      # Shells/Shards, transactions atomiques
│   │   │   ├── HypeService.luau         # calcul Hype, decay, éligibilité FM
│   │   │   ├── PlotService.luau         # attribution/chargement des parcelles
│   │   │   ├── BuildService.luau        # achat/placement/upgrade/repair
│   │   │   ├── NPCService.luau          # spawn, pathfinding, dépenses
│   │   │   ├── StaffService.luau        # rolls, assignation, fusion
│   │   │   ├── EventService.luau        # météo, singes, VIP, saisonnier
│   │   │   ├── FullMoonService.luau     # horloge UTC globale, multiplicateurs
│   │   │   ├── SocialService.luau       # visites, ratings, bonus amis
│   │   │   ├── DataService.luau         # ProfileStore, migrations
│   │   │   └── MonetizationService.luau # ProcessReceipt idempotent, passes
│   │   └── init.server.luau
│   ├── client/                   # StarterPlayerScripts
│   │   ├── Controllers/  (UI, Camera, Ambience, Placement, SFX)
│   │   └── init.client.luau
│   └── shared/                   # ReplicatedStorage
│       ├── Config/   (Equipment.luau, Staff.luau, Economy.luau, Events.luau)
│       ├── Types.luau
│       └── Util/     (Signal, Net wrapper, Formatter)
└── tests/                        # TestEZ
```

### 10.3 Règles serveur-autoritaire (non négociables — cf. skill telegram-miniapp : never trust the client)
1. **Tout calcul économique côté serveur.** Le client n'envoie que des intentions (`RequestBuy(equipmentId, cframe)`).
2. **Validation systématique des RemoteEvents :** type-check des arguments, ownership du plot, solde suffisant, position dans les bounds du plot, rate limiting (max 10 requêtes/s/joueur, kick au-delà).
3. **Aucun prix/revenu répliqué modifiable** : configs en ReplicatedStorage en lecture, mais valeurs de référence recalculées serveur.
4. Collecte : le serveur détient les montants ; le client n'affiche que ce que le serveur réplique.

### 10.4 Persistance
- **ProfileStore** (successeur de ProfileService) : session-locking → zéro duplication d'items.
- Schéma versionné `dataVersion` + fonctions de migration (même discipline que tes migrations Prisma FreshOS).
- Autosave : 60 s + save on leave + save post-transaction Robux.
- Schéma joueur v1 :

```luau
type PlayerData = {
  dataVersion: number,
  shells: number,
  moonShards: number,
  hype: number,
  prestigeCount: number,
  plots: { [string]: PlotData },     -- équipements posés {id, level, cframe, broken}
  staff: { StaffEntry },              -- {staffId, rarity, assignedZone}
  stats: { totalEarned: number, fullMoonsAttended: number, visits: number },
  passes: { [string]: boolean },
  lastSeen: number,                   -- pour revenus offline
}
```

### 10.5 Full Moon global
- Horloge dérivée de `os.time()` UTC, modulo 7200 s → tous les serveurs convergent sans MessagingService (fallback simple). MessagingService en v1.1 pour annonces cross-server et leaderboards globaux (via MemoryStore + OrderedDataStore).

### 10.6 Performance (budget contraignant)
- Cible : 60 FPS PC / 30 FPS mobile bas de gamme.
- NPC : max 40 actifs par plot, pathfinding simplifié par waypoints (pas de PathfindingService par NPC à chaque tick), LOD d'animation au-delà de 50 studs.
- Streaming Enabled ON, parts anchored, unions minimales, textures atlas.

---

## §11 — CONFORMITÉ & SÉCURITÉ

1. **Roblox Community Standards :** zéro alcool/drogue/gambling/suggestif. Les "buckets" sont des **fruit buckets**. Revue de conformité à chaque ajout de contenu (checklist en CI de contenu).
2. **Loot/gacha :** probabilités affichées, pas de roll direct Robux.
3. **Chat & UGC :** aucun input texte libre affiché aux autres (les noms de festivals passent par TextService:FilterStringAsync).
4. **Exploits économiques :** logs serveur des transactions anormales (delta Shells > seuil/min → flag), audit avant tout patch économie.
5. **Aucune donnée personnelle collectée** hors APIs Roblox.

---

## §12 — ROADMAP D'IMPLÉMENTATION

| Sprint | Contenu | Definition of Done |
|---|---|---|
| **S0 — Fondations** | Repo + Rojo + structure §10.2, DataService/ProfileStore, PlotService, Net wrapper validé, CI TestEZ | Un joueur spawn, reçoit un plot, data persiste entre sessions |
| **S1 — Boucle cœur** | EconomyService, BuildService, 13 équipements Zone 1, collecte, HypeService v1 | Boucle achat→revenu→réinvestissement jouable, hook D0 < 15 min validé |
| **S2 — Monde vivant** | NPCService, cycle jour/nuit, ambiance audio/lighting, cleanup | La plage "vit", revenus nuit ×2 fonctionnels |
| **S3 — Full Moon** | FullMoonService, horloge UTC, multiplicateurs, Moon Shards, VFX event | Event synchronisé vérifié sur 2 serveurs simultanés |
| **S4 — Profondeur** | StaffService, Repair/casse, EventService (tempête, singes, VIP), Zone 2 | Session 45 min sans friction, sinks fonctionnels |
| **S5 — Social & monétisation** | SocialService (visites, ratings), Game Passes, Dev Products idempotents, hub | Transaction Robux test validée, visite inter-plots validée |
| **S6 — Polish & launch** | Zone 3, prestige, leaderboards, onboarding/tutorial, icônes+thumbnails, page produit | Soft launch privé → itération metrics → launch public |

**KPIs de pilotage post-launch :** D1 retention ≥ 25 %, session moyenne ≥ 18 min, % joueurs présents à ≥ 1 Full Moon ≥ 40 %, ARPDAU, ratio earn/buy Moon Shards.

---

## §13 — KICKOFF PROMPT (à coller tel quel dans Claude Code)

```
Tu démarres le Sprint 0 du projet FULL MOON FESTIVAL, un tycoon Roblox.

Lis d'abord /docs/BLUEPRINT.md en entier. C'est un document CONTRAIGNANT :
architecture §10, règles serveur-autoritaire §10.3, schéma de données §10.4,
économie §3-§4. Aucune déviation sans mise à jour préalable du Blueprint.

Tâches Sprint 0, dans l'ordre :
1. Initialise le repo avec la structure exacte de §10.2 et default.project.json
   (Rojo 7), Luau strict mode partout.
2. Implémente shared/Util/Net.luau : wrapper RemoteEvent/RemoteFunction avec
   validation de types des arguments et rate limiting (10 req/s/joueur).
3. Implémente DataService avec ProfileStore : schéma PlayerData v1 (§10.4),
   session-locking, autosave 60s, save on leave, fonction de migration stub.
4. Implémente PlotService : 12 plots par serveur, attribution au join,
   libération au leave, chargement des équipements sauvegardés.
5. Écris les tests TestEZ pour Net (validation/rejet) et DataService
   (défauts, migration).

Definition of Done : un joueur rejoint, reçoit un plot, ses données
persistent entre deux sessions. Ne commence AUCUNE feature de gameplay
(économie, NPC, Full Moon) dans ce sprint.
```

---

*FULL MOON FESTIVAL — Blueprint v1.0 — La lune se lève sur Haad Rin.* 🌕
