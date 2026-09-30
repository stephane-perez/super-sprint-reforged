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
;   6 joypad A (STE / Falcon)   7 joypad B (STE / Falcon)
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
F_0E67C     equ     $e67c           ; « prepare to race » dans une colonne
F_0F560     equ     $f560           ; idem, depuis F_0F4E2
XTAB_I      equ     -$21d8          ; x des libellés, indexé par voiture
XTAB_K      equ     -$21dc          ; même table, indexée par touche F2..F4
NAMES       equ     -$21ca          ; 4 pointeurs vers les noms des contrôles
; Libellé de la 4e voiture : dans la 1re ligne d'aide (x=$19, y=$AD, 6 pixels
; par caractère), réécrite par le patcheur en « f5 - green car » à partir
; du 10e caractère ; le nom du contrôle suit, 26 caractères après le début.
X4          equ     $19+26*6
Y4          equ     $ad

            org     0

; ---- table d'entrée : le patcheur vise ces adresses (base + 4*n) ----------
            bra.w   ext629c         ; +0  : F_0629c, contrôles 1 et >= 4
            bra.w   init            ; +4  : entrée $24 de la table de sauts
            bra.w   joindraw        ; +8  : « prepare to race » (colonne i)
            bra.w   names           ; +12 : pointeur vers le nom d'un contrôle
            bra.w   xpos_i          ; +16 : x du libellé (boucle par voiture)
            bra.w   xpos_k          ; +20 : x du libellé (touche F2..F5)
            bra.w   joindraw2       ; +24 : « prepare to race », autre écran

; ----------------------------------------------------------------------------
; init : remplace l'appel de F_0624A au démarrage (jsr $24(a5)).
; Met la 4e voiture sur son contrôle par défaut, teste la présence des
; ports joypad (cookie _MCH), puis continue vers F_0624A.
; ----------------------------------------------------------------------------
init        move.w  #CTL3_DEF,CTL+6(a4)
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
            swap    d1              ; 1 = STE / Mega STE, 3 = Falcon
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
            ; --- joypads STE : $FF9202 = sélection de ligne (écriture) et
            ; directions (lecture, bits 8-11 pad A, 12-15 pad B, actifs à 0),
            ; $FF9200 = tirs (bit 1 pad A, bit 3 pad B, actifs à 0).
.pad        move.b  haspad(pc),d2
            beq.s   .done
            cmpi.w  #7,d1
            beq.s   .padb
            move.w  #$fffe,$ffff9202.w
            move.w  $ffff9202.w,d0
            move.w  $ffff9200.w,d2
            lsr.w   #8,d0
            btst    #1,d2
            bra.s   .padx
.padb       move.w  #$ffef,$ffff9202.w
            move.w  $ffff9202.w,d0
            move.w  $ffff9200.w,d2
            lsr.w   #8,d0
            lsr.w   #4,d0
            btst    #3,d2
.padx       seq     d1
            not.b   d0
            andi.b  #$0f,d0
            andi.b  #$80,d1
            or.b    d1,d0
            move.w  #$ffff,$ffff9202.w
.done       lea     extval(pc),a0
            move.b  d0,(a0)
            rts

; ----------------------------------------------------------------------------
; joindraw : remplace « jsr F_0E67C(pc) » dans F_0E3CA (une voiture rejoint
; la course). F_0E67C écrit dans la colonne x = 15 + 107*i de l'en-tête : il
; n'y a que 3 colonnes, on n'écrit rien pour la 4e voiture.
; Pile : retour, pointeur écran (long), i (mot), i+1 (mot).
; ----------------------------------------------------------------------------
joindraw    cmpi.w  #3,8(a7)
            beq.s   .skip
            move.l  a5,a0
            adda.l  #F_0E67C,a0
            jmp     (a0)
.skip       rts

; joindraw2 : remplace « jsr F_0F560(pc) » dans F_0F4E2 (une voiture rejoint
; la course pendant « prepare to race »). Pile : retour, écran (long),
; x (mot), i+1 (mot).
joindraw2   cmpi.w  #4,10(a7)
            beq.s   .skip
            move.l  a5,a0
            adda.l  #F_0F560,a0
            jmp     (a0)
.skip       rts

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
; « move.w (a0),-(a7) » (x du libellé). d0 = 2*indice. Pour la 4e voiture
; (i = 3 ou touche F5), x = X4 et on corrige le y déjà empilé (4(a7)).
; ----------------------------------------------------------------------------
xpos_i      cmpi.w  #6,d0
            beq.s   car4
            lea     XTAB_I(a4),a0
            adda.w  d0,a0
            rts
xpos_k      cmpi.w  #10,d0
            beq.s   car4
            lea     XTAB_K(a4),a0
            adda.w  d0,a0
            rts
car4        move.w  #Y4,4(a7)
            lea     x4(pc),a0
            rts

; ---- données ---------------------------------------------------------------
x4          dc.w    X4
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
