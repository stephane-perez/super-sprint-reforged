; ============================================================================
; p4.s - Super Sprint (Atari ST) : 4e voiture jouable, nouveaux contrôles
; ============================================================================
; Ce code est AJOUTÉ à la fin du segment TEXT de SUPER2.DAT par
; tools/patch_ss.py. Il est assemblé à l'adresse 0 et entièrement relatif au
; PC : le patcheur le place en TEXT+taille_TEXT (le DATA et le BSS sont
; décalés d'autant ; le jeu n'y accède que par a4, voir docs/fr/CODE_MAP.md).
;
; Conventions du jeu (C compilé) :
;   a5 = début du TEXT (constant dans tout le code C)
;   a4 = début du DATA déplacé ; -$xxxx(a4) = BSS, +$xxxx(a4) = DATA
;   d0-d1/a0-a1 sont libres dans une fonction ; a2 doit être préservé
;   (les enveloppes de trap du jeu le sauvent).
;
; Contrôles (valeur de ctl[voiture], mot en -$12CA(a4) + 2*voiture) :
;   0 clavier   1 aucun (« souris » dans l'original, jamais proposée ni lue ;
;     renommée « none » : la voiture reste pilotée par l'ordinateur)
;   2 joystick 0   3 joystick 1
;   4 joystick 2 = adaptateur parallèle, prise « joystick 3 » (D4-D7, BUSY)
;   5 joystick 3 = adaptateur parallèle, prise « joystick 4 » (D0-D3, STROBE)
;   6 joypad A (STE / Falcon)   7 joypad B (STE / Falcon) ; le Mega STE
;     n'a pas de ports joypad : ces contrôles y renvoient 0
; Valeur renvoyée par F_0629c : bits 0-3 = haut/bas/gauche/droite actifs à 1,
; bit 7 = tir (format des paquets joystick de l'IKBD).
;
; ctl[3] (4e voiture, le « drone ») est le mot -$12C4(a4). Dans l'original,
; c'étaient les 2 octets des joysticks IKBD ; le patcheur les déplace dans
; deux cases inutilisées du tableau des touches (codes $74 et $75).
; ============================================================================

CTL         equ     -$12ca          ; ctl[4] (mots), relatif à a4
            ifnd    CTL3_DEF
CTL3_DEF    equ     1               ; contrôle initial de la 4e voiture : aucun
            endif
F_0624A     equ     $624a           ; installation du gestionnaire IKBD
F_0E78C     equ     $e78c           ; « press accelerate to play/continue »
F_0F60C     equ     $f60c           ; idem, écran du choix du circuit
F_0C224     equ     $c224           ; nombre (décompte)
F_0A2E4     equ     $a2e4           ; chiffre « DRONE LAP n » en bas de l'écran
F_0A31C     equ     $a31c           ; restauration du fond sous ce chiffre
F_0814C     equ     $814c           ; son du moteur (voie, vitesse)
F_085DC     equ     $85dc           ; effet sonore (voie)
DRONE3      equ     -$f44           ; drone[3] (drone[i] : -$F4A(a4) + 2*i)
LAPS3       equ     -$f42+6         ; tours de la voiture 3
WRENCH3     equ     -$f72+6         ; clés à molette de la voiture 3
SCORE3      equ     -$12ee+18       ; score de la voiture 3 : 6 chiffres
                                    ; (0-9, négatif = vide)
FONT        equ     -$1e5a          ; petite police du jeu, 8 octets/caractère
                                    ; (5 lignes) : 0-9, '.', '!', A-Z, espace
SCREEN      equ     -$4e            ; écran en cours de dessin
BACKGND     equ     -$56            ; image de fond de la course
XTAB_I      equ     -$21d8          ; x des libellés, indexé par voiture
XTAB_K      equ     -$21dc          ; même table, indexée par touche F2..F4
NAMES       equ     -$21ca          ; 4 pointeurs vers les noms des contrôles
F_0A546     equ     $a546           ; décompression d'une image
F_0C4F8     equ     $c4f8           ; grand titre (écran, texte, couleur, x, y)
F_0AFCE     equ     $afce           ; image n (blocs 8x8) dans un tampon
PIC3CARS    equ     -$66            ; image compressée « 3 voitures » (options,
                                    ; prepare to race, initiales)
PALS        equ     -$16de          ; palettes du raster de ces écrans
TSPAL       equ     -$179e          ; palettes du raster du choix du circuit ;
                                    ; bande 0 (textes du haut) : couleurs 1-3 =
                                    ; bleu, rouge, jaune, 4 = $567 (gris), ne
                                    ; sert qu'à la 4e colonne
; Le patcheur agrandit le BSS de BSSX octets : ils apparaissent sous le BSS
; d'origine, en P4B(a4). On y range les tables par voiture à 4 cases.
BSSX        equ     256             ; utilisés : 80 + 48 + 40
P4B         equ     -$2b74-BSSX
NPOS        equ     10              ; tables de positions (x ou y), 4 mots
DRONES      equ     -$f4a           ; drone[4]
PODCOL      equ     -$167e          ; podium : 3 couleurs par entrée, 7 entrées
                                    ; (0-2 humains, 3 verte drone, 4-6 drones)
PODCOL8     equ     P4B+NPOS*8      ; notre copie à 8 entrées (3 = verte
                                    ; humaine, 7 = verte drone)
GREEN1      equ     $070            ; verts de la 4e voiture (palette P2,
GREEN2      equ     $041            ; couleurs 1 et 2, libres dans cette bande)

            org     0

; ---- table d'entrée : le patcheur vise ces adresses (base + 4*n) ----------
            bra.w   ext629c         ; +0  : F_0629c, contrôles 1 et >= 4
            bra.w   init            ; +4  : entrée $24 de la table de sauts
            bra.w   names           ; +8  : pointeur vers le nom d'un contrôle
            bra.w   xpos_i          ; +12 : x, y du libellé (par voiture)
            bra.w   xpos_k          ; +16 : x, y du libellé (touche F2..F5)
            bra.w   hud4            ; +20 : entrée $132 de la table de sauts
            bra.w   dec4            ; +24 : entrée $18c (F_0A546)
            bra.w   titles          ; +28 : titres de l'écran des options
            bra.w   alldrone        ; +32 : fin de partie (F_0975A)
            bra.w   prepchk         ; +36 : fin de « prepare to race »
            bra.w   inichk          ; +40 : fin de la saisie des initiales
            bra.w   col4a           ; +44 : F_0E78C (colonne d'un drone)
            bra.w   col4b           ; +48 : F_0F60C (idem, choix du circuit)
            bra.w   col4c           ; +52 : F_0C224 (décompte d'un drone)
            bra.w   rst4            ; +56 : entrée $180 (F_0A31C)
            bra.w   vmap            ; +60 : voie du son d'une voiture
            bra.w   eng4            ; +64 : entrée $156 (F_0814C, moteur)
            bra.w   snd4            ; +68 : entrée $126 (F_085DC)
            bra.w   title5          ; +72 : entrée $24C (F_0AFCE, images)

; ----------------------------------------------------------------------------
; init : remplace l'appel de F_0624A au démarrage (jsr $24(a5)).
; Met la 4e voiture sur son contrôle par défaut, teste la présence des
; ports joypad (cookie _MCH = STE ou Falcon), puis continue vers F_0624A.
; ----------------------------------------------------------------------------
init        move.w  #CTL3_DEF,CTL+6(a4)
            lea     HUDST(a4),a0    ; ligne du bas de la verte : rien dessiné
            moveq   #2*HUDSZ/4-1,d0
.hst        clr.l   (a0)+
            dbra    d0,.hst
            lea     postab(pc),a0   ; tables de positions à 4 voitures
            lea     P4B(a4),a1
            moveq   #NPOS*4-1,d0
.pos        move.w  (a0)+,(a1)+
            dbra    d0,.pos
            lea     PODCOL(a4),a0   ; couleurs du podium (lues dans INIT.DAT)
            lea     PODCOL8(a4),a1
            moveq   #7*3-1,d0
.pc         move.w  (a0)+,(a1)+
            dbra    d0,.pc
            lea     PODCOL8(a4),a0
            move.l  3*6(a0),7*6(a0)         ; 7 = verte drone (ancienne 3)
            move.w  3*6+4(a0),7*6+4(a0)
            move.l  #$05730040,3*6(a0)      ; 3 = verte humaine :
            move.w  #$0070,3*6+4(a0)        ; clair, foncé, principal
            move.w  #GREEN1,TSPAL+8(a4)     ; choix du circuit : texte vert
            movem.l d1-d2/a0-a2,-(a7)
            pea     chkmch(pc)
            move.w  #38,-(a7)       ; Supexec
            trap    #14
            addq.l  #6,a7
            movem.l (a7)+,d1-d2/a0-a2
            move.l  a5,a0
            adda.l  #F_0624A,a0
            jmp     (a0)

chkmch      move.l  $5a0.w,d0       ; _p_cookies
            beq.s   .no
            move.l  d0,a0
.loop       move.l  (a0)+,d0
            beq.s   .no
            move.l  (a0)+,d1
            cmpi.l  #'_MCH',d0
            bne.s   .loop
            cmpi.l  #$00010010,d1   ; Mega STE : pas de ports joypad,
            beq.s   .no             ; seulement l'adaptateur parallèle
            swap    d1              ; 1 = STE (toutes variantes), 3 = Falcon
            cmpi.w  #1,d1
            beq.s   .yes
            cmpi.w  #3,d1
            bne.s   .no
.yes        lea     haspad(pc),a0
            st      (a0)
.no         rts

; ----------------------------------------------------------------------------
; ext629c : remplace, dans F_0629c, la branche « contrôle inconnu »
; (move.w #0,d0 / bra fin). d0.w = numéro du contrôle. On est dans le cadre
; de F_0629c : on termine par unlk a6 / rts.
; ----------------------------------------------------------------------------
ext629c     cmpi.w  #4,d0
            blt.s   .zero
            cmpi.w  #7,d0
            bgt.s   .zero
            movem.l d1-d2/a0-a2,-(a7)
            lea     reqctl(pc),a0
            move.w  d0,(a0)
            pea     readext(pc)     ; les ports ne sont lisibles qu'en
            move.w  #38,-(a7)       ; superviseur : Supexec
            trap    #14
            addq.l  #6,a7
            movem.l (a7)+,d1-d2/a0-a2
            moveq   #0,d0
            move.b  extval(pc),d0
            unlk    a6
            rts
.zero       moveq   #0,d0
            unlk    a6
            rts

; readext (superviseur) : lit le contrôle reqctl, résultat dans extval.
readext     moveq   #0,d0
            move.w  reqctl(pc),d1
            cmpi.w  #6,d1
            bge.s   .pad
            ; --- adaptateur parallèle (méthode d'IK+ Reforged, src/p3.s) ---
            move.w  sr,-(a7)
            ori.w   #$0700,sr
            move.b  #7,$ffff8800.w  ; port B du PSG en entrée (bit 7 = 0)
            move.b  $ffff8800.w,d2
            bclr    #7,d2
            move.b  d2,$ffff8802.w
            cmpi.w  #5,d1
            beq.s   .j4
            move.b  #15,$ffff8800.w ; prise « joystick 3 » : D4-D7 + BUSY
            move.b  $ffff8800.w,d0
            move.b  $fffffa01.w,d2  ; GPIP bit 0 = BUSY, 0 = appuyé
            move.w  (a7)+,sr
            lsr.b   #4,d0
            btst    #0,d2
            bra.s   .par
.j4         move.b  #14,$ffff8800.w ; prise « joystick 4 » : D0-D3 + STROBE
            move.b  $ffff8800.w,d2  ; (lu deux fois : voir src/p3.s d'IK+)
            move.b  #14,$ffff8800.w
            move.b  $ffff8800.w,d2  ; bit 5 = STROBE, 0 = appuyé
            move.b  d2,d1
            bset    #5,d1           ; STROBE remis à 1
            move.b  d1,$ffff8802.w
            move.b  #15,$ffff8800.w
            move.b  $ffff8800.w,d0
            move.w  (a7)+,sr
            btst    #5,d2
.par        seq     d1              ; d1 = $FF si tir appuyé
            not.b   d0              ; directions actives à 1
            andi.b  #$0f,d0
            andi.b  #$80,d1
            or.b    d1,d0
            bra.s   .done
            ; --- joypads STE : $FF9202 = sélection de ligne (écriture :
            ; bits 0-3 pad A, 4-7 pad B, ligne choisie à 0) et directions
            ; (lecture, ligne 0 : bits 8-11 pad A, 12-15 pad B, actifs à 0) ;
            ; $FF9200 = bouton de la ligne choisie (bit 1 pad A, bit 3 pad B,
            ; actif à 0) : A en ligne 0, B en ligne 1, C en ligne 2. Le tir
            ; est l'un des trois.
.pad        move.b  haspad(pc),d2
            beq.s   .done
            moveq   #1,d2           ; pad A : bouton en bit 1, lignes en
            cmpi.w  #7,d1           ; bits 0-3 (d1 = contrôle demandé)
            seq     d1
            andi.w  #4,d1
            beq.s   .pa
            moveq   #3,d2           ; pad B : bit 3, lignes en bits 4-7
.pa         move.w  #$fffe,d0
            rol.w   d1,d0           ; ligne 0
            move.w  d0,$ffff9202.w
            move.w  $ffff9202.w,d0  ; directions
            lsr.w   #8,d0
            lsr.w   d1,d0
            not.b   d0
            andi.b  #$0f,d0
            movem.l d3-d4,-(a7)
            moveq   #2,d4           ; lignes 0, 1, 2 : boutons A, B, C
            move.w  #$fffe,d3
            rol.w   d1,d3
.btn        move.w  d3,$ffff9202.w
            move.w  $ffff9200.w,d1
            btst    d2,d1
            bne.s   .nb
            bset    #7,d0           ; appuyé
.nb         rol.w   #1,d3
            dbra    d4,.btn
            movem.l (a7)+,d3-d4
            move.w  #$ffff,$ffff9202.w
.done       lea     extval(pc),a0
            move.b  d0,(a0)
            rts

; ----------------------------------------------------------------------------
; names : remplace « lea NAMES(a4),a0 / adda.w d0,a0 » (d0 = 4*contrôle).
; Renvoie dans a0 l'adresse d'un pointeur vers le nom du contrôle ; l'appelant
; fait ensuite move.l (a0),-(a7).
; ----------------------------------------------------------------------------
names       cmpi.w  #16,d0
            bge.s   .ext
            lea     NAMES(a4),a0
            adda.w  d0,a0
            rts
.ext        lsr.w   #1,d0           ; 4*contrôle -> 2*contrôle
            lea     nametab-8(pc),a0
            adda.w  d0,a0
            move.w  (a0),d0         ; décalage relatif à nametab
            lea     nametab(pc),a0
            adda.w  d0,a0
            lea     nameptr(pc),a1
            move.l  a0,(a1)
            move.l  a1,a0
            rts

; ----------------------------------------------------------------------------
; xpos_i / xpos_k : remplacent « lea XTAB(a4),a0 / adda.w d0,a0 » avant
; « move.w (a0),-(a7) » (x du libellé du contrôle). d0 = 2*voiture (xpos_i)
; ou 2*touche (xpos_k, touche = voiture + 2). Les positions viennent de
; labxy ; le y, déjà empilé par l'appelant, est corrigé en 4(a7).
; ----------------------------------------------------------------------------
xpos_k      subq.w  #4,d0
xpos_i      lea     labxy(pc),a0
            add.w   d0,d0
            adda.w  d0,a0
            move.w  2(a0),4(a7)
            rts

; ----------------------------------------------------------------------------
; titles : remplace, dans F_0E850 (écran des options), les 6 appels de
; F_0C4F8 qui écrivent « BLUE / CAR », « RED / CAR », « YELLOW / CAR ».
; Nouvelle disposition : 4 colonnes en haut (bleue, rouge, jaune, verte),
; comme les écrans « prepare to race » et choix du circuit.
; a6 = cadre de F_0E850, écran en 8(a6).
; ----------------------------------------------------------------------------
titles      move.l  a2,-(a7)        ; F_0C462 modifie d0-d7 : compteur
            lea     titab(pc),a2    ; = adresse de fin de la table
.t          move.w  6(a2),-(a7)     ; y
            move.w  4(a2),-(a7)     ; x
            move.w  2(a2),-(a7)     ; couleur
            lea     titab(pc),a0
            adda.w  (a2),a0
            move.l  a0,-(a7)        ; texte
            move.l  8(a6),-(a7)     ; écran
            move.l  a5,a0
            adda.l  #F_0C4F8,a0
            jsr     (a0)
            lea     14(a7),a7
            addq.w  #8,a2
            lea     titend(pc),a0
            cmpa.l  a0,a2
            bne.s   .t
            movea.l (a7)+,a2
            rts

; ----------------------------------------------------------------------------
; dec4 : remplace F_0A546 (entrée $18c) : décompression d'une image
; (source 4(a7), destination 8(a7)). Pour l'image « 3 voitures », on la
; retouche (pic4) et on adapte le raster de ces écrans :
; - palette P2 (voitures du bas, à partir de la ligne 112) : couleurs 1 et 2
;   (jaunes, inutilisées dans cette bande) -> verts ;
; - palette P0 (titres du haut) : couleur 4 -> vert (4e colonne).
; ----------------------------------------------------------------------------
dec4        move.l  4(a7),d0
            cmp.l   PIC3CARS(a4),d0
            beq.s   .ours
            move.l  a5,a0
            adda.l  #F_0A546,a0
            jmp     (a0)
.ours       move.l  8(a7),-(a7)
            move.l  8(a7),-(a7)
            move.l  a5,a0
            adda.l  #F_0A546,a0
            jsr     (a0)
            addq.l  #8,a7
            movea.l 8(a7),a0
            movem.l d2-d7/a2-a3,-(a7)
            bsr.s   pic4
            movem.l (a7)+,d2-d7/a2-a3
            move.w  #GREEN1,PALS+8(a4)      ; P0[4] : textes de la 4e colonne
            move.w  #GREEN1,PALS+$40+2(a4)
            move.w  #GREEN2,PALS+$40+4(a4)
            rts

; ----------------------------------------------------------------------------
; Écran titre : « AI WORK BY CLAUDE » au-dessus de « (c) 1986 ATARI GAMES »
; (lignes 193-197, couleur 5, fin en x = 300), dans la même petite police.
; L'image du titre est l'image n° 8 de F_0AFCE(n, tampon) (entrée $24C), qui
; la reconstitue par blocs de 8x8 dans le tampon avant chaque affichage.
; ----------------------------------------------------------------------------
AIX         equ     199
AIY         equ     185
title5      move.l  6(a7),-(a7)     ; F_0AFCE(n, tampon)
            move.w  8(a7),-(a7)
            move.l  a5,a0
            adda.l  #F_0AFCE,a0
            jsr     (a0)
            addq.l  #6,a7
            cmpi.w  #8,4(a7)
            bne.s   .no
            movem.l d0-d7/a0-a3,-(a7)
            movea.l 6+48(a7),a1
            bsr.s   aitext
            movem.l (a7)+,d0-d7/a0-a3
.no         rts

aitext      lea     AIY*160(a1),a1
            lea     FONT(a4),a3
            move.w  #AIX,d2
            moveq   #5,d7
            lea     txtai(pc),a2
            bra     puts

; pic4 : image « 3 voitures » en a0 (320x200, 4 plans). La rouge (lignes
; 126-167, blocs de 16 pixels 5 à 14) est déplacée de 5 blocs à gauche (sous
; la bleue) ; une copie recolorée est posée 5 blocs à droite (sous la
; jaune). Recoloration par plans, sans orange (9 et 10 sont partagées avec
; la rouge dans la même bande du raster) : 4, 6, 10 -> 1 ; 3, 5, 9 -> 2.
;   M1 = ~p0 & (p2 ^ p3) & (~p3 | p1)                  (couleurs 4, 6, 10)
;   M2 = p0 & (p1 ^ p2 ^ p3) & ~(p1 & p2 & p3)         (couleurs 3, 5, 9)
pic4        lea     126*160(a0),a2
            moveq   #41,d7          ; 42 lignes
.row        lea     -80(a7),a7      ; une ligne de 10 blocs
            movea.l a7,a3
            lea     5*8(a2),a1
            moveq   #19,d6
.cp         move.l  (a1),(a3)+      ; copie et efface l'original
            clr.l   (a1)+
            dbra    d6,.cp
            movea.l a7,a3           ; rouge : blocs 0 à 9
            movea.l a2,a1
            moveq   #19,d6
.red        move.l  (a3)+,(a1)+
            dbra    d6,.red
            movea.l a7,a3           ; verte : blocs 10 à 19
            lea     10*8(a2),a1
            lea     10.w,a0
.grn        movem.w (a3)+,d0-d3
            move.w  d2,d4
            eor.w   d3,d4           ; p2 ^ p3
            move.w  d3,d5
            not.w   d5
            or.w    d1,d5           ; ~p3 | p1
            and.w   d5,d4
            move.w  d0,d5
            not.w   d5
            and.w   d5,d4           ; M1
            move.w  d1,d5
            eor.w   d2,d5
            eor.w   d3,d5           ; p1 ^ p2 ^ p3
            move.w  d1,d6
            and.w   d2,d6
            and.w   d3,d6
            not.w   d6              ; ~(p1 & p2 & p3)
            and.w   d6,d5
            and.w   d0,d5           ; M2
            move.w  d4,d6
            or.w    d5,d6
            not.w   d6              ; ~(M1|M2)
            and.w   d6,d0
            or.w    d4,d0
            and.w   d6,d1
            or.w    d5,d1
            and.w   d6,d2
            and.w   d6,d3
            movem.w d0-d3,(a1)
            addq.l  #8,a1
            subq.w  #1,a0
            cmpa.w  #0,a0
            bne.s   .grn
            lea     80(a7),a7
            lea     160(a2),a2
            dbra    d7,.row
            rts


; ----------------------------------------------------------------------------
; alldrone : fin de partie quand les 4 voitures sont des drones (F_0975A,
; $97EC, ne testait que les 3 premières). Résultat dans d0.
; ----------------------------------------------------------------------------
alldrone    move.w  DRONES(a4),d0
            and.w   DRONES+2(a4),d0
            and.w   DRONES+4(a4),d0
            and.w   DRONES+6(a4),d0
            rts

; ----------------------------------------------------------------------------
; prepchk : fin de la boucle de « prepare to race » (F_0DD20, $E348).
; Cadre de F_0DD20 (a6) : animation en cours par voiture en -$2C(a6)
; (4 mots, déplacé par le patcheur), décompte en -4(a6).
; d0 = 1 : on continue ; 0 : on sort. Comme l'original : on continue tant
; qu'une animation tourne, tant que le décompte est > $FA, puis tant qu'il
; est > 0 et qu'un drone peut encore rejoindre. La voiture 4 n'est prise en
; compte que si elle a un contrôle (sinon elle est toujours drone et le
; décompte ne s'arrêterait jamais plus tôt, même avec 3 joueurs).
; ----------------------------------------------------------------------------
prepchk     lea     -$2c(a6),a0
            moveq   #3,d1
.anim       cmpi.w  #1,(a0)+
            beq.s   .yes
            dbra    d1,.anim
            move.w  -4(a6),d0
            ble.s   .no
            cmpi.w  #$fa,d0
            bgt.s   .yes
            lea     DRONES(a4),a0
            moveq   #2,d1
            cmpi.w  #1,CTL+6(a4)    ; voiture 4 sans contrôle : ignorée
            beq.s   .dr
            moveq   #3,d1
.dr         cmpi.w  #1,(a0)+
            beq.s   .yes
            dbra    d1,.dr
.no         moveq   #0,d0
            rts
.yes        moveq   #1,d0
            rts


; ----------------------------------------------------------------------------
; inichk : fin de la saisie des initiales (F_0CFEC, $D672). L'état par
; voiture est en -$3C(a6) (4 mots, déplacé par le patcheur) ; on continue
; (d0 = 1) tant qu'une voiture est encore en saisie (état 1).
; ----------------------------------------------------------------------------
inichk      lea     -$3c(a6),a0
            moveq   #3,d1
.l          cmpi.w  #1,(a0)+
            beq.s   .yes
            dbra    d1,.l
            moveq   #0,d0
            rts
.yes        moveq   #1,d0
            rts


; ----------------------------------------------------------------------------
; col4a / col4b / col4c : les écrans à 4 colonnes invitent chaque drone à
; rejoindre la course. Si la voiture 4 n'a pas de contrôle (« none »), sa
; colonne reste vide, comme dans le jeu d'origine à 3 colonnes.
;   col4a remplace « jsr F_0E78C(pc) » en $DE0C  : pile écran, i, i+1
;   col4b remplace « jsr F_0F60C(pc) » en $EFB0  : pile écran, x, i+1
;   col4c remplace « jsr F_0C224(pc) » en $E308  : pile écran, n, x, y, c, i+1
; ----------------------------------------------------------------------------
col4a       cmpi.w  #3,8(a7)
            bne.s   .go
            cmpi.w  #1,CTL+6(a4)
            beq.s   col4r
.go         move.l  a5,a0
            adda.l  #F_0E78C,a0
            jmp     (a0)
col4b       cmpi.w  #4,10(a7)
            bne.s   .go
            cmpi.w  #1,CTL+6(a4)
            beq.s   col4r
.go         move.l  a5,a0
            adda.l  #F_0F60C,a0
            jmp     (a0)
col4c       cmpi.w  #4,16(a7)
            bne.s   .go
            cmpi.w  #1,CTL+6(a4)
            beq.s   col4r
.go         move.l  a5,a0
            adda.l  #F_0C224,a0
            jmp     (a0)
col4r       rts

; ----------------------------------------------------------------------------
; hud4 : remplace F_0A2E4 (entrée $132 de la table de sauts), appelée à
; chaque image de la course pour écrire le tour du drone dans « DRONE LAP n »
; en bas de l'écran (ligne 194, en noir sur la bande du bas).
; Si la voiture verte est pilotée par un humain, on remplace toute cette
; zone par « GREEN CAR », ses clés à molette, son tour et son score.
; Bande effacée : lignes 193-199, x = 96-271 (les arbres de certains
; circuits commencent vers x = 280), avec la couleur du fond de la course
; relevée en (96, 199).
; Tout redessiner à chaque image coûtait environ 30000 cycles et faisait
; passer la course de 50 à 25 images/s. On garde donc, pour chacun des deux
; écrans (double tampon), ce qui y est déjà dessiné : adresse de l'écran,
; témoin (8 octets du « G » de GREEN, relus après dessin) et les 8 chiffres
; affichés. Si l'écran est connu et le témoin intact, on ne redessine que
; les chiffres qui ont changé ; sinon (début de course, écran repeint), tout.
; ----------------------------------------------------------------------------
HUDX        equ     96
HUDY        equ     194
HUDST       equ     P4B+128         ; 2 x 20 octets : écran.l, témoin (8),
HUDSZ       equ     20              ; chiffres affichés (8)
HUDWIT      equ     160+(HUDX+4)/16*8       ; relatif à la ligne HUDY
SHOWN       equ     -$52            ; écran affiché (l'autre tampon)

hud4        bsr     g4human
            bne.s   .human
            move.l  a5,a0
            adda.l  #F_0A2E4,a0
            jmp     (a0)
.human      movem.l d2-d7/a2-a3,-(a7)
            movea.l SCREEN(a4),a1
            lea     HUDY*160(a1),a1 ; a1 = ligne du texte
            lea     FONT(a4),a3
            ; chiffres à afficher (indices de la police) : clés, tour, score
            subq.l  #8,a7
            movea.l a7,a0
            move.w  WRENCH3(a4),d0
            bsr     clamp9
            move.w  LAPS3(a4),d0
            bsr     clamp9
            lea     SCORE3(a4),a2
            moveq   #5,d1
.cs         move.b  (a2)+,d0
            bpl.s   .cs1
            moveq   #38,d0          ; vide : espace
.cs1        move.b  d0,(a0)+
            dbra    d1,.cs
            ; entrée de cet écran
            lea     HUDST(a4),a2
            cmpa.l  (a2),a1
            beq.s   .known
            lea     HUDSZ(a2),a2
            cmpa.l  (a2),a1
            beq.s   .known
            lea     HUDST(a4),a2    ; nouvel écran : on remplace l'entrée
            move.l  SHOWN(a4),d0    ; qui n'est pas celle de l'écran affiché
            addi.l  #HUDY*160,d0    ; (les entrées gardent la ligne HUDY)
            cmp.l   (a2),d0
            bne.s   .full
            lea     HUDSZ(a2),a2
            bra.s   .full
.known      move.l  HUDWIT(a1),d0
            cmp.l   4(a2),d0
            bne.s   .full
            move.l  HUDWIT+4(a1),d0
            cmp.l   8(a2),d0
            beq.w   .digits
.full       move.l  a1,(a2)
            moveq   #-1,d0          ; aucun chiffre affiché
            move.l  d0,12(a2)
            move.l  d0,16(a2)
            move.l  a2,d6
            bsr     bgcol
            ; mots des 4 plans pour la couleur de fond d3
            moveq   #0,d4
            moveq   #0,d5
            btst    #0,d3
            beq.s   .p1
            move.l  #$ffff0000,d4
.p1         btst    #1,d3
            beq.s   .p2
            move.w  #$ffff,d4
.p2         btst    #2,d3
            beq.s   .p3
            move.l  #$ffff0000,d5
.p3         btst    #3,d3
            beq.s   .fill
            move.w  #$ffff,d5
.fill       lea     (193-HUDY)*160+HUDX/2(a1),a2
            moveq   #6,d1           ; 7 lignes
.frow       movea.l a2,a0
            moveq   #10,d0          ; 11 blocs de 16 pixels
.fblk       move.l  d4,(a0)+
            move.l  d5,(a0)+
            dbra    d0,.fblk
            lea     160(a2),a2
            dbra    d1,.frow
            ; textes fixes
            move.w  #HUDX+4,d2
            moveq   #15,d7          ; blanc
            lea     txtgreen(pc),a2
            bsr     puts
            moveq   #0,d7           ; noir
            move.w  #HUDX+70,d2
            lea     gwrench(pc),a0
            bsr     putc
            move.w  #HUDX+90,d2
            lea     txtlap(pc),a2
            bsr     puts
            movea.l d6,a2
            move.l  HUDWIT(a1),4(a2)        ; témoin
            move.l  HUDWIT+4(a1),8(a2)
.digits     bsr     bgcol
            move.w  d3,d7           ; d7 = fond << 16 | encre (noir)
            swap    d7
            clr.w   d7
            moveq   #0,d6
.dl         move.b  (a7,d6.w),d0
            cmp.b   12(a2,d6.w),d0
            beq.s   .dn
            move.b  d0,12(a2,d6.w)
            ext.w   d0
            move.w  d6,d1
            add.w   d1,d1
            move.w  digx(pc,d1.w),d2
            lsl.w   #3,d0
            lea     (a3,d0.w),a0
            bsr     putcell
.dn         addq.w  #1,d6
            cmpi.w  #8,d6
            bne.s   .dl
            addq.l  #8,a7
            movem.l (a7)+,d2-d7/a2-a3
            rts
; x des 8 chiffres : clés, tour, score (6)
digx        dc.w    HUDX+80,HUDX+114
            dc.w    HUDX+134,HUDX+140,HUDX+146,HUDX+152,HUDX+158,HUDX+164

clamp9      cmpi.w  #9,d0
            bls.s   .ok
            moveq   #9,d0
.ok         move.b  d0,(a0)+
            rts

; g4human : Z = 0 si la voiture verte est pilotée par un humain
g4human     tst.w   DRONE3(a4)
            bne.s   .no
            cmpi.w  #1,CTL+6(a4)    ; pas de contrôle (démo...)
            beq.s   .no
            moveq   #1,d0
            rts
.no         moveq   #0,d0
            rts

; rst4 : remplace F_0A31C (entrée $180), qui recopie à chaque image le bloc
; du chiffre de « DRONE LAP n » depuis le fond ; il effacerait notre ligne.
rst4        bsr.s   g4human
            bne.s   .no
            move.l  a5,a0
            adda.l  #F_0A31C,a0
            jmp     (a0)
.no         rts

; ----------------------------------------------------------------------------
; Son : le pilote du jeu a 3 voies (une par voiture humaine : le moteur ;
; les effets sonores des drones passent par voiture % 3). Pour la verte
; (voiture 3), on prend la voie d'une des 3 premières voitures pilotée par
; l'ordinateur, qui n'a pas de son de moteur ; s'il n'y en a pas (4
; humains), la voie 0 pour les effets et la voie de la jaune, une image sur
; deux, pour le moteur.
; vmap : d0.w = voiture -> d0.w = voie (0-2). Remplace « ext.l d0 /
; divs #3,d0 / swap d0 » devant les appels d'effets sonores.
; ----------------------------------------------------------------------------
vmap        bsr.s   vfree
            bpl.s   .ok
            moveq   #0,d0
.ok         rts

; vfree : d0.w = voiture -> d0.w = voie, ou -1 (N = 1) si aucune voie libre
vfree       cmpi.w  #3,d0
            blo.s   .own
            move.l  a0,-(a7)
            lea     DRONES(a4),a0
            moveq   #0,d0
.l          tst.w   (a0)+
            bne.s   .fnd
            addq.w  #1,d0
            cmpi.w  #3,d0
            blo.s   .l
            moveq   #-1,d0
.fnd        movea.l (a7)+,a0
            tst.w   d0
            rts
.own        tst.w   d0
            rts

; eng4 : entrée $156, F_0814C(voiture, vitesse), appelée à chaque image pour
; chaque voiture humaine. À 4 humains, la verte partage la voie de la jaune
; (SHAREV) : une image sur deux chacune (le YM ne mélange pas deux sons sur
; une voie ; l'alternance à 25 Hz fait entendre les deux moteurs).
SHAREV      equ     2
FRAMES      equ     -$1f88          ; compteur d'images (échanges d'écran)
eng4        move.w  4(a7),d0
            cmpi.w  #3,d0
            beq.s   .green
            cmpi.w  #SHAREV,d0
            bne.s   .call
            moveq   #3,d0           ; la verte est-elle humaine sans voie
            bsr.s   vfree           ; libre ?
            bpl.s   .call
            bsr     g4human
            beq.s   .call
            btst    #0,FRAMES+1(a4) ; images impaires : la verte
            bne.s   .no
            bra.s   .call
.green      bsr.s   vfree
            bpl.s   .set
            btst    #0,FRAMES+1(a4)
            beq.s   .no
            moveq   #SHAREV,d0
.set        move.w  d0,4(a7)
.call       move.l  a5,a0
            adda.l  #F_0814C,a0
            jmp     (a0)
.no         rts

; snd4 : entrée $126, F_085DC(voiture)
snd4        move.w  4(a7),d0
            bsr.s   vmap
            move.w  d0,4(a7)
            move.l  a5,a0
            adda.l  #F_085DC,a0
            jmp     (a0)

; bgcol : d3 = couleur du fond de la course en (96, 199)
bgcol       movea.l BACKGND(a4),a0
            lea     199*160+HUDX/2+8(a0),a0
            moveq   #0,d3
            moveq   #3,d1
.col        move.w  -(a0),d0        ; plans 3, 2, 1, 0
            add.w   d0,d0           ; bit 15 -> X
            addx.w  d3,d3
            dbra    d1,.col
            rts

; puts : chaîne a2 (indices de la police, -1 = fin) en x = d2, couleur d7
puts        moveq   #0,d0
            move.b  (a2)+,d0
            bmi.s   .end
            lsl.w   #3,d0
            lea     (a3,d0.w),a0
            bsr.s   putc
            bra.s   puts
.end        rts

; putdig : chiffre d0 (0-9) en x = d2, couleur d7
putdig      lsl.w   #3,d0
            lea     (a3,d0.w),a0
; putc : glyphe a0 (5 lignes, 5 pixels à gauche de l'octet) en x = d2,
; couleur d7, sur la ligne d'écran a1 (5 lignes). Avance x de 6.
putc        movem.l d2-d5/a2-a3,-(a7)
            movea.l a0,a3           ; glyphe
            move.w  d2,d3
            lsr.w   #4,d3
            lsl.w   #3,d3
            movea.l a1,a2           ; ligne du texte
            adda.w  d3,a2
            andi.w  #15,d2
            moveq   #4,d5
.row        moveq   #0,d3
            move.b  (a3)+,d3
            ror.l   #8,d3           ; octet -> bits 31-24
            lsr.l   d2,d3           ; masque sur 2 blocs de 16 pixels
            move.l  d3,d4
            not.l   d4
            movea.l a2,a0
            moveq   #0,d1
.plane      btst    d1,d7
            beq.s   .clr
            or.w    d3,8(a0)
            swap    d3
            or.w    d3,(a0)+
            swap    d3
            bra.s   .nxt
.clr        and.w   d4,8(a0)
            swap    d4
            and.w   d4,(a0)+
            swap    d4
.nxt        addq.w  #1,d1
            cmpi.w  #4,d1
            blt.s   .plane
            lea     160(a2),a2
            dbra    d5,.row
            movem.l (a7)+,d2-d5/a2-a3
            addq.w  #6,d2
            rts

; putcell : glyphe a0 dans une case de 6 pixels en x = d2, sur la ligne
; d'écran a1 : pixels du glyphe en couleur d7.w, reste de la case en couleur
; (d7 >> 16) ; remplace donc l'ancien caractère. Avance x de 6.
putcell     movem.l d2-d6/a2-a3,-(a7)
            movea.l a0,a3
            move.w  d2,d3
            lsr.w   #4,d3
            lsl.w   #3,d3
            movea.l a1,a2           ; ligne du texte
            adda.w  d3,a2
            andi.w  #15,d2
            moveq   #4,d5
.row        moveq   #0,d3
            move.b  (a3)+,d3
            ror.l   #8,d3
            lsr.l   d2,d3           ; glyphe g
            move.l  #$fc000000,d4
            lsr.l   d2,d4           ; case c
            movea.l a2,a0
            moveq   #0,d1
.plane      moveq   #0,d6
            btst    d1,d7
            beq.s   .nofg
            move.l  d3,d6           ; encre : g
.nofg       move.w  d1,d0
            addi.w  #16,d0
            btst    d0,d7
            beq.s   .nobg
            move.l  d4,d0
            eor.l   d3,d0           ; fond : c & ~g
            or.l    d0,d6
.nobg       move.l  d4,d0
            not.l   d0
            swap    d0
            swap    d6
            and.w   d0,(a0)
            or.w    d6,(a0)
            swap    d0
            swap    d6
            and.w   d0,8(a0)
            or.w    d6,8(a0)
            addq.l  #2,a0
            addq.w  #1,d1
            cmpi.w  #4,d1
            blt.s   .plane
            lea     160(a2),a2
            dbra    d5,.row
            movem.l (a7)+,d2-d6/a2-a3
            addq.w  #6,d2
            rts

; ---- données ---------------------------------------------------------------
; positions (x ou y) par voiture des animations dessinées sur l'image des
; voitures ; dans l'original, 3 cases chacune, en -$2184 ... -$21BA(a4).
; Rouge : x - 80 (sous la bleue) ; verte : x + 80 depuis l'ancienne rouge.
postab      dc.w    $26,$26,$c5,$c6         ; -$2184 : x (initiales)
            dc.w    $49,$8e,$49,$8e         ; -$218A : y
            dc.w    $26,$26,$c5,$c6         ; -$2190 : x (prepare to race)
            dc.w    $49,$8e,$49,$8e         ; -$2196 : y
            dc.w    $1a,$1a,$b9,$ba         ; -$219C : x
            dc.w    $3c,$81,$3c,$81         ; -$21A2 : y
            dc.w    $58,$58,$f9,$f8         ; -$21A8 : x
            dc.w    $3f,$84,$3f,$84         ; -$21AE : y
            dc.w    $26,$26,$c5,$c6         ; -$21B4 : x (options)
            dc.w    $49,$8e,$49,$8e         ; -$21BA : y
; libellés des contrôles (x, y), voitures 0 à 3 (bleue, rouge, jaune, verte) :
; 4 colonnes de 80 pixels comme « prepare to race » (centres 44, 124, 204,
; 284), 10 caractères de 6 pixels
labxy       dc.w    14,$22, 94,$22, 174,$22, 254,$22
; grands titres (11 pixels par caractère) : texte (décalage depuis titab),
; couleur (palette P0 : 1 bleu, 2 rouge, 3 jaune, 4 vert), x, y
titab       dc.w    tblue-titab,1,22,5
            dc.w    tcar-titab,1,28,$13
            dc.w    tred-titab,2,108,5
            dc.w    tcar-titab,2,108,$13
            dc.w    tyellow-titab,3,171,5
            dc.w    tcar-titab,3,188,$13
            dc.w    tgreen-titab,4,257,5
            dc.w    tcar-titab,4,268,$13
titend
tblue       dc.b    'blue',0
tred        dc.b    'red',0
tyellow     dc.b    'yellow',0
tgreen      dc.b    'green',0
tcar        dc.b    'car',0
            even
reqctl      dc.w    0
nameptr     dc.l    0
extval      dc.b    0
haspad      dc.b    0
            even
nametab     dc.w    n4-nametab,n5-nametab,n6-nametab,n7-nametab
; 10 caractères, comme les noms d'origine (« joystick 0 »)
n4          dc.b    'joystick 2',0
n5          dc.b    'joystick 3',0
n6          dc.b    ' joypad a ',0
n7          dc.b    ' joypad b ',0
            even
; textes de hud4, en indices de la petite police (A = 12)
txtgreen    dc.b    18,29,16,16,25,38,14,12,29,-1   ; GREEN CAR
txtlap      dc.b    23,12,27,38,-1                  ; LAP
txtai       dc.b    12,20,38,34,26,29,22,38,13,36,38,14,23,12,32,15,16,-1
                                                ; AI WORK BY CLAUDE
gwrench     dc.b    %10100000                       ; clé à molette
            dc.b    %11100000                       ; (8 pixels de large)
            dc.b    %01111111
            dc.b    %11100000
            dc.b    %10100000
            even
