# Super Sprint Reforged — notes pour Claude

Lis ce fichier en entier avant toute modification. La carte du jeu est dans
`docs/fr/CODE_MAP.md`, la méthode dans `docs/fr/METHODOLOGIE.md`, les
différences avec le jeu d'origine (texte distribué) dans `dist/LISEZMOI.TXT`
et `dist/README.TXT`.

## Le projet

Correctifs pour *Super Sprint* (Atari ST, Electric Dreams 1986, programmé
par State of the Art), à partir du `SUPER2.DAT` de l'utilisateur (le
programme du jeu, un PRG GEMDOS ; très probablement le fichier d'origine,
non vérifié sur disquette originale). `tools/patch_ss.py` en fait
`SSPRINT.PRG` : notre code `src/p4.s` est ajouté à la fin du TEXT, le BSS
est agrandi, et les données (`SUPER.DAT`, `SUPER1.DAT`, `INIT.DAT`,
`SSPRINT.HSC`, `SSPRINT.SEQ`) sont recopiées telles quelles.

- **v1.0.0** (tag sur `4c49297`, validée sur machine réelle) : 4e joueur
  humain (voiture verte, F5), contrôles en plus pour toutes les voitures
  (joysticks sur adaptateur parallèle, joypads STE/Falcon), en-tête de course
  à 4 colonnes, installation sur disque dur, RESET qui relance le TOS, écran
  titre redessiné par Strider avec crédits et numéro de version.
- Testée par Strider sur STF 1 Mo, STE 4 Mo, Mega STE 4 Mo, Falcon030 14 Mo
  (RVB et VGA) et Falcon CT60 (VGA compris). STF 512 Ko non testé (il
  faudrait lancer depuis le dossier AUTO).
- Limites connues : la verte ne peut pas lancer une partie depuis l'écran
  titre (seulement la rejoindre) ; deux voitures ne peuvent pas avoir le même
  contrôle, « none » compris (règle d'origine).

Le propriétaire, **Strider** (game design, essais, graphismes additionnels),
teste sur STF, STE, Mega STE et Falcon. Ce qu'on ne peut valider que sur la
machine, on le lui demande avec une liste précise. Crédits dans les textes
distribués : « Reverse engineering and code: Claude AI (Anthropic) » et
« Game design, testing and additional graphics: Strider » ; ne pas y mettre
son nom civil.

## Règles absolues

1. **Aucun contenu du jeu dans le dépôt** : ni `.DAT`, ni PRG produit, ni
   image ou capture tirée du jeu, ni ROM TOS. Le `.gitignore` les exclut ;
   vérifie quand même `git status` avant chaque commit. L'écran titre de
   Strider n'est stocké que sous forme de correctif (`src/title.inc` :
   pixels redessinés + palette), jamais son PI1 complet.
2. **Chaque correctif vérifie les octets d'origine** (listes `(adresse,
   octets d'origine, nouveaux)` dans `patch_ss.py`) et le MD5 de
   `SUPER2.DAT` ; `tools/check_data.py` vérifie taille et MD5 des autres
   fichiers (et repère un fichier compressé, comme dans certains cracks).
3. **Sorties reproductibles** : `make check` compare le MD5 de
   `SSPRINT.PRG`. Le MD5 par défaut dépend de la version affichée sur
   l'écran titre (`REF_VERSION` dans le `Makefile`). À chaque version : mettre
   à jour `REF_VERSION` et les MD5 dans le `Makefile`, `README.md` et
   `README_FR.md`, puis faire poser le tag sur ce commit.
4. **Français** pour les commentaires, les messages des outils et
   `docs/fr/` ; `README.md` (anglais) et `README_FR.md` (français) ont le
   même contenu et gardent l'avertissement juridique. Messages de commit en
   anglais.
5. Toujours tester dans Hatari avant de livrer, et dire clairement ce qui
   n'a été vérifié que dans l'émulateur.

## Reprendre le travail (nouvelle session)

La machine de la session est temporaire : tout ce qui n'est pas poussé
disparaît. Dans ce dépôt, on travaille directement sur `master` (commits
poussés au fil de l'eau).

1. **Outils** : `make` construit vasm dans `.tools/` (`scripts/get-vasm.sh`).
   Pour l'étude et les essais : `pip install capstone pillow numpy` ; Hatari,
   Xvfb et xdotool pour `hatari/runx.sh`.
2. **Fichiers du jeu**, jamais dans le dépôt : Strider les envoie dans la
   conversation (ils arrivent dans `/root/.claude/uploads/<session>/`). Les
   ranger hors du dépôt (par exemple `../ssprint-local/game/`) avec les ROM
   (`tos104.img` STF, `tos162.img` STE, `tos206.img` Mega STE). EmuTOS
   (`etos256uk.img`) suffit pour la plupart des essais.
3. **Étiquettes** : format `v1.N.M`. Le proxy git des sessions refuse de
   pousser les tags, et l'API GitHub refuse leur création : donner la
   commande à Strider (`git tag -a v1.0.1 <commit> -m ...` puis
   `git push origin v1.0.1`), après avoir poussé le commit avec les MD5 de
   cette version.
4. **Livrer** à Strider un zip du dossier `build/SSPRINT` (il contient le jeu
   corrigé : jamais dans le dépôt ni dans une release GitHub).

## Construire

```sh
make                                  # build/p4.bin (notre code seul)
make game GAME=/chemin/vers/le/jeu    # build/SSPRINT/ (+ README.TXT, LISEZMOI.TXT)
make check                            # MD5 attendu
make game GAME=... P4=0               # correctif disque dur seul
make game GAME=... VERSION=1.0.0      # forcer le numéro affiché
make listing GAME=...                 # work/ss.lst (désassemblage, capstone)
```

| Fichier | Taille | MD5 |
|---|---|---|
| `SUPER2.DAT` | 74 355 | `2d828d5478e14b7e7b7bbb820ade4cfd` |
| `SUPER.DAT` | 212 650 | `3692bea1615e36f003cec5e14bc54669` |
| `SUPER1.DAT` | 17 024 | `b3c2e08bb9fd5ab92eab39b45fd713a1` |
| `INIT.DAT` | 5 139 | `68d72c8952f071b6b0ca513d8bf1c989` |
| `SSPRINT.PRG` v1.0.0 | 84 114 | `c9263001cba8427109130b767228dbb3` |
| `SSPRINT.PRG` `P4=0` | 74 355 | `65e5b04c48c3b07f4154a15d7a9f0c51` |

- `tools/patch_ss.py` : correctifs, ajout de `p4.bin`, relocations,
  `--version` (8 octets `$FE` réservés dans `txcred`), `--autopilot` (essais :
  voitures humaines conduites par l'IA).
- `tools/title_patch.py <PI1> <titre d'origine en PNG indexé> src/title.inc` :
  à relancer si Strider retouche l'écran titre (l'original s'obtient par une
  capture Hatari, palette du jeu dans l'ordre d'origine).
- `tools/txt2st.py` : `dist/*.TXT` (UTF-8) → jeu de caractères ST (CP437 pour
  $80-$AF), CR LF, 78 colonnes au plus. Pas de « À » ni de « œ ».
- `tools/trace_ss.py`, `tools/show.py <début> <fin>` : listing et extraits.

## Le jeu et notre code (à respecter)

- Le jeu est en C compilé : a4 = base DATA/BSS (variables en `-$xxxx(a4)`),
  a5 = base du TEXT, appels par une table de sauts `jsr $xx(a5)` (entrées
  relogées : on les détourne vers nos routines). Nos routines sont appelées
  par une table d'entrée en tête de `p4.s` (`B + 4*n`, B = $11CCC = fin du
  TEXT d'origine ; `E(n)` dans `patch_ss.py`). Ajouter une entrée = ajouter
  un `bra.w` à la fin de la table.
- **BSS ajouté** : `BSSX` = 4096 octets, à `P4B = -$2B74-BSSX` (même valeur
  dans `p4.s` et `patch_ss.py`). Zones utilisées : tables podium et
  « customize car » (`UPCOL`…), octets d'état (`HUDCLR`, `HRACE`, `RTBON`,
  `HSTEP1`), raster de course (`RCNT`, `RPALS`), cache de l'en-tête (`HDR`,
  2 écrans × 48 octets) et copies des colonnes (`HSAVE`, jusqu'à 4096).
- Les boucles « 3 voitures » du jeu ont été étendues à 4 (voir CODE_MAP) ;
  la voiture 3 (verte) était un drone pur : chaque nouvelle fonction du jeu
  touchée doit être vérifiée pour elle (ex. améliorations non remises à zéro,
  score jamais clignotant).
- **En-tête de course** (`hupd`) : cache des valeurs affichées par écran ;
  en course un seul élément par image (vitesse). Dessin aussi dans le fond
  `BACKGND` (`-$56`, d'où les voitures restaurent l'écran) et dans le masque
  de priorité des sprites (`-$5E`+`$3E80`, 1 bit/pixel, 0 = devant).
  Le clignotement du premier (`hblink`) efface écran **et** fond ; le témoin
  d'écran n'est pas vérifié en course.
- **Écran titre** : image n° 8 de `F_0AFCE` ; `title5` applique `title.inc`
  puis les crédits (police du jeu `FONT` -$1E5A : 0-9, « . » = 10, A-Z =
  12-37, espace = 38, **pas de minuscules**) ; palette du titre en
  `-$1534(a4)` (lue dans INIT.DAT), remplacée par `init`.
- Palettes : course `RACEPAL` (raster à 2 bandes posé par `rpal`, notre
  Timer B `rtb`), podium `-$1654`, « customize car » `-$171E`.
- `F_0C462` et d'autres routines graphiques du jeu **modifient d0-d7 sans
  les sauver**.

## Tester dans Hatari

- `hatari/runx.sh <nom> <machine> <tos> <secondes> <touches>` (Xvfb +
  xdotool, joysticks émulés, voir `joy4.cfg`). Lignes du script de touches :
  `t down|up|tap <touche>`, `t cmd <raccourci>` (ex. `warmreset`),
  `t raw <commande>` (ex. `hatari-debug savebin fichier 0 $100000`).
  `SHOTS` = captures par seconde, `HD`/`PRG` = dossier et programme.
- `hatari/keys/` : `race_green.keys` (partie avec la verte sur le joypad A,
  triche `*`), `track_steps.keys` (choix du circuit pas à pas au clavier,
  bleue sur « keyboard » : touche `z` ; le minutage n'est pas fiable, vérifier
  le circuit obtenu), `reset.keys`.
- Clavier du jeu : A/Z/L gauche, D/X/' droite, Maj/Alt accélérer ; Hatari
  ignore les touches de joystick quand Maj est enfoncée.
- Vitesse : `hatari/vbl.py` (voir son en-tête) ; attendu 1,00 VBL par image
  en course.
- Pour que le bleu ou la verte mène une course : `patch_ss.py --autopilot`.

## Pièges déjà rencontrés

- **Hatari ne reproduit pas tout** : le RESET bloquait la machine réelle (la
  routine `resvector` du jeu) mais pas Hatari, même avec les vrais TOS.
- Les captures Hatari sont en 4 bits par composante (×17) ; les valeurs ST
  sont sur 3 bits. Ne pas reconstruire une palette sans la vérifier sur une
  capture (une ancienne copie de l'écran titre avait une palette fausse).
- Le jeu choisit la voiture mise à jour par `(image mod 6) / 2` : la verte
  n'était jamais traitée (`fmod` passe à modulo 8).
- Le témoin d'écran de l'en-tête était dans la colonne bleue : le
  clignotement le modifiait et vidait le cache à chaque image.
- Le proxy git refuse les tags (voir plus haut) ; `git push` d'un tag finit
  par « remote end hung up ».
