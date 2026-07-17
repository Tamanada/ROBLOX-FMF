# FULL MOON FESTIVAL — Prompts de génération des visuels store (S6)

> Compagnon de `STORE_PAGE.md` §3-4. 6 visuels : 1 icône + 5 thumbnails.
> Prompts EN prêts à coller (LINEAGE STUDIO ou autre générateur).
> Palette contraignante §9 : bleu profond `#0B1D3A`, sable lunaire `#E8DCC0`,
> cyan `#00E5FF`, magenta `#FF2E92`, lime `#B4FF39`, or lunaire `#FFD166`.
> Conformité §11 : zéro alcool/verre/bouteille/cigarette, foule habillée
> style Roblox family-friendly, aucun logo ou marque réelle.

**Negative prompt commun (à ajouter si l'outil le supporte) :**

```
alcohol, bottles, drinks in glasses, cigarettes, smoking, gambling, casino,
realistic humans, photorealism, real brand logos, text watermarks, gore,
game UI, HUD, buttons, menus, currency counters, level bars, price tags,
fake interface overlay
```

---

## 1/6 — Icône du jeu (512×512, carré 1:1)

```
Square game icon, stylized low-poly 3D render. A giant glowing golden full
moon (#FFD166) fills the upper frame against a deep navy night sky (#0B1D3A)
with stars. Below, the dark silhouette of a tropical beach party: palm trees,
a low-poly festival stage, string lanterns, thin neon trim lights in cyan
(#00E5FF) and magenta (#FF2E92) reflecting on wet sand. Bold readable title
"FULL MOON FESTIVAL" in warm golden letters at the bottom, clean rounded
game-logo typography. Vibrant, high contrast, emissive neon glow, Roblox
game icon style, readable at small size, centered composition.
```

*Variante sans texte (A/B post-soft-launch) : même prompt en retirant la
phrase sur le titre.*

## 2/6 — Thumbnail 1 « Hero — Full Moon » (1920×1080, 16:9)

```
Widescreen game key art, stylized low-poly 3D render, night scene. A massive
golden full moon (#FFD166) rises over a phosphorescent glowing turquoise
ocean. On the beach, a huge festival in full swing: dancing blocky
stylized characters (Roblox-like proportions), neon dance floor glowing cyan
(#00E5FF) and magenta (#FF2E92), fire show performers with spinning fire
trails, floating paper lanterns rising into the sky, volumetric god rays
from the moon. Deep navy sky (#0B1D3A), lunar sand (#E8DCC0). Epic, joyful,
high-energy atmosphere, cinematic wide angle, emissive lighting.
```

*Texte à ajouter en post-prod (plus fiable que généré) : « THE MOON RISES
EVERY 2 HOURS ».*

## 3/6 — Thumbnail 2 « Construction » (1920×1080, 16:9)

```
Widescreen game art, stylized low-poly 3D render, tycoon building gameplay.
A blocky stylized player character places a glowing neon smoothie bar on a
tropical beach plot at dusk; a translucent hologram placement grid glows
lime green (#B4FF39) under the building. Around it, an in-progress festival:
a small stage, fruit stands with colorful fruit buckets, string lights, palm
trees. Half the beach is still empty sand (#E8DCC0), showing room to grow.
Warm sunset transitioning to navy night sky (#0B1D3A), cyan (#00E5FF) and
magenta (#FF2E92) neon accents. Inviting, constructive, playful mood.
Pure cinematic key art scene with NO game interface: no HUD, no buttons,
no menus, no currency or level counters, no price tags, no on-screen text.
```

*⚠️ Leçon v1 : le générateur avait inventé une fausse UI (devise « MRZ »,
compteurs, boutons PLACE/ROTATE) — données mensongères vs le jeu réel
(Shells/Moon Shards) et texte UI trompeur pour la modération Roblox. D'où
l'interdiction explicite ci-dessus + negative prompt renforcé.*

## 4/6 — Thumbnail 3 « Collection staff » (1920×1080, 16:9)

```
Widescreen game art, stylized low-poly 3D render, character collection
lineup. Five blocky stylized festival staff characters posing side by side
on a beach stage at night, facing camera: a smoothie barista, a DJ with
headphones, a fire performer holding unlit staffs, a lantern keeper, and a
glowing legendary dancer at the center with a golden aura (#FFD166). Each
character stands on a colored rarity pedestal glowing from gray to green to
blue to purple to gold — glow color only, no rarity labels. All characters
fully clothed in family-friendly festival outfits (the dancer wears a full
costume, no swimwear). Deep navy sky (#0B1D3A) with a full moon, cyan
(#00E5FF) and magenta (#FF2E92) neon stage lights. Collectible showcase
composition, fun and charismatic. Pure key art scene with NO game
interface: no HUD, no counters, no name plates, no on-screen text.
```

*⚠️ Leçon v1 : compteur « STAFF COLLECTED 23/35 » inventé + étiquettes de
rareté/noms en UI + tenue de la danseuse trop légère (§11).*

## 5/6 — Thumbnail 4 « Social » (1920×1080, 16:9)

```
Widescreen game art, stylized low-poly 3D render, aerial three-quarter view
of two neighboring beach festival islands at night, connected by a glowing
turquoise sea. A colorful wooden longtail boat carries a blocky stylized
player from one island to the other, leaving a phosphorescent wake. Both
festivals glow with cyan (#00E5FF) and magenta (#FF2E92) neon, string
lanterns and dancing crowds. Friendly waving characters on both shores.
Giant golden full moon (#FFD166) above, deep navy sky (#0B1D3A). Warm,
social, welcoming multiplayer mood. Pure key art scene with NO game
interface: no HUD, no friends list, no chat panel, no buttons, and no
readable text anywhere (neon signs show symbols only).
```

*⚠️ Leçon v1 : widgets « FRIENDS ONLINE » et « GLOBAL CHAT » inventés
(fonctionnalité inexistante — MessagingService = post-launch §10.5) +
panneaux texte partout.*

## 6/6 — Thumbnail 5 « Prestige » (1920×1080, 16:9)

```
Widescreen game art, stylized low-poly 3D render, triumphant scene. A grand
golden statue (#FFD166) of a blocky stylized player character (Roblox-like
proportions, exactly two arms, two legs) in a joyful dance pose stands on a
stone pedestal at the heart of a maxed-out beach festival at night — a
celebration of the player, with NO religious or deity iconography of any
kind (no multiple arms, no headdress evoking a deity). Spotlights and
god rays converging on it. Around the statue: a massive celebrating crowd of
blocky stylized characters, confetti, rising paper lanterns, neon stages in
cyan (#00E5FF), magenta (#FF2E92) and lime (#B4FF39). A glowing badge emblem
shines above the statue. Deep navy sky (#0B1D3A), one single giant golden
full moon on the horizon. Epic legacy, achievement, celebration mood. Pure
key art scene with NO game interface and no text.
```

*⚠️ Leçon v1 : la statue générée avait plusieurs bras façon divinité
dansante (évoque Shiva Nataraja) — risque culturel/religieux, refusé.*

*Texte post-prod : « IMMORTALIZE YOUR FESTIVAL ».*

---

## Check avant upload (par visuel)

- [ ] Format exact : icône 512×512, thumbnails 1920×1080
- [ ] Palette §9 respectée (dominante navy + or lunaire, néons cyan/magenta)
- [ ] Conformité §11 : rien qui ressemble à de l'alcool (les stands = smoothies
  et fruit buckets), personnages habillés, aucun logo/marque
- [ ] Représentatif du jeu réel (pas de promesse visuelle mensongère)
- [ ] Aucune fausse UI générée (HUD, boutons, compteurs de devise/niveau —
  les seuls textes admis sont le titre sur l'icône et le texte post-prod)
- [ ] Texte lisible en miniature (l'icône est souvent vue en 64×64)
