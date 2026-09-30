# Super Sprint (Atari ST) — méthode et constats

*Notes de travail, en français. Voir aussi [CODE_MAP.md](CODE_MAP.md) (carte du code).*

Même règle que pour IK+ Reforged : **aucune affirmation sans les octets qui la portent**, et aucun fichier du jeu dans le dépôt. Les outils vérifient l'empreinte MD5 et les octets d'origine avant d'écrire.

## 1. Les fichiers

Version étudiée : Super Sprint, Electric Dreams / State of the Art, 1986, craquée par 42-crew (27/11/87).

| Fichier | Taille | MD5 | Nature |
|---|---|---|---|
| `AUTO/SUPER.PRG` | 655 | `edc0e882f050da6693641317c4845134` | Chargeur (crack) : écran basse résolution en `$78000`, message, `Pexec(0, "SUPER2.DAT")` |
| `SUPER2.DAT` | 74 355 | `2d828d5478e14b7e7b7bbb820ade4cfd` | **Le jeu** : PRG GEMDOS (`$601A`), TEXT `$11CCC`, DATA `$522`, BSS `$2B74`, 101 relocations |
| `SUPER.DAT` | 212 650 | `3692bea1615e36f003cec5e14bc54669` | Graphismes (chargé par le jeu) |
| `SUPER1.DAT` | 17 024 | `b3c2e08bb9fd5ab92eab39b45fd713a1` | Données (chargé par le jeu) |
| `INIT.DAT` | 5 139 | `68d72c8952f071b6b0ca513d8bf1c989` | Réglages initiaux, dont les contrôles par défaut |
| `SSPRINT.HSC` | 295 | `711ae49a3752a43b729a6dbf9fb41fa2` | Meilleurs scores et temps (réécrit par le jeu) |
| `SSPRINT.SEQ` | 295 | `6a98c70248910fd3b28878949e674d10` | Même format que `.HSC` |

Le chargeur contient la protection d'origine : `Floprd` sur la piste 79 (`$4F`) en `$76000` puis `jsr $76000`, et deux autres lectures qui doivent échouer avec -8 et -11. Le crack la saute par un `bra` (`$F4` → `$18C`). Il reste une **seconde protection** dans `SUPER2.DAT` (voir §4).

## 2. Différences avec IK+

| | IK+ | Super Sprint |
|---|---|---|
| Format | Image mémoire brute, chargée en `$700` | PRG GEMDOS relogeable |
| Code | Assembleur | **C compilé** (`link`/`unlk`, variables par a4, appels par a5) |
| Machine | Le jeu écrase le TOS | Le jeu reste sous TOS (GEMDOS, XBIOS) et tourne en mode utilisateur |
| Place pour notre code | Zone libre `$800`–`$BFF` | **Ajout à la fin du TEXT** |

Adaptations des outils :

- `tools/trace_ss.py` (d'après `trace_ik.py`) lit l'en-tête et la table de relocation : un mot long relogé est un pointeur certain. Il suit les appels par la table de sauts (`jsr $NN(a5)`), prend chaque `link a6` comme début de fonction, et essaie les cibles de `lea/pea x(pc)` (routines d'interruption). Il annote chaque accès `x(a4)` avec l'adresse de la variable. Résultat : 98 % du TEXT reconnu comme code.
- `tools/patch_ss.py` reconstruit le PRG : TEXT allongé, DATA inchangé, table de relocation réencodée. Sans `--p4`, il redonne à l'octet près la version corrigée à la main (vérifié).

## 3. Environnement de test

- **Hatari 2.4.1** (paquet Ubuntu). Pas de ROM Atari : **EmuTOS 1.3** (libre) suffit. `etos192uk.img` pour l'ST ; `etos256uk.img` pour l'STE (Hatari traite l'image 192 Ko comme un TOS 1.x et repasse en mode ST).
- Disque GEMDOS sur un dossier, `--auto C:\SSPRINT.PRG`. Le chargeur `AUTO/SUPER.PRG` échoue sous EmuTOS (son `Mshrink` renvoie une erreur et il boucle sur la couleur du fond) : on lance directement le jeu.
- `hatari/run.sh` : sans écran, une capture par seconde, touches par `--cmd-fifo`. `hatari/runx.sh` : Xvfb + xdotool, les touches passent par l'émulation des joysticks de Hatari, y compris **joypads STE** (`Joystick2`/`3`) et **port parallèle** (`Joystick4`/`5`). Voir `hatari/joy4.cfg`.
- Attention : Hatari ignore les touches des joysticks tant que **Maj** est enfoncée (`Joy_KeyDown`).
- Débogueur : `--parse` avec des expressions relatives au programme, qui marchent quelle que soit l'adresse de chargement :
  - `b pc = TEXT && pc < $400000 :once :file f.ini` puis `info basepage` ;
  - `m "TEXT+$11EF6+$2B74-$F4A" 8` : variable `-$F4A(a4)` (a4 = TEXT + TEXT_len + BSS_len) ;
  - `history cpu 20000` puis `b VBL = 1500 :file …` : où tourne le programme ;
  - pile (`m a7 …`) : c'est ainsi qu'on a trouvé l'appel `Floprd` bloquant.

## 4. Constats

### 4.1 La copie ne démarre pas depuis un disque dur

- L'écran titre défile sans fin et aucune touche n'est lue. Historique CPU : seules les interruptions du jeu et une boucle d'EmuTOS sur `_hz_200` tournent. La pile donne le retour `$9568`, juste après `jsr $9C(a5)` → **`F_05EB8`**.
- `F_05EB8` fait `Floprd(tampon, 0, lecteur 0, secteur 1, piste 0, face 0, 1)` et compare les octets 8–10 du secteur de boot à `"SOA"`. En cas d'échec, `@14CCC = 1` : la course s'arrête aussitôt (`$9812`) et les records ne sont pas sauvés (`F_05D0A`).
- Correctif : `$5EC8` : `moveq #8,d5 / move.w #1,-(a7)` → `bra $5F22` (`unlk a6 / rts`). Le jeu tourne alors depuis un disque dur, sous EmuTOS, en ST et en STE.

### 4.2 Les joueurs

- L'arcade *Super Sprint* se joue à 3 ; la 4e voiture est un **drone**. Il en est de même ici : bleue, rouge, jaune peuvent être humaines ; la **verte** est toujours pilotée par l'ordinateur.
- Les contrôles sont un tableau de 3 mots, `ctl[3]` en `-$12CA(a4)`, **immédiatement suivi** des 2 octets joystick écrits par le gestionnaire IKBD. En déplaçant ces 2 octets (3 accès), on obtient la 4e case sans rien déplacer d'autre.
- Toutes les lectures de `ctl[]` passent par `F_0629C` : c'est le seul point à étendre pour ajouter des contrôles.
- L'écran des options calcule l'indice par `touche − 2` : **F5 tombe exactement sur `ctl[3]`** une fois la case libérée.

## 5. Voiture 4 jouable : état

Fait (`src/p4.s`, `tools/patch_ss.py --p4`) et vérifié sous Hatari :

- touche **F5** dans les options : contrôle de la voiture verte, affiché dans la 1re ligne d'aide (« f5 - green car … ») ;
- nouveaux contrôles pour toutes les voitures : **joystick 2** (adaptateur parallèle, prise « joystick 3 » : D4–D7 + BUSY), **joystick 3** (prise « joystick 4 » : D0–D3 + STROBE), **joypad a**, **joypad b** (STE, Mega STE, Falcon ; ignorés ailleurs grâce au cookie `_MCH`) ;
- « mouse », jamais utilisable, devient « **none** » : valeur par défaut de la voiture verte, qui reste alors un drone. Un adaptateur absent ne peut donc pas l'inscrire par erreur ;
- la voiture verte rejoint la course quand son contrôle accélère pendant « prepare to race » (`F_0F4E2`, vérifié), puis se pilote comme les autres. L'autre boucle d'inscription, `F_0E3CA` (appelée depuis `F_0DD20`), est aussi étendue à 4 voitures mais n'a pas encore été essayée.

Vérifications faites (Hatari, EmuTOS) : ST + joystick parallèle, STE + joypad A. Mémoire : `ctl = [0,2,3,4]` ou `[0,2,3,6]`, `drone = [0,1,1,0]` après inscription.

Reste à faire :

- **Affichage** : l'en-tête n'a que 3 colonnes (score, tours). La voiture verte n'a que la ligne du bas « DRONE LAP » ;
- **Écran titre** (`F_0969A`, borné à 3) : la voiture verte ne peut pas lancer une partie, seulement la rejoindre ;
- fin de partie, scores, saisie des initiales : boucles bornées à 3 à vérifier une par une (`F_01B3C`, `F_027A4`, `F_0CFEC`, `F_0EE60`, `F_101C6`…) ;
- deux voitures sur « none » sont refusées par la règle « contrôles en double » ;
- essais sur machine réelle (adaptateur parallèle, joypads STE).
