# Super Sprint — carte du code

*Notes de travail, en français. Voir aussi [METHODOLOGIE.md](METHODOLOGIE.md).*

Programme étudié : `SUPER2.DAT` (MD5 `2d828d5478e14b7e7b7bbb820ade4cfd`), programme GEMDOS ordinaire. Listing : `python3 tools/trace_ss.py SUPER2.DAT` → `work/ss.lst` ; extraits : `python3 tools/show.py <début> <fin>`.

**Adresses** : décalages depuis le début du TEXT (le listing charge le programme en 0). Les variables sont notées `@xxxxx` : c'est leur adresse dans la disposition du fichier (TEXT, DATA, BSS à la suite), telle que le listing l'affiche en commentaire.

## Segments et registres de base

| Élément | Valeur |
|---|---|
| TEXT | `$11CCC` octets |
| DATA | `$522` octets |
| BSS | `$2B74` octets |
| Relocations | 101, **toutes dans le TEXT** : le `jmp` d'entrée et la table de sauts |

C'est du **C compilé** (`link a6` / `unlk a6` / `rts`). Le démarrage (`$25E`) :

1. `Mshrink` ;
2. **recopie le DATA juste après le BSS** (`$2A8`), puis efface le BSS ;
3. `a4 = p_dbase + p_blen` : a4 pointe sur le **DATA déplacé**. Donc `-$xxxx(a4)` = BSS, `+$xxxx(a4)` = DATA ;
4. `a5 = p_tbase` : **début du TEXT**. `jsr $NN(a5)` passe par la **table de sauts** `TEXT+$6`…`$25D` (`jmp adresse.l`, relogés).

Conséquence utile : on peut **allonger le TEXT** (ajouter du code à la fin) sans rien corriger d'autre, puisque le DATA et le BSS ne sont atteints que par a4, recalculé au démarrage.

## Démarrage et protection

| Adresse | Rôle |
|---|---|
| `$0` | `jmp $25E` |
| `$9512` | Initialisations : chargement de `init.dat`, `F_0624A` (IKBD) via `jsr $24(a5)`, `F_05EB8` (protection)… |
| `F_05EB8` | **Protection** : `Floprd` du secteur de boot du lecteur A:, puis compare les octets 8–10 à `"SOA"` (écrit sous la forme `$52+1`, `$50-1`, `$42-1`). Échec → `@14CCC = 1` |
| `$9812` | Si `@14CCC` ≠ 0, la course s'arrête aussitôt |
| `F_05D0A` | Sauvegarde de `ssprint.hsc`, seulement si `@14CCC` = 0 |

Le chargeur `AUTO/SUPER.PRG` (crack 42-crew, 27/11/87) saute sa propre vérification de piste et fait `Pexec(0, "SUPER2.DAT")`. La vérification du secteur de boot reste dans `SUPER2.DAT` : la copie ne marche que depuis une disquette dont le secteur de boot contient `SOA`. Sous EmuTOS sans disquette, `Floprd` attend indéfiniment pendant que l'écran titre défile.

## Entrées

| Adresse | Rôle |
|---|---|
| `F_06186` | Via `Supexec` : `Mfpint(6, $61B2)` remplace l'interruption ACIA |
| `$61B2` | Gestionnaire IKBD (installé par `pea`, noté `I_061b2` par le traceur). Paquet `$FE` → joystick 0, `$FF` → joystick 1, rangés en `-$12C4(a4)` + (0 ou 1). Touches : tableau `-$12C2(a4)[scancode]`, 3 = appuyée, bit 0 effacé au relâchement, codes ≥ `$76` ignorés |
| `F_0626A` | Envoie une commande à l'IKBD (`$14` : joysticks en mode événement) |
| `F_06354` | Renvoie la touche de fonction appuyée : F1 = 1 … F10 = `$A` (et l'efface) |
| **`F_0629C(type)`** | **État d'un contrôle** : 0 = clavier (A/Z/L → gauche, D/X/' → droite, Maj/Alt → accélérer), 2 = joystick 0, 3 = joystick 1, autre → 0. Format : bits 0–3 = haut, bas, gauche, droite (actifs à 1), bit 7 = accélérer |

## Voitures

Quatre voitures, indice i = 0 (bleue), 1 (rouge), 2 (jaune), 3 (**verte, le « drone »**). Les tableaux par voiture ont 4 cases, sauf celui des contrôles.

| Variable | Rôle |
|---|---|
| `-$12CA(a4)` (`@13A98`) | **`ctl[3]`** : contrôle de chaque voiture humaine (mots). Valeurs par défaut lues dans `init.dat` (`F_05A76`, 6 octets) |
| `-$12C4(a4)` | Dans l'original : les 2 octets des joysticks IKBD, **juste après `ctl[2]`** |
| `-$F4A(a4)` (`@13E18`) | `drone[4]` : 1 = voiture pilotée par l'ordinateur |
| `-$21CA(a4)` (`@12B98`) | 4 pointeurs vers les noms des contrôles (« keyboard », « mouse », « joystick 0 », « joystick 1 ») |
| `-$21D8(a4)` (`@12B8A`) | x des libellés de l'écran des options, par voiture (3 cases) |

| Adresse | Rôle |
|---|---|
| `$24DC` | Boucle des 4 voitures : si `drone[i]` = 0 → `F_031F6(i)` (humain), sinon `F_047E6(i)` (ordinateur) |
| `F_031F6(i)` | Pilotage humain : `F_0629C(ctl[i])` |
| `F_0969A` | Écran titre / démo : le tir d'un contrôle i < 3 lance une partie (`F_0975A(i)`) |
| `F_0E3CA` | Une voiture « drone » dont le contrôle tire rejoint la course (i < 3) ; `F_0E67C` écrit dans la colonne x = 15 + 107·i de l'en-tête |
| `F_0F4E2` | Idem pendant « prepare to race » ; dessin par `F_0F560` dans la colonne i |
| `F_0E850` | **Écran des options** : F2–F4 font tourner `ctl[touche−2]` modulo 4, en sautant 1 (souris) ; F9 = son ; F10 = sortie, refusée si deux contrôles sont égaux ou si souris et joystick 0 sont pris ensemble |
| `F_0C192(écran, texte, x, y, c1, c2)` | Affichage d'un texte (police de 6 pixels de large) |

La valeur 1 (« mouse ») n'est **jamais proposée** par l'écran des options, et `F_0629C` renvoie 0 pour elle : la souris n'est pas gérée dans cette version.

Environ 45 boucles sont bornées à 3 (joueurs humains) dans une vingtaine de fonctions, et 37 à 4 (toutes les voitures). Liste : voir `METHODOLOGIE.md` §5.

## Écrans, affichage, fin de course

| Adresse | Rôle |
|---|---|
| `F_0975A(i)` | **Partie** : choix du circuit (`F_0EE60`), « prepare to race » (`F_0DD20`), puis boucle : course (`F_01B3C`), podium (`F_101C6`), « customize car » (`F_0F680`), « prepare to race », circuit suivant. Fin quand toutes les voitures sont des drones (`$97EC`) |
| `F_0EE60` | Choix du circuit ; au début de la partie, toutes les voitures redeviennent drones sauf celle qui a lancé la partie |
| `F_0DD20` | « Prepare to race » : chaque drone peut rejoindre (`F_0E3CA`), décompte, animations des pilotes sur l'image des voitures, puis `F_0CFEC` |
| `F_0CFEC` | Saisie des initiales des joueurs qui n'ont pas continué ; voitures servies à tour de rôle, une par image |
| `F_101C6` | Podium (« winner's circle », 4 places). Couleurs de chaque voiture : 3 mots copiés dans la palette de sa bande depuis `-$167E(a4)` (`$104D2`). En `$10FA8` : **tout humain classé derrière le premier drone redevient drone** (règle de l'arcade), sur les 4 voitures |
| `F_0F680` | Pour chaque humain ayant plus de 3 clés à molette : écran « customize car » (`F_0F6DA`) |
| `F_0A546(src, dst)` | Décompression d'une image (RLE par plan). `-$66(a4)` : image « 3 voitures » (options, prepare to race, initiales) |
| `F_0A3DE(écran, palettes, durées)` / `F_055CC` | Fondu puis raster Timer B : une palette de 16 couleurs (`$20` octets) par bande, durées en unités de 2 lignes. Options et prepare to race : palettes `-$16DE(a4)`, durées `-$17DA(a4)` = 26, 30, 255 |
| `F_0C4F8(écran, texte, couleur, x, y)` | Grand titre, 11 pixels par caractère ; `F_0C462` dessine un caractère et **modifie d0-d7 sans les sauver** |
| `F_0C192(écran, texte, x, y, c1, c2)` | Petit texte, 6 pixels par caractère |
| Colonnes du haut | `x = base + $6B*i` (3 colonnes de 107 pixels) dans `F_0E67C`, `F_0E78C`, `F_0F4E2`, `F_0EE60`, `F_0DD20`, `F_0CFEC` et les fonctions des initiales |

### En-tête et bas de l'écran de course

| Adresse | Rôle |
|---|---|
| `F_0A1C6(écran, i)` | Libellé « BLUE CAR » (ou « DRONE » si drone), colonnes `[0, $38, $68]` |
| `F_0A236(écran, i)` | Chiffre des clés à molette (`@13DF0[i]`) ; rien pour un drone ni pour la voiture 3 |
| `F_0B5E6(écran, i)` | Score : 6 chiffres par voiture (`@13A74 + 6i`, 4 voitures ; négatif = vide), 3 versions déroulées, une par colonne |
| `F_0BB56(écran, i)` | Tour (`@13E20[i]`) |
| `F_0A2E4` / `F_0A31C` | Chiffre de « DRONE LAP n » (ligne 194, x = 176) et restauration du fond |
| `-$1E5A(a4)` | Petite police : 8 octets par caractère, 0-9, « . », « ! », A-Z (12-37), espace (38) |
| `-$4E(a4)` / `-$56(a4)` | Écran en cours de dessin / image de fond de la course |

## Code de la 4e voiture (`src/p4.s`, `tools/patch_ss.py --p4`)

| Accroche | Remplace | Rôle |
|---|---|---|
| `$6224`, `$6314`, `$6330` | `-$12C4/-$12C3(a4)` | Octets joysticks IKBD déplacés en `-$124E/-$124D(a4)` (cases `$74`/`$75` du tableau des touches, jamais écrites) : `-$12C4(a4)` devient **`ctl[3]`** |
| `$6340` → `ext629c` | `move.w #0,d0 / bra` | Contrôles 4–7 : port parallèle (prises « joystick 3 » et « joystick 4 ») et joypads STE A/B, lus en superviseur (`Supexec`) |
| table de sauts `$24` → `init` | `jmp F_0624A` | `ctl[3]` = 1 (« none ») au démarrage ; détection du joypad (cookie `_MCH` = STE, Mega STE ou Falcon) |
| `$E484`, `$F552` | `cmpi.w #3` | `F_0E3CA`, `F_0F4E2` : 4 voitures |
| `$EA10`, `$ED6E` → `xpos_i` ; `$EC04` → `xpos_k` | `lea XTAB(a4),a0 / adda.w d0,a0` | Position (x, y) du libellé de chaque voiture (table `labxy` : 4 colonnes de 80 pixels), y corrigé sur la pile |
| `$EA28`, `$EC1C`, `$ED86` → `names` | `lea -$21CA(a4),a0 / adda.w d0,a0` | Noms des contrôles 4–7 |
| `$EA40`, `$ED9E`, `$ECBC`, `$ECCA` | `cmpi.w #3` | Options : affichage et contrôles en double sur 4 voitures |
| `$EBA4` | `cmpi.w #5` | Touches F2 à **F5** |
| `$EBBE` | `and.w #3` | 8 valeurs de contrôle |
| `$EBE0` | `bne` | Le 1 n'est plus sauté (« none ») |
| `$EC96` | `bne` | Plus de conflit souris / joystick 0 |
| DATA `+$1F4` | « mouse » | « none » |
| DATA `+$23E` | « use function keys to select controls for cars » | chaîne vide |
| DATA `+$26C` | « f2 - blue car   f3 - red car   f4 - yellow car » | « f2 blue  f3 red  f4 yellow  f5 green » |
| table de sauts `$132` → `hud4` | `jmp F_0A2E4` | Voiture verte humaine : ligne du bas « GREEN CAR », clés, tour, score |
| table de sauts `$18C` → `dec4` | `jmp F_0A546` | Image « 3 voitures » : la rouge passe sous la bleue, copie verte sous la jaune (recoloration par plans) ; palette P2 : couleurs 1-2 vertes ; P0[4] vert |
| `$E8A6` → `titles` | 6 appels de `F_0C4F8` | Titres des 4 voitures en haut, sur 4 colonnes (bleue, rouge, jaune, verte), comme « prepare to race » |
| `$97EC` → `alldrone` | `drone[0] & drone[1] & drone[2]` | Fin de partie : les 4 voitures |
| 11 calculs `base + $6B*i` | | 4 colonnes de 80 pixels : `base - 11 + $50*i` |
| `$DE0C`, `$EFB0`, `$E308` → `col4a/b/c` | appels de `F_0E78C`, `F_0F60C`, `F_0C224` | 4e colonne vide si la voiture 4 n'a pas de contrôle |
| `F_0DD20` : cadre de pile, `$DE9E`, `$E29E`, `$E314`, `$E348` → `prepchk` | tableaux locaux de 3 mots | 4 mots (`-$3C`, `-$34`, `-$2C`, `-$24(a6)`), boucles à 4 |
| `F_0CFEC` : cadre de pile, 5 boucles, `$D31C`, `$D672` → `inichk` | tableaux locaux pour 3 voitures | 4 voitures ; tour de rôle `(compteur / 2) & 3` |
| `$F6CC` | `cmpi.w #3` | « Customize car » pour 4 voitures |
| `$F300`, `$110A8` | `cmpi.w #3` | Clés à molette de départ (difficulté) ; remise à zéro des clés d'un joueur éliminé |
| `$104EE`, `$1054A` | `cmpi.w #3` ; `lea -$167E(a4)` | Podium : 3 couleurs par voiture, indice = voiture + 4 × drone (la voiture 3 était toujours « drone ») ; table à 8 entrées dans `P4B+80` : 3 = verte humaine (`$573`, `$040`, `$070`), 7 = verte drone |
| 10 tables de positions `-$2184` … `-$21BA(a4)` | 3 cases | 4 cases dans 256 octets ajoutés au BSS (`P4B`), remplies par `init` |

### Boucles bornées à 3 qui restent (examinées, sans effet sur la 4e voiture)

| Fonction | Rôle de la boucle |
|---|---|
| `F_01B3C` (`$1FE0`, `$2096`, `$2228`), `F_027A4`, `F_0BE2E`, `F_101C6` (`$10236`, `$1026E`, `$10CB4`), `F_0F6DA` (`$F778`, `$F7B0`) | Affichage des 3 colonnes de l'en-tête (la verte a la ligne du bas) |
| `F_0969A` | Écran titre : les voitures 0 à 2 seulement peuvent lancer une partie |
| `F_06C78` | Division |
| `F_0C760`, `F_0C894` | Tableau des records (3 colonnes) |
| `F_0D72E`, `F_0D772` | Les 3 lettres des initiales |
| `F_112EA` | Chiffres d'un nombre |
| `F_101C6` `$104A8`, `$11002` | Tri du classement (3 comparaisons pour 4 voitures) et règle « derrière le premier drone » (positions 0 à 2) |
