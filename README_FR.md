# Super Sprint Reforged

*[English version](README.md)*

Rétro-ingénierie, correctifs et outils pour **Super Sprint** (Electric Dreams, 1986) sur Atari ST, avec les méthodes et outils d'[IK+ Reforged](../README_FR.md) :

- **installation sur disque dur** : la protection restante (lecture du secteur de boot de la disquette) est neutralisée ; le jeu tourne depuis un disque dur (testé sous EmuTOS, sur ST et STE) ;
- **4e joueur** : la voiture verte, jusqu'ici toujours pilotée par l'ordinateur (le « drone »), peut être prise par un humain ;
- **nouveaux contrôles**, pour toutes les voitures : joystick sur **adaptateur port parallèle** (deux prises) et **joypads STE** A et B.

> ## ⚠️ Avertissement
>
> *Super Sprint* © 1986 Atari Games, adaptation Atari ST © 1986 Electric Dreams Software. Ce projet n'est **ni affilié, ni approuvé, ni lié** à ces sociétés ou à d'autres ayants droit.
>
> **Ce dépôt ne contient aucune partie du jeu** : ni programme, ni graphismes, ni données, d'origine ou modifiés. Il ne contient que du code et des outils originaux, qui modifient **sur votre ordinateur** une copie du jeu que **vous** fournissez. Vous seul êtes responsable de vous assurer que vous avez le droit d'utiliser cette copie, par exemple en possédant l'original. Seule la version décrite plus bas (MD5 de `SUPER2.DAT`) est acceptée.
>
> Tout est fourni « en l'état », sans aucune garantie. À utiliser à vos risques, y compris sur une vraie machine.

## Utilisation

- **F1** : options. **F2**, **F3**, **F4** : contrôle des voitures bleue, rouge, jaune ; **F5** : voiture **verte**. Le contrôle de la voiture verte s'affiche en bas, sur la ligne « F5 - GREEN CAR ».
- Contrôles possibles : `keyboard`, `none`, `joystick 0`, `joystick 1`, `joystick 2`, `joystick 3`, `joypad a`, `joypad b`.
- La voiture verte est sur `none` au démarrage : elle reste un drone. Donnez-lui un contrôle avec F5, puis appuyez sur l'accélérateur de ce contrôle pendant « PREPARE TO RACE » pour qu'elle rejoigne la course.

| Contrôle | Matériel | Directions | Accélérer |
|---|---|---|---|
| `joystick 2` | adaptateur parallèle, prise « joystick 3 » | D4–D7 | BUSY |
| `joystick 3` | adaptateur parallèle, prise « joystick 4 » | D0–D3 | STROBE |
| `joypad a` / `joypad b` | ports joypad STE, Mega STE, Falcon | croix | bouton A |

L'adaptateur parallèle est celui de *Gauntlet II*, *Leatherneck* ou *Dynabusters+*. Les joypads ne sont lus que si le cookie `_MCH` indique un STE, un Mega STE ou un Falcon.

**Limites actuelles** : la voiture verte n'a pas de score dans l'en-tête (qui n'a que 3 colonnes) ; elle ne peut pas lancer une partie depuis l'écran titre, seulement la rejoindre ; deux voitures sur `none` sont refusées (« can't have two controls the same »). Testé sous Hatari uniquement pour l'instant. Voir [docs/fr/METHODOLOGIE.md](docs/fr/METHODOLOGIE.md) §5.

## Construction

Prérequis : `make`, un compilateur C (pour vasm), `python3`, `curl` ou `git`.

```sh
cd super-sprint
make                                   # code de la 4e voiture : build/p4.bin
make game GAME=/chemin/vers/SSPRINT    # corrige VOTRE copie
make check                             # vérifie le résultat
```

`GAME` est le dossier qui contient `SUPER2.DAT`, `SUPER.DAT`, `SUPER1.DAT`, `INIT.DAT`, `SSPRINT.HSC` (et `SSPRINT.SEQ`). Le résultat, `build/SSPRINT/`, contient `SSPRINT.PRG` et les fichiers de données : copiez ce dossier sur l'Atari et lancez `SSPRINT.PRG`. Le chargeur `AUTO/SUPER.PRG` n'est plus nécessaire.

| Fichier fourni | MD5 |
|---|---|
| `SUPER2.DAT` | `2d828d5478e14b7e7b7bbb820ade4cfd` |

| Résultat | MD5 |
|---|---|
| `SSPRINT.PRG` (défaut) | `f08bf0dd6fa1f176bb13e19258407fc2` |
| `SSPRINT.PRG` avec `P4=0` (disque dur seul) | `c98082d03fdc9f2ba12e6321a8e83188` |

## Étude

- `tools/trace_ss.py` : désassembleur récursif pour ce PRG (relocations, table de sauts, variables a4). `make listing GAME=…` → `work/ss.lst` ; `tools/show.py <début> <fin>` en affiche un extrait. Nécessite `pip install capstone`.
- `tools/patch_ss.py` : applique les correctifs (vérifie le MD5 et chaque octet d'origine), ajoute le code de `src/p4.s` à la fin du TEXT et réécrit la table de relocation.
- `hatari/run.sh` (sans écran) et `hatari/runx.sh` (Xvfb + xdotool, avec joysticks, joypads STE et port parallèle, voir `joy4.cfg`). EmuTOS suffit : aucune ROM Atari n'est nécessaire.
- `docs/fr/` : méthode, constats, carte du code.
