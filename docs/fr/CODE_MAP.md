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

## Code de la 4e voiture (`src/p4.s`, `tools/patch_ss.py --p4`)

| Accroche | Remplace | Rôle |
|---|---|---|
| `$6224`, `$6314`, `$6330` | `-$12C4/-$12C3(a4)` | Octets joysticks IKBD déplacés en `-$124E/-$124D(a4)` (cases `$74`/`$75` du tableau des touches, jamais écrites) : `-$12C4(a4)` devient **`ctl[3]`** |
| `$6340` → `ext629c` | `move.w #0,d0 / bra` | Contrôles 4–7 : port parallèle (prises « joystick 3 » et « joystick 4 ») et joypads STE A/B, lus en superviseur (`Supexec`) |
| table de sauts `$24` → `init` | `jmp F_0624A` | `ctl[3]` = 1 (« none ») au démarrage ; détection du joypad (cookie `_MCH` = STE, Mega STE ou Falcon) |
| `$E422` → `joindraw` | `jsr F_0E67C(pc)` | Pas de texte d'en-tête pour la voiture 4 |
| `$E484` | `cmpi.w #3` | `F_0E3CA` : 4 voitures |
| `$F53A` → `joindraw2` | `jsr F_0F560(pc)` | Idem pour `F_0F4E2` |
| `$F552` | `cmpi.w #3` | `F_0F4E2` : 4 voitures |
| `$EA10`, `$ED6E` → `xpos_i` ; `$EC04` → `xpos_k` | `lea XTAB(a4),a0 / adda.w d0,a0` | Position du libellé ; pour la voiture 4 : dans la 1re ligne d'aide, y corrigé sur la pile |
| `$EA28`, `$EC1C`, `$ED86` → `names` | `lea -$21CA(a4),a0 / adda.w d0,a0` | Noms des contrôles 4–7 |
| `$EA40`, `$ED9E`, `$ECBC`, `$ECCA` | `cmpi.w #3` | Options : affichage et contrôles en double sur 4 voitures |
| `$EBA4` | `cmpi.w #5` | Touches F2 à **F5** |
| `$EBBE` | `and.w #3` | 8 valeurs de contrôle |
| `$EBE0` | `bne` | Le 1 n'est plus sauté (« none ») |
| `$EC96` | `bne` | Plus de conflit souris / joystick 0 |
| DATA `+$1F4` | « mouse » | « none » |
| DATA `+$23E` | « use function keys to select controls for cars » | « f5 - green car » (le nom du contrôle est ajouté à droite) |
