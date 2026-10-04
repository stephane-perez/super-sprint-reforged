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
BSSX        equ     4096            ; utilisés : 80 + 48 + 40 + 32 + 1, en-tête dès 256
P4B         equ     -$2b74-BSSX
NPOS        equ     10              ; tables de positions (x ou y), 4 mots
DRONES      equ     -$f4a           ; drone[4]
PODCOL      equ     -$167e          ; podium : 3 couleurs par entrée, 7 entrées
                                    ; (0-2 humains, 3 verte drone, 4-6 drones)
PODCOL8     equ     P4B+NPOS*8      ; notre copie à 8 entrées (3 = verte
                                    ; humaine, 7 = verte drone)
UPCOL       equ     P4B+168         ; « customize car » (F_0F6DA) : tables
UPWID       equ     UPCOL+8         ; d'origine à 3 entrées (-$2240 couleur,
UPNAME      equ     UPCOL+16        ; -$2246 largeur, -$2252 nom), ici à 4
UPREL       equ     P4B+200         ; tir relâché depuis l'ouverture (octet)
HUDCLR      equ     P4B+201         ; bande du bas à effacer (octet)
HRACE       equ     P4B+202         ; appel depuis la course (octet)
RTBON       equ     P4B+203         ; notre Timer B installé (octet)
HSTEP1      equ     P4B+204         ; un seul élément par appel (octet)
RCNT        equ     P4B+360         ; raster de la course : compteurs,
RPALS       equ     P4B+368         ; 2 palettes (en-tête, reste)
RACEPAL     equ     -$17be          ; palette de la course
CUSTPAL     equ     -$171e          ; palettes de « customize car »
PODPAL      equ     -$1654          ; palettes du podium (bandes 1-3 :
                                    ; couleurs des voitures)
PRIOMASK    equ     $3e80           ; masque de priorité : (-$5E(a4)) + $3E80,
                                    ; 1 bit par pixel, 40 octets par ligne ;
                                    ; 0 = devant les voitures
HGREEN      equ     $070            ; vert vif de la colonne verte
MASTER      equ     -$5a            ; image maître de la course
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
            bra.w   upin            ; +76 : lecture du contrôle, « customize car »
            bra.w   cust4           ; +80 : améliorations de la verte (F_0DD20)
            bra.w   hlab            ; +84 : entrée $120 (F_0A1C6, étiquettes)
            bra.w   hwr             ; +88 : entrée $E4 (F_0A236, clés)
            bra.w   hsc             ; +92 : entrée $210 (F_0B5E6, score)
            bra.w   hlap            ; +96 : entrée $204 (F_0BB56, tour)
            bra.w   hblink          ; +100 : F_0994C (clignotement du premier)
            bra.w   rpal            ; +104 : palette de la course ($1B98, $2800)

; ----------------------------------------------------------------------------
; init : remplace l'appel de F_0624A au démarrage (jsr $24(a5)).
; Met la 4e voiture sur son contrôle par défaut, teste la présence des
; ports joypad (cookie _MCH = STE ou Falcon), puis continue vers F_0624A.
; ----------------------------------------------------------------------------
init        move.w  #CTL3_DEF,CTL+6(a4)
            move.w  #HGREEN,PODPAL+2*5(a4)  ; podium : en-tête (bande 0)
            move.w  #HGREEN,CUSTPAL+2*5(a4) ; « customize car » : en-tête,
                                    ; colonne verte en vert vif (couleur 5,
                                    ; inutilisée ailleurs dans cette bande)
            lea     UPCOL(a4),a0    ; écran « customize car » : couleur,
            move.l  #$02370701,(a0)+        ; largeur et nom du titre pour
            move.l  #$07730070,(a0)+        ; 4 voitures
            move.l  #$0058004d,(a0)+
            move.l  #$006e0063,(a0)+        ; « green car » : 9 x 11 pixels
            lea     $414(a4),a1             ; noms d'origine (DATA)
            move.l  a1,(a0)+
            lea     $41e(a4),a1
            move.l  a1,(a0)+
            lea     $426(a4),a1
            move.l  a1,(a0)+
            lea     txtgcar(pc),a1
            move.l  a1,(a0)+
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

hud4        bsr     cheat
            bsr     g4human
            bne.s   .human
            move.l  a5,a0
            adda.l  #F_0A2E4,a0
            jmp     (a0)
.human      tst.b   RTBON(a4)       ; raster de l'en-tête : notre Timer B
            bne.s   .rtbok
            bsr     rtbinst
.rtbok      tst.b   HUDCLR(a4)      ; la verte est dans l'en-tête : on
            beq.s   .no             ; efface seulement « DRONE LAP » de la
            subq.b  #1,HUDCLR(a4)   ; bande du bas (2 écrans, fond, image
            movem.l d2-d5/a2,-(a7)  ; maître), en début de course
            bsr     bgcol
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
            beq.s   .p4
            move.w  #$ffff,d5
.p4         movea.l SCREEN(a4),a1
            bsr.s   .fill
            movea.l BACKGND(a4),a1
            bsr.s   .fill
            movea.l MASTER(a4),a1
            bsr.s   .fill
            movem.l (a7)+,d2-d5/a2
.no         rts
.fill       lea     193*160+HUDX/2(a1),a2
            moveq   #6,d1           ; 7 lignes
.frow       movea.l a2,a0
            moveq   #10,d0          ; 11 blocs de 16 pixels
.fblk       move.l  d4,(a0)+
            move.l  d5,(a0)+
            dbra    d0,.fblk
            lea     160(a2),a2
            dbra    d1,.frow
            rts

; upin : dans F_0F6DA (« customize car »), remplace « jsr F_0629C / addq.l
; #2,a7 » ($FAB4) : lecture du contrôle de la voiture $10(a6). Pour la
; verte, le tir n'est pris en compte qu'après avoir été relâché une fois
; depuis l'ouverture de l'écran (premier passage : décompte -6(a6) = $1DA),
; sinon l'accélérateur encore enfoncé à la fin de la course valide tout de
; suite le choix.
upin        move.w  4(a7),-(a7)
            jsr     $96(a5)
            addq.l  #2,a7
            cmpi.w  #3,$10(a6)
            bne.s   .out
            cmpi.w  #$1da,-6(a6)
            bne.s   .chk
            sf      UPREL(a4)
.chk        tst.b   d0
            bmi.s   .fire
            st      UPREL(a4)
            bra.s   .out
.fire       tst.b   UPREL(a4)
            bne.s   .out
            andi.w  #$7f,d0
.out        movea.l (a7)+,a0
            addq.l  #2,a7
            jmp     (a0)

; cust4 : « prepare to race » (F_0DD20, $DDBC) : après les 3 appels de
; F_0E492(écran, voiture, x, y) (« customized car includes ... » sous
; chaque voiture), celui de la verte, sous sa voiture en bas à droite ; puis
; ce que faisait l'original à cet endroit : F_10032(écran).
cust4       move.w  #173,-(a7)
            move.w  #172,-(a7)
            move.w  #3,-(a7)
            move.l  8(a6),-(a7)
            move.l  a5,a0
            adda.l  #$e492,a0
            jsr     (a0)
            lea     10(a7),a7
            move.l  8(a6),-(a7)
            move.l  a5,a0
            adda.l  #$10032,a0
            jsr     (a0)
            addq.l  #4,a7
            rts

; cheat : touche « * » du pavé numérique (code $66) pendant la course :
; 5 clés à molette de plus pour chaque voiture (pour essayer l'écran
; « customize car » dès le premier circuit). Le gestionnaire IKBD met la
; case de la touche à 3 à l'appui et efface le bit 0 au relâchement : on
; efface le bit 1 pour ne compter qu'un appui.
KEYS        equ     -$12c2
KEYCHEAT    equ     $66
WRENCHES    equ     -$f72           ; clés de chaque voiture (mots)
cheat       bclr    #1,KEYS+KEYCHEAT(a4)
            beq.s   .no
            movem.l d0-d7/a0-a3,-(a7)  ; F_0A236 utilise d0-d4, d7, a0-a3
            lea     WRENCHES(a4),a0
            moveq   #3,d0
.add        addq.w  #5,(a0)+
            dbra    d0,.add
            moveq   #2,d6           ; chiffres des clés dans l'en-tête
.hdr        move.w  d6,-(a7)        ; (voitures 0 à 2, deux écrans)
            move.l  SCREEN(a4),-(a7)
            jsr     $e4(a5)
            move.l  SHOWN(a4),(a7)
            jsr     $e4(a5)
            addq.l  #6,a7
            dbra    d6,.hdr
            movem.l (a7)+,d0-d7/a0-a3
.no         rts

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
; (SHAREV) : le YM ne mélange pas deux sons sur une voie. F_0814C monte le
; volume de la voie (+8 par appel) vers une cible si la vitesse est > 20, et
; le baisse (-8) sinon : en alternant simplement, une voiture arrêtée
; faisait baisser le volume de l'autre. La voie va donc à la voiture qui
; roule si une seule roule, et alterne une image sur deux (25 Hz chacune)
; si les deux roulent ou si aucune ne roule.
SHAREV      equ     2
FRAMES      equ     -$1f88          ; compteur d'images (échanges d'écran)
SPEEDS      equ     -$e92           ; vitesse de chaque voiture (mots)
eng4        move.w  4(a7),d0
            cmpi.w  #3,d0
            beq.s   .green
            cmpi.w  #SHAREV,d0
            bne.s   .call
            moveq   #3,d0           ; la verte est-elle humaine sans voie
            bsr     vfree           ; libre ?
            bpl.s   .call
            bsr     g4human
            beq.s   .call
            bsr     owner           ; à qui la voie partagée ?
            bne.s   .no             ; à la verte
            bra.s   .call
.green      bsr     vfree
            bpl.s   .set
            bsr     owner
            beq.s   .no             ; à la jaune
            moveq   #SHAREV,d0
.set        move.w  d0,4(a7)
.call       move.l  a5,a0
            adda.l  #F_0814C,a0
            jmp     (a0)
.no         rts

; owner : Z = 1 si la voie partagée va à la jaune cette image, 0 à la verte
owner       move.l  d1,-(a7)
            moveq   #20,d1
            cmp.w   SPEEDS+2*SHAREV(a4),d1
            slt     d0              ; d0 = $FF si la jaune roule
            cmp.w   SPEEDS+6(a4),d1
            slt     d1              ; d1 = $FF si la verte roule
            cmp.b   d0,d1
            beq.s   .alt            ; les deux ou aucune : alternance
            tst.b   d1              ; la seule qui roule
            bra.s   .end
.alt        moveq   #1,d1
            and.b   FRAMES+1(a4),d1 ; images impaires : la verte
.end        movem.l (a7)+,d1        ; (ne change pas Z)
            rts

; snd4 : entrée $126, F_085DC(voiture)
snd4        move.w  4(a7),d0
            bsr     vmap
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


; ============================================================================
; En-tête à 4 colonnes (course, podium, « customize car »), quand la voiture
; verte est pilotée par un humain. L'original dessine 3 colonnes de 107
; pixels avec des routines aux positions codées en dur : étiquettes
; F_0A1C6, chiffre des clés F_0A236, score F_0B5E6, tour F_0BB56. On les
; remplace par 4 colonnes de 80 pixels (5 blocs) :
;   lignes 0-5  : nom (BLUE, RED, YELLOW, GREEN ou DRONE), clé et nombre de
;                 clés pour un humain, « LAP » à droite (x+62) ;
;   lignes 7-17 : score aligné à droite (6 chiffres à x+0..+54, virgule des
;                 milliers à x+30), tour à x+70.
; Couleurs (palette de course) : 9 bleu, $A rouge, $C jaune, 5 vert foncé.
; Les étiquettes sont tirées des images du jeu (banque -$6BA(a4) + $6720 :
; 6 images 112x6, 7 blocs, couleur 8 transparente), « GREEN » est dessiné
; à la main. Elles ne sont dessinées qu'à la préparation d'un écran (appel
; de F_0A1C6 pour la voiture 0), pixel par pixel. Les chiffres sont
; redessinés à la demande (appels de F_0A236, F_0B5E6, F_0BB56), colonne par
; colonne, seulement si leurs valeurs ont changé sur cet écran (cache par
; écran, comme la ligne du bas).
; ============================================================================
SPRBANK     equ     -$6ba           ; pointeur : banque d'images
LABSPR      equ     $6720           ; étiquettes, $150 octets chacune
WDIGSPR     equ     $6f00           ; chiffres des clés 16x6, $30 octets
HFONT       equ     -$1348          ; pointeur : police (+$A50 + n*$58)
HBG         equ     -$134c          ; pointeur : fond des lignes 7-17
LBG         equ     -$1350          ; pointeur : bande des étiquettes 0-5
SCORES      equ     -$12ee          ; score affichable, 6 octets par voiture
SCOREDISP   equ     -$1306          ; sa copie (F_0B5E6)
LAPS        equ     -$f42           ; tours
LAPDISP     equ     -$12d6          ; leur copie (F_0BB56, logique du jeu)
F_0A1C6     equ     $a1c6
F_0A236     equ     $a236
F_0B5E6     equ     $b5e6
F_0BB56     equ     $bb56
HDR         equ     P4B+256         ; 2 entrées : écran.l, témoin (8),
HDRSZ       equ     48              ; 4 colonnes x 8 octets affichés,
HBLINK      equ     44              ; colonnes effacées par le clignotement,
HNSAVE      equ     45              ; modifiées depuis leur copie,
HVALID      equ     46              ; dont la copie est valable (bits)
HSAVE       equ     P4B+512         ; copie des colonnes dessinées : 2 écrans
HCOLSZ      equ     11*40+8         ; x 4 colonnes x (11 lignes x 5 blocs +
                                    ; les 8 valeurs affichées)
HWIT        equ     12*160+4*8      ; témoin : tour de la colonne 0
HLASTS      equ     HDR+2*HDRSZ     ; dernier écran mis à jour (l)
HLASTF      equ     HLASTS+4        ; et à quelle image (w)

hcolor      dc.b    9,$a,$c,5
; nom d'un humain : image, x, largeur (la verte : txgreen)
hname       dc.w    0,0,22, 1,0,18, 2,7,33, 0,0,30
; nom d'un drone (« DRONE » aux couleurs de la voiture)
hdrone      dc.w    3,6,29, 4,6,29, 5,22,29, 3,6,29
; « LAP » : image, x
hlapw       dc.w    0,74, 1,74, 2,90, 0,74

; hlab : entrée $120, F_0A1C6(écran, voiture)
hlab        bsr     g4human
            bne.s   .ours
            move.l  a5,a0
            adda.l  #F_0A1C6,a0
            jmp     (a0)
.ours       tst.w   8(a7)
            bne.s   .no
            movem.l d0-d7/a0-a3,-(a7)
            movea.l 4+48(a7),a1
            bsr     lab4
            lea     HDR(a4),a0      ; écran repeint : rien n'est à jour
            clr.l   (a0)
            clr.l   HDRSZ(a0)
            clr.l   HLASTS(a4)
            move.b  #2,HUDCLR(a4)   ; bande du bas à effacer (course)
            movem.l (a7)+,d0-d7/a0-a3
.no         rts

; hwr : entrée $E4, F_0A236(écran, voiture)
hwr         bsr     g4human
            bne     hupd
            move.l  a5,a0
            adda.l  #F_0A236,a0
            jmp     (a0)

; hsc : entrée $210, F_0B5E6(écran, voiture) ; garde sa copie du score
hsc         bsr     g4human
            bne.s   .ours
            move.l  a5,a0
            adda.l  #F_0B5E6,a0
            jmp     (a0)
.ours       btst    #0,FRAMES+1(a4)
            bne.s   hupd
            move.w  8(a7),d0
            mulu    #6,d0
            lea     SCORES(a4),a0
            adda.w  d0,a0
            lea     SCOREDISP(a4),a1
            adda.w  d0,a1
            moveq   #5,d1
.cp         move.b  (a0)+,(a1)+
            dbra    d1,.cp
            bra.s   hupd

; hlap : entrée $204, F_0BB56(écran, voiture) ; garde sa copie du tour
hlap        bsr     g4human
            bne.s   .ours
            move.l  a5,a0
            adda.l  #F_0BB56,a0
            jmp     (a0)
.ours       btst    #0,FRAMES+1(a4)
            bne.s   .chk
            move.w  8(a7),d0
            add.w   d0,d0
            lea     LAPS(a4),a0
            lea     LAPDISP(a4),a1
            move.w  (a0,d0.w),(a1,d0.w)
.chk        ; le tour est demandé juste après le score (F_098BA, podium,
            ; customize car) : déjà mis à jour pour cet écran à cette image
            move.l  4(a7),d0
            cmp.l   HLASTS(a4),d0
            bne.s   hupd
            move.w  FRAMES(a4),d0
            cmp.w   HLASTF(a4),d0
            bne.s   hupd
            rts

; hupd : met à jour les chiffres de l'en-tête de l'écran 4(a7), demandés
; pour la voiture 8(a7). Pour ne jamais dépasser le temps d'une image, un
; seul élément est mis à jour par appel (un chiffre, le tour, les clés) ;
; les autres le sont aux appels suivants (une image chacun).
hupd        movem.l d0-d7/a0-a3,-(a7)
            movea.l 4+48(a7),a1
            move.l  a1,HLASTS(a4)   ; (voir hlap)
            move.w  FRAMES(a4),HLASTF(a4)
            ; appel depuis le code de la course (avant $A000 : aussi dans le
            ; fond BACKGND) ; depuis F_098BA (chaque image) : un élément
            move.l  48(a7),d0
            sub.l   a5,d0
            cmpi.l  #$a000,d0
            scs     HRACE(a4)
            cmpi.l  #$9922,d0
            seq     HSTEP1(a4)
            beq.s   .race
            cmpi.l  #$9930,d0
            seq     HSTEP1(a4)
.race
            ; entrée de cet écran
            lea     HDR(a4),a2
            cmpa.l  (a2),a1
            beq.s   .known
            lea     HDRSZ(a2),a2
            cmpa.l  (a2),a1
            beq.s   .known
            lea     HDR(a4),a2
            move.l  SHOWN(a4),d0
            cmp.l   (a2),d0
            bne.s   .full
            lea     HDRSZ(a2),a2
            bra.s   .full
.known      ; en course, l'en-tête n'est repeint qu'au départ (hlab vide
            ; alors le cache) ; le témoin, dans la colonne bleue, y change
            ; quand elle clignote (voitures, fond et masque communs aux
            ; deux écrans) : on ne le regarde pas
            tst.b   HRACE(a4)
            bne.s   .blink
            move.l  HWIT(a1),d0
            cmp.l   4(a2),d0
            bne.s   .full
            move.l  HWIT+4(a1),d0
            cmp.l   8(a2),d0
            beq.s   .blink
.full       move.l  a1,(a2)
            moveq   #3,d7
.inv        bsr     hinvcol
            dbra    d7,.inv
            clr.b   HBLINK(a2)
            clr.b   HNSAVE(a2)
            clr.b   HVALID(a2)
.blink      ; colonne effacée par le clignotement et redemandée : on remet
            ; sa copie (ou on la redessinera)
            move.w  8+48(a7),d7
            cmpi.w  #4,d7
            bhs.w   .steps
            bclr    d7,HBLINK(a2)
            beq.w   .steps
            btst    d7,HVALID(a2)
            bne.s   .copy
            bsr     hinvcol         ; pas de copie : toute la colonne,
            move.w  d7,d0           ; tout de suite (sinon le clignotement
            lsl.w   #3,d0           ; suivant arriverait avant la fin)
            lea     12(a2,d0.w),a3
.fc         lea     -8(a7),a7
            movea.l a7,a0
            bsr     hvals
            movea.l a7,a0
            movea.l a3,a1
            moveq   #7,d1
.fcc        cmpm.b  (a0)+,(a1)+
            dbne    d1,.fcc
            beq.s   .fce
            movea.l (a2),a1
            move.l  a2,-(a7)
            lea     4(a7),a2
            bsr     hstep
            movea.l (a7)+,a2
            lea     8(a7),a7
            bra.s   .fc
.fce        lea     8(a7),a7
            bsr     hwit
            bset    d7,HNSAVE(a2)   ; copie à la prochaine occasion
            bra     .steps
.copy       bsr     hsaveptr
            bsr     hcolptr
            movea.l a1,a3           ; en course : aussi dans le fond, d'où
            tst.b   HRACE(a4)       ; les voitures restaurent l'écran
            beq.s   .rs0
            suba.l  (a2),a3
            adda.l  BACKGND(a4),a3
.rs0        moveq   #10,d1
.rs         moveq   #9,d2
.rsw        move.l  (a0),(a3)+
            move.l  (a0)+,(a1)+
            dbra    d2,.rsw
            lea     160-40(a1),a1
            lea     160-40(a3),a3
            dbra    d1,.rs
            move.w  d7,d0           ; valeurs de la copie
            lsl.w   #3,d0
            lea     12(a2,d0.w),a1
            move.l  (a0)+,(a1)
            move.l  (a0),4(a1)
            bsr     hmvals          ; et leur masque de priorité
            bsr     hwit
.steps      moveq   #0,d7           ; voiture
            lea     12(a2),a3       ; valeurs affichées
.col        btst    d7,HBLINK(a2)   ; effacée : elle attend
            bne.w   .next
            lea     -8(a7),a7       ; valeurs à afficher
            movea.l a7,a0
            bsr     hvals
            movea.l a7,a0
            movea.l a3,a1
            moveq   #7,d1
.cmp        cmpm.b  (a0)+,(a1)+
            dbne    d1,.cmp
            beq.s   .clean
            movea.l (a2),a1         ; un élément de cette colonne
            move.l  a2,-(a7)
            lea     4(a7),a2
            bsr     hstep
            movea.l (a7)+,a2
            bsr     hwit
            movea.l a7,a0           ; colonne à jour ?
            movea.l a3,a1
            moveq   #7,d1
.cmp2       cmpm.b  (a0)+,(a1)+
            dbne    d1,.cmp2
            lea     8(a7),a7
            beq.s   .save
            bset    d7,HNSAVE(a2)
            bra.s   .more
.clean      lea     8(a7),a7
            bclr    d7,HNSAVE(a2)   ; colonne à jour depuis peu : copie
            beq.s   .next
.save       bclr    d7,HNSAVE(a2)
            bsr     hsaveptr
            bsr     hcolptr
            tst.b   HRACE(a4)       ; en course : copie prise dans le fond
            beq.s   .svs            ; (jamais de voiture dessus)
            suba.l  (a2),a1
            adda.l  BACKGND(a4),a1
.svs
            moveq   #10,d1
.sv         moveq   #9,d2
.svw        move.l  (a1)+,(a0)+
            dbra    d2,.svw
            lea     160-40(a1),a1
            dbra    d1,.sv
            move.l  (a3),(a0)+      ; et ses valeurs
            move.l  4(a3),(a0)
            bset    d7,HVALID(a2)
.more       ; en course (appel depuis F_098BA, chaque image) : un élément
            ; par appel ; ailleurs (podium, customize car) : tout de suite
            tst.b   HSTEP1(a4)
            bne.s   .done
            bra     .steps
.next       addq.l  #8,a3
            addq.w  #1,d7
            cmpi.w  #4,d7
            blt     .col
.done       movem.l (a7)+,d0-d7/a0-a3
            rts

; hinvcol : colonne d7 de l'entrée a2 à redessiner entièrement (fond à
; remettre : tour = -2, le reste vide)
hinvcol     move.w  d7,d0
            lsl.w   #3,d0
            lea     12(a2,d0.w),a0
            move.l  #$fffeffff,(a0)+
            move.l  #$ffffffff,(a0)
            bclr    d7,HVALID(a2)
            rts

; hcolptr : a1 = zone des chiffres (ligne 7) de la colonne d7, écran (a2)
hcolptr     movea.l (a2),a1
            move.w  d7,d0
            mulu    #40,d0
            lea     7*160(a1),a1
            adda.w  d0,a1
            rts

; hwit : témoin de l'écran (a2) à jour (il est dans la colonne 0)
hwit        movea.l (a2),a1
            move.l  HWIT(a1),4(a2)
            move.l  HWIT+4(a1),8(a2)
            rts

; hblink : remplace F_0994C(voiture) ($994C, sauté depuis son début) :
; F_098BA fait clignoter la colonne du premier en effaçant sa zone de
; chiffres (aux positions d'origine) ; ici, on efface la colonne de la
; voiture dans la disposition à 4 colonnes, sur l'écran en cours et dans le fond, et on
; marque ses valeurs comme non affichées pour qu'elle soit redessinée.
hblink      bsr     g4human
            bne.s   .ours
            link    a6,#0           ; début de F_0994C
            move.w  8(a6),d0
            move.l  a5,a0
            adda.l  #$9954,a0
            jmp     (a0)
.ours       movem.l d0-d7/a0-a3,-(a7)
            move.w  4+48(a7),d7
            movea.l SCREEN(a4),a1
            movea.l HBG(a4),a0
            move.w  d7,d0
            mulu    #40,d0
            adda.w  d0,a0
            lea     7*160(a1),a2
            adda.w  d0,a2
            movea.l BACKGND(a4),a3  ; et dans le fond, comme F_0994C
            lea     7*160(a3),a3
            adda.w  d0,a3
            moveq   #10,d1
.bg         moveq   #9,d2
.bgw        move.l  (a0),(a3)+
            move.l  (a0)+,(a2)+
            dbra    d2,.bgw
            lea     160-40(a0),a0
            lea     160-40(a2),a2
            lea     160-40(a3),a3
            dbra    d1,.bg
            lea     HDR(a4),a2      ; cette colonne n'est plus affichée
            cmpa.l  (a2),a1
            beq.s   .inv
            lea     HDRSZ(a2),a2
            cmpa.l  (a2),a1
            bne.s   .end
.inv        bset    d7,HBLINK(a2)   ; à remettre depuis sa copie
            bsr     hmcol           ; les voitures passent sur la colonne vide
            move.l  HWIT(a1),4(a2)  ; témoin (s'il est dans cette colonne)
            move.l  HWIT+4(a1),8(a2)
.end        clr.l   HLASTS(a4)
            movem.l (a7)+,d0-d7/a0-a3
            rts

; hsaveptr : a0 = copie de la colonne d7 pour l'entrée a2
hsaveptr    lea     HSAVE(a4),a0
            lea     HDR(a4),a1
            cmpa.l  a1,a2
            beq.s   .e0
            lea     4*HCOLSZ(a0),a0
.e0         move.w  d7,d0
            mulu    #HCOLSZ,d0
            adda.w  d0,a0
            rts

; rpal : remplace « clr.l -(a7) / pea RACEPAL(a4) » avant F_0A3DE(image,
; palette, compteurs) au début d'une course ($1B98, $2800) : la course a une
; seule palette, dont les seuls verts sont $040 (couleur 5) et l'herbe
; ($153, le fond de l'en-tête). Si la verte est humaine, on y ajoute une
; bande de raster (Timer B, déjà utilisé par les menus) : lignes 0-17
; (l'en-tête), même palette mais couleur 5 = vert vif ; puis la palette
; normale. Compteurs en paires de lignes.
rpal        movea.l (a7)+,a0        ; retour
            bsr     g4human
            beq.s   .orig
            lea     RACEPAL(a4),a1
            lea     RPALS(a4),a2
            moveq   #7,d0
.cp         move.l  (a1)+,(a2)+     ; bande de l'en-tête
            dbra    d0,.cp
            lea     RACEPAL(a4),a1  ; 2e bande : palette d'origine
            lea     RPALS+32(a4),a2
            moveq   #7,d0
.cp2        move.l  (a1)+,(a2)+
            dbra    d0,.cp2
            move.w  #HGREEN,RPALS+2*5(a4)
            sf      RTBON(a4)       ; Timer B à remplacer (hud4)
            move.w  #9,RCNT(a4)     ; 18 lignes
            move.w  #255,RCNT+2(a4)
            pea     RCNT(a4)
            pea     RPALS(a4)
            jmp     (a0)
.orig       clr.l   -(a7)
            pea     RACEPAL(a4)
            jmp     (a0)

; rtbinst : en course, remplace le gestionnaire Timer B du raster du jeu
; (une interruption toutes les 2 lignes pendant tout l'écran, ~100 par
; image) par rtb : à la 9e interruption (ligne 18, fin de l'en-tête) on
; remet la couleur 5 de la course et on arrête le Timer B jusqu'à la VBL
; suivante (qui le relance, avec la palette de l'en-tête). Superviseur.
rtbinst     movem.l d0-d2/a0-a2,-(a7)
            st      RTBON(a4)
            lea     rtbcnt(pc),a0
            move.l  a5,d0
            addi.l  #$578c,d0       ; compteur du raster du jeu (remis à 0
            move.l  d0,(a0)+        ; par sa VBL)
            move.w  RACEPAL+2*5(a4),(a0)
            pea     .sup(pc)
            move.w  #38,-(a7)       ; Supexec
            trap    #14
            addq.l  #6,a7
            movem.l (a7)+,d0-d2/a0-a2
            rts
.sup        lea     rtb(pc),a0
            move.l  a0,$120.w
            rts
rtbcnt      dc.l    0               ; adresse du compteur
rtbc5       dc.w    0               ; couleur 5 de la course
rtb         move.l  a0,-(a7)
            movea.l rtbcnt(pc),a0
            addq.w  #1,(a0)
            cmpi.w  #9,(a0)
            bne.s   .x
            move.w  rtbc5(pc),$ffff824a.w
            clr.b   $fffffa1b.w     ; Timer B arrêté
.x          movea.l (a7)+,a0
            bclr    #0,$fffffa0f.w
            rte

; hvals : 8 octets en a0 pour la voiture d7 : clés (0-9, -1 si drone), tour
; (0-9), score (6 chiffres, négatif = vide)
hvals       move.w  d7,d0
            add.w   d0,d0
            moveq   #-1,d1
            lea     DRONES(a4),a1
            tst.w   (a1,d0.w)
            bne.s   .dr
            lea     WRENCHES(a4),a1
            move.w  (a1,d0.w),d1
            cmpi.w  #9,d1
            bls.s   .dr
            moveq   #9,d1
.dr         move.b  d1,(a0)+
            lea     LAPS(a4),a1
            move.w  (a1,d0.w),d1
            cmpi.w  #9,d1
            bls.s   .l9
            moveq   #9,d1
.l9         move.b  d1,(a0)+
            move.w  d7,d0
            mulu    #6,d0
            lea     SCORES(a4),a1
            adda.w  d0,a1
            moveq   #5,d1
.sc         move.b  (a1)+,(a0)+
            dbra    d1,.sc
            rts

; hstep : met à jour UN élément de la colonne d7 de l'écran a1 : a3 =
; valeurs affichées, a2 = valeurs voulues (8 octets : clés, tour, score) ;
; tour affiché = -2 : on remet d'abord le fond de la colonne.
hstep       movem.l d0-d7/a0-a3,-(a7)
            move.w  d7,d6
            mulu    #80,d6          ; x de la colonne
            lea     hcolor(pc),a0
            moveq   #0,d4
            move.b  (a0,d7.w),d4    ; couleur
            cmpi.b  #-2,1(a3)
            bne.s   .digits
            lea     .rest(pc),a0    ; fond des lignes 7-17 (5 blocs)
            bsr     .both
            st      1(a3)           ; tour : rien d'affiché
            bra     .end
.digits     moveq   #0,d5           ; score : chiffres 0-5
.sd         move.b  2(a3,d5.w),d3   ; affiché
            move.b  2(a2,d5.w),d2   ; voulu
            cmp.b   d3,d2
            bne.s   .sdo
            addq.w  #1,d5
            cmpi.w  #6,d5
            blt.s   .sd
            bra.s   .lap
.sdo        move.b  d2,2(a3,d5.w)
            move.w  d5,d0
            mulu    #10,d0
            cmpi.w  #3,d5
            blt.s   .s3
            addq.w  #4,d0
.s3         add.w   d6,d0
            lea     .swap(pc),a0    ; efface l'ancien, dessine le nouveau
            bsr     .both
            cmpi.w  #2,d5           ; virgule des milliers : avec ce chiffre
            bne.s   .end
            eor.b   d3,d2
            bpl.s   .end            ; même présence
            lea     hcomma(pc),a0
            move.w  d6,d0
            addi.w  #30,d0
            move.w  d4,d2
            tst.b   d3
            bmi.s   .cd
            moveq   #-1,d2          ; plus de milliers : effacer
.cd         move.l  a0,d1
            lea     .glyph(pc),a0
            bsr     .both
            bra.s   .end
.lap        move.b  1(a3),d3
            move.b  1(a2),d2
            cmp.b   d3,d2
            beq.s   .wr
            move.b  d2,1(a3)
            move.w  d6,d0
            addi.w  #70,d0
            lea     .swap(pc),a0
            bsr     .both
            bra.s   .end
.wr         move.b  (a2),d1         ; nombre de clés (humains)
            move.b  d1,(a3)
            bmi.s   .end
            ext.w   d1
            lea     .wdig(pc),a0
            bsr     .both
.end        movem.l (a7)+,d0-d7/a0-a3
            rts
; .swap : en x d0, efface le chiffre d3 (s'il y en a un), dessine le d2
.swap       movem.l d2-d3,-(a7)
            tst.b   d3
            bmi.s   .sw1
            moveq   #0,d1
            move.b  d3,d1
            moveq   #-1,d2
            bsr     hdig
.sw1        movem.l (a7)+,d2-d3
            tst.b   d2
            bmi.s   .sw2
            moveq   #0,d1
            move.b  d2,d1
            move.l  d2,-(a7)
            move.w  d4,d2
            bsr     hdig
            move.l  (a7)+,d2
.sw2        rts
; .both : l'opération a0 sur l'écran a1, puis en course sur le fond de la
; course (BACKGND, d'où les voitures restaurent l'écran en passant)
.both       move.l  a0,-(a7)
            jsr     (a0)
            movea.l (a7)+,a0
            tst.b   HRACE(a4)
            beq.s   .b1
            move.l  a1,-(a7)
            movea.l BACKGND(a4),a1
            jsr     (a0)
            movea.l (a7)+,a1
.b1         rts
; .rest : fond des lignes 7-17 de la colonne d7 (5 blocs) sur a1 (et en
; course, masque de priorité de la colonne à 1)
.rest       tst.b   HRACE(a4)
            beq.s   .rm
            bsr     hmcol
.rm         movem.l d0-d2/a0-a1,-(a7)
            movea.l HBG(a4),a0
            move.w  d7,d0
            mulu    #40,d0
            adda.w  d0,a0
            lea     7*160(a1),a1
            adda.w  d0,a1
            moveq   #10,d1
.bg         moveq   #9,d2
.bgw        move.l  (a0)+,(a1)+
            dbra    d2,.bgw
            lea     160-40(a0),a0
            lea     160-40(a1),a1
            dbra    d1,.bg
            movem.l (a7)+,d0-d2/a0-a1
            rts
; .glyph : glyphe d1 (adresse) en x d0, couleur d2
.glyph      movea.l d1,a0
            bra     hglyph
; .wdig : chiffre des clés d1
.wdig       movem.l d0-d7/a0-a3,-(a7)
            bsr     hwdig
            movem.l (a7)+,d0-d7/a0-a3
            rts

; hnamew : d0 = largeur du nom de la voiture d7 (humaine)
hnamew      move.w  d7,d0
            mulu    #6,d0
            move.l  a0,-(a7)
            lea     hname+4(pc),a0
            move.w  (a0,d0.w),d0
            movea.l (a7)+,a0
            rts

; hwdig : chiffre des clés d1 de la voiture d7, colonne x d6, écran a1 :
; la case (6x6) est remplie de la couleur du fond de la bande, prise 2
; pixels à sa droite, puis on y pose le chiffre (images à $6F00, 16x6)
hwdig       bsr.s   hnamew
            add.w   d6,d0
            addi.w  #1+2+14+1,d0    ; après le nom et la clé
            move.w  d0,d4
            movem.l d1/d4,-(a7)
            movea.l a1,a0           ; couleur du fond
            addq.w  #8,d0
            moveq   #2,d1
            move.l  #160,d3
            bsr     getpx
            moveq   #0,d1           ; remplissage, lignes 0-4
.fy         moveq   #0,d0
.fx         movem.l d0,-(a7)
            add.w   d4,d0
            bsr     putpx
            movem.l (a7)+,d0
            addq.w  #1,d0
            cmpi.w  #6,d0
            blt.s   .fx
            addq.w  #1,d1
            cmpi.w  #5,d1
            blt.s   .fy
            movem.l (a7)+,d1/d4
            movea.l SPRBANK(a4),a0
            adda.l  #WDIGSPR,a0
            mulu    #$30,d1
            adda.w  d1,a0
            moveq   #0,d0           ; x source
            moveq   #6,d6           ; largeur
            move.w  d4,d7           ; x destination
            moveq   #-1,d5          ; pas de recoloration
            moveq   #8,d3           ; pas : 1 bloc
            bra     sprcopy

; hdig : gros chiffre d1 (0-9) en x d0 : dessiné (couleur d2) ou effacé
; (d2 < 0 : le fond est remis sous ses pixels), écran a1
hdig        movea.l HFONT(a4),a0
            lea     $a50(a0),a0
            mulu    #$58,d1
            adda.w  d1,a0
; hglyph : glyphe a0 (11 lignes : forme.l, masque.l ; forme en colonnes
; 13-21) en x d0, lignes 7-17. d2 = couleur : forme dans cette couleur,
; ombre (masque sans forme) en noir ; d2 < 0 : on remet le fond (HBG) sous
; la forme et l'ombre (effacement d'un chiffre sans toucher ses voisins).
hglyph      tst.b   HRACE(a4)       ; en course : masque de priorité
            beq.s   .nm
            bsr     hgmask
.nm         movem.l d0-d7/a0-a4,-(a7)
            move.w  d0,d3
            andi.w  #15,d3
            subi.w  #13,d3          ; décalage : > 0 à droite, < 0 à gauche
            lsr.w   #4,d0
            lsl.w   #3,d0
            lea     7*160(a1),a2
            adda.w  d0,a2
            tst.w   d2
            bmi.s   .erase
            lea     hpltab(pc),a3
            andi.w  #15,d2
            add.w   d2,d2
            adda.w  (a3,d2.w),a3
            bra.s   .go
.erase      movea.l HBG(a4),a4
            adda.w  d0,a4
            lea     hplbg(pc),a3
.go         moveq   #10,d7
.row        move.l  (a0)+,d4        ; forme
            move.l  (a0)+,d5
            not.l   d5              ; forme + ombre
            tst.w   d3
            bmi.s   .left
            lsr.l   d3,d4
            lsr.l   d3,d5
            bra.s   .sh
.left       neg.w   d3
            lsl.l   d3,d4
            lsl.l   d3,d5
            neg.w   d3
.sh         move.l  d5,d6
            not.l   d6              ; hors forme et ombre
            swap    d4
            swap    d5
            swap    d6
            movea.l a2,a1
            jsr     (a3)
            swap    d4
            swap    d5
            swap    d6
            lea     8(a2),a1
            addq.l  #8,a4
            jsr     (a3)
            subq.l  #8,a4
            lea     160(a2),a2
            lea     160(a4),a4
            dbra    d7,.row
            movem.l (a7)+,d0-d7/a0-a4
            rts
; un bloc (a1) : 4 plans ; d4 forme, d5 forme+ombre, d6 = ~d5
hpltab      dc.w    hpl0-hpltab,hpl1-hpltab,hpl2-hpltab,hpl3-hpltab,hpl4-hpltab,hpl5-hpltab,hpl6-hpltab,hpl7-hpltab,hpl8-hpltab,hpl9-hpltab,hpl10-hpltab,hpl11-hpltab,hpl12-hpltab,hpl13-hpltab,hpl14-hpltab,hpl15-hpltab
hpl0
            and.w   d6,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)+
            rts
hpl1
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)+
            rts
hpl2
            and.w   d6,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)+
            rts
hpl3
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)+
            rts
hpl4
            and.w   d6,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)+
            rts
hpl5
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)+
            rts
hpl6
            and.w   d6,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)+
            rts
hpl7
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)+
            rts
hpl8
            and.w   d6,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            rts
hpl9
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            rts
hpl10
            and.w   d6,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            rts
hpl11
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            rts
hpl12
            and.w   d6,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            rts
hpl13
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            rts
hpl14
            and.w   d6,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            rts
hpl15
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            and.w   d6,(a1)
            or.w    d4,(a1)+
            rts
; effacement : fond (a4) sous forme + ombre
hplbg       move.w  (a4),d0
            and.w   d5,d0
            and.w   d6,(a1)
            or.w    d0,(a1)+
            move.w  2(a4),d0
            and.w   d5,d0
            and.w   d6,(a1)
            or.w    d0,(a1)+
            move.w  4(a4),d0
            and.w   d5,d0
            and.w   d6,(a1)
            or.w    d0,(a1)+
            move.w  6(a4),d0
            and.w   d5,d0
            and.w   d6,(a1)
            or.w    d0,(a1)+
            rts

; hgmask : masque de priorité sous le glyphe a0 en x d0 (lignes 7-17) :
; dessiné (d2 >= 0) : 0 sous forme + ombre (les voitures passent dessous,
; comme sous les chiffres d'origine, F_0BB56) ; effacé (d2 < 0) : 1
hgmask      movem.l d0-d7/a0-a2,-(a7)
            movea.l -$5e(a4),a2
            adda.l  #PRIOMASK+7*40,a2
            move.w  d0,d3
            andi.w  #15,d3
            subi.w  #13,d3
            lsr.w   #4,d0
            add.w   d0,d0
            adda.w  d0,a2
            moveq   #10,d7
.r          addq.l  #4,a0
            move.l  (a0)+,d5
            not.l   d5              ; forme + ombre
            tst.w   d3
            bmi.s   .l
            lsr.l   d3,d5
            bra.s   .s
.l          neg.w   d3
            lsl.l   d3,d5
            neg.w   d3
.s          tst.w   d2
            bmi.s   .e
            not.l   d5
            swap    d5
            and.w   d5,(a2)
            swap    d5
            and.w   d5,2(a2)
            bra.s   .n
.e          swap    d5
            or.w    d5,(a2)
            swap    d5
            or.w    d5,2(a2)
.n          lea     40(a2),a2
            dbra    d7,.r
            movem.l (a7)+,d0-d7/a0-a2
            rts

; hmcol : masque de priorité de la colonne d7 à 1 (lignes 7-17)
hmcol       movem.l d0-d1/a0,-(a7)
            movea.l -$5e(a4),a0
            adda.l  #PRIOMASK+7*40,a0
            move.w  d7,d0
            mulu    #10,d0
            adda.w  d0,a0
            moveq   #10,d1
.r          move.l  #-1,(a0)
            move.l  #-1,4(a0)
            move.w  #-1,8(a0)
            lea     40(a0),a0
            dbra    d1,.r
            movem.l (a7)+,d0-d1/a0
            rts

; hmvals : masque de priorité de la colonne d7 pour les valeurs (a1)
; (après avoir remis une copie de la colonne)
hmvals      movem.l d0-d6/a0-a1,-(a7)
            bsr.s   hmcol
            move.w  d7,d6
            mulu    #80,d6
            moveq   #0,d2           ; « dessiné »
            moveq   #0,d5
.sd         move.b  2(a1,d5.w),d1
            bmi.s   .sn
            move.w  d5,d0
            mulu    #10,d0
            cmpi.w  #3,d5
            blt.s   .s3
            addq.w  #4,d0
.s3         add.w   d6,d0
            bsr.s   .dig
.sn         addq.w  #1,d5
            cmpi.w  #6,d5
            blt.s   .sd
            tst.b   4(a1)
            bmi.s   .nc
            lea     hcomma(pc),a0
            move.w  d6,d0
            addi.w  #30,d0
            bsr     hgmask
.nc         move.b  1(a1),d1
            bmi.s   .end
            move.w  d6,d0
            addi.w  #70,d0
            bsr.s   .dig
.end        movem.l (a7)+,d0-d6/a0-a1
            rts
.dig        movea.l HFONT(a4),a0
            lea     $a50(a0),a0
            ext.w   d1
            mulu    #$58,d1
            adda.w  d1,a0
            bra     hgmask

; lab4 : étiquettes des 4 colonnes sur l'écran a1 (lignes 0-5)
lab4        moveq   #0,d7
.col        move.w  d7,d6
            mulu    #80,d6          ; x de la colonne
            move.w  d7,d0
            add.w   d0,d0
            lea     DRONES(a4),a0
            tst.w   (a0,d0.w)
            bne.s   .drone
            cmpi.w  #3,d7
            bne.s   .hum
            move.w  d6,d0           ; « GREEN »
            addq.w  #1,d0
            bsr     grdraw
            bra.s   .wr
.hum        lea     hname(pc),a0
            bsr.s   .spr
.wr         bsr     hnamew          ; clé après le nom
            add.w   d6,d0
            addq.w  #1+2,d0
            movem.l d6-d7,-(a7)
            move.w  d0,d7
            movea.l SPRBANK(a4),a0
            adda.l  #LABSPR,a0      ; image 0
            moveq   #49,d0
            moveq   #14,d6
            moveq   #-1,d5
            moveq   #56,d3
            bsr     sprcopy
            movem.l (a7)+,d6-d7
            bra.s   .lap
.drone      lea     hdrone(pc),a0
            bsr.s   .spr
.lap        move.w  d7,d0           ; « LAP »
            lsl.w   #2,d0
            lea     hlapw(pc),a0
            adda.w  d0,a0
            movem.l d6-d7,-(a7)
            move.w  (a0)+,d0
            mulu    #$150,d0
            movea.l SPRBANK(a4),a2
            adda.l  #LABSPR,a2
            adda.l  d0,a2
            move.w  (a0),d0         ; x source
            moveq   #-1,d5
            cmpi.w  #3,d7
            bne.s   .lc
            move.w  #$0905,d5       ; bleu -> vert
.lc         add.w   #62,d6
            move.w  d6,d7
            moveq   #18,d6
            movea.l a2,a0
            moveq   #56,d3
            bsr     sprcopy
            movem.l (a7)+,d6-d7
            addq.w  #1,d7
            cmpi.w  #4,d7
            blt     .col
            rts
; .spr : nom depuis la table a0 (image, x, largeur) pour la voiture d7
.spr        move.w  d7,d0
            mulu    #6,d0
            adda.w  d0,a0
            movem.l d6-d7,-(a7)
            move.w  (a0)+,d0
            mulu    #$150,d0
            movea.l SPRBANK(a4),a2
            adda.l  #LABSPR,a2
            adda.l  d0,a2
            move.w  (a0)+,d0
            addq.w  #1,d6
            move.w  d6,d7           ; x destination
            move.w  (a0),d6         ; largeur
            moveq   #-1,d5
            movea.l a2,a0
            moveq   #56,d3
            bsr.s   sprcopy
            movem.l (a7)+,d6-d7
            rts

; grdraw : « GREEN » (txgreen) en x d0, lignes 0-5, écran a1
grdraw      movem.l d0-d4/a0,-(a7)
            move.w  d0,d4
            lea     txgreen(pc),a0
            moveq   #0,d1
.y          moveq   #0,d3
.x          move.b  (a0)+,d2
            beq.s   .n
            subq.b  #1,d2           ; 1 -> vert (5), 2 -> noir (0)
            bne.s   .k
            moveq   #5,d2
            bra.s   .p
.k          moveq   #0,d2
.p          move.w  d4,d0
            add.w   d3,d0
            bsr     putpx
.n          addq.w  #1,d3
            cmpi.w  #30,d3
            blt.s   .x
            addq.w  #1,d1
            cmpi.w  #6,d1
            blt.s   .y
            movem.l (a7)+,d0-d4/a0
            rts

; sprcopy : copie, de l'image a0 (pas d3 octets par ligne), les pixels
; x = d0 .. d0+d6-1 des lignes 0-5 vers x = d7 de l'écran a1 ; couleur 8
; transparente ; d5 = recoloration (ancienne << 8 | nouvelle) ou -1
sprcopy     movem.l d0-d7,-(a7)
            moveq   #0,d1
.y          moveq   #0,d4           ; colonne
.x          movem.l d0-d1/d4,-(a7)
            add.w   d4,d0
            bsr.s   getpx
            movem.l (a7)+,d0-d1/d4
            cmpi.w  #8,d2
            beq.s   .skip
            move.w  d5,-(a7)
            lsr.w   #8,d5
            cmp.b   d5,d2
            bne.s   .rc
            move.w  (a7),d2
            andi.w  #$ff,d2
.rc         move.w  (a7)+,d5
            move.w  d0,-(a7)
            move.w  d7,d0
            add.w   d4,d0
            bsr.s   putpx
            move.w  (a7)+,d0
.skip       addq.w  #1,d4
            cmp.w   d6,d4
            blt.s   .x
            addq.w  #1,d1
            cmpi.w  #6,d1
            blt.s   .y
            movem.l (a7)+,d0-d7
            rts

; getpx : d2 = couleur du pixel (d0, d1) de l'image a0, pas d3 octets
getpx       movem.l d3-d5/a0,-(a7)
            mulu    d1,d3
            adda.l  d3,a0
            move.w  d0,d3
            lsr.w   #4,d3
            lsl.w   #3,d3
            adda.w  d3,a0
            move.w  d0,d4
            not.w   d4
            andi.w  #15,d4
            moveq   #0,d2
            moveq   #3,d5
            addq.l  #8,a0
.l          move.w  -(a0),d3
            add.w   d2,d2
            btst    d4,d3
            beq.s   .z
            addq.w  #1,d2
.z          dbra    d5,.l
            movem.l (a7)+,d3-d5/a0
            rts

; putpx : pixel (d0, d1) de l'écran a1 en couleur d2
putpx       movem.l d3-d5/a1,-(a7)
            move.w  d1,d3
            mulu    #160,d3
            adda.l  d3,a1
            move.w  d0,d3
            lsr.w   #4,d3
            lsl.w   #3,d3
            adda.w  d3,a1
            move.w  d0,d4
            not.w   d4
            andi.w  #15,d4
            moveq   #0,d5
.p          move.w  (a1),d3
            bclr    d4,d3
            btst    d5,d2
            beq.s   .n
            bset    d4,d3
.n          move.w  d3,(a1)+
            addq.w  #1,d5
            cmpi.w  #4,d5
            blt.s   .p
            movem.l (a7)+,d3-d5/a1
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
txtgcar     dc.b    'green car',0
txtai       dc.b    12,20,38,34,26,29,22,38,13,36,38,14,23,12,32,15,16,-1
                                                ; AI WORK BY CLAUDE
gwrench     dc.b    %10100000                       ; clé à molette
            dc.b    %11100000                       ; (8 pixels de large)
            dc.b    %01111111
            dc.b    %11100000
            dc.b    %10100000
            even

; « GREEN » : 6 lignes de 30 pixels (0 transparent, 1 vert, 2 noir),
; contour noir à gauche et en dessous comme la police des étiquettes
txgreen
            dc.b    0,2,1,1,1,1,2,1,1,1,1,0,2,1,1,1,1,1,2,1,1,1,1,1,2,1,1,0,2,1
            dc.b    2,1,1,2,2,2,2,1,1,2,1,1,2,1,1,2,2,2,2,1,1,2,2,2,2,1,1,1,2,1
            dc.b    2,1,1,2,1,1,2,1,1,1,1,2,2,1,1,1,1,0,2,1,1,1,1,0,2,1,1,1,1,1
            dc.b    2,1,1,2,2,1,2,1,1,2,1,1,2,1,1,2,2,0,2,1,1,2,2,0,2,1,1,2,1,1
            dc.b    2,2,1,1,1,1,2,1,1,2,1,1,2,1,1,1,1,1,2,1,1,1,1,1,2,1,1,2,2,1
            dc.b    0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,2,2

; virgule des milliers, au format de la police des gros chiffres
hcomma
            dc.l    $00000000,$ffffffff
            dc.l    $00000000,$ffffffff
            dc.l    $00000000,$ffffffff
            dc.l    $00000000,$ffffffff
            dc.l    $00000000,$ffffffff
            dc.l    $00000000,$ffffffff
            dc.l    $00000000,$ffffffff
            dc.l    $00060000,$fff8ffff
            dc.l    $00060000,$fff8ffff
            dc.l    $00020000,$fff8ffff
            dc.l    $00040000,$fff8ffff
