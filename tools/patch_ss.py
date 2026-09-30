"""patch_ss.py : fabrique SSPRINT.PRG à partir de VOTRE SUPER2.DAT.

    python3 tools/patch_ss.py SUPER2.DAT SSPRINT.PRG               # disque dur
    python3 tools/patch_ss.py SUPER2.DAT SSPRINT.PRG --p4 p4.bin   # + 4e voiture
    ... --autopilot : pour les tests, voitures humaines conduites par l'IA

SUPER2.DAT est le programme du jeu (PRG GEMDOS). Le fichier fourni doit être
exactement celui de la version étudiée (MD5 ci-dessous). Chaque correctif
vérifie les octets d'origine avant d'écrire.

Correctif « disque dur » (toujours appliqué)
  $5EC8 : F_05EB8 lit le secteur de boot du lecteur A: (Floprd) et attend
  « SOA » aux octets 8-10. Sans cette disquette, la course s'arrête tout de
  suite et les records ne sont pas sauvés ; sous EmuTOS sans disquette,
  l'attente est infinie. On saute directement au rts (drapeau d'échec à 0).

Option --p4 : code de src/p4.s ajouté à la fin du TEXT
  Le DATA et le BSS sont décalés d'autant. Le jeu n'y accède que par a4
  (recalculé au démarrage depuis la page de base) : rien d'autre à changer.
  Les seules relocations d'origine sont dans le TEXT (table de sauts), on y
  ajoute celles de nos « jmp adresse.l ».
"""
import sys, struct, hashlib

MD5 = '2d828d5478e14b7e7b7bbb820ade4cfd'

# (adresse dans le TEXT, octets d'origine, nouveaux octets)
HD = [
    (0x5EC8, '7a083f3c', '60000058'),       # bra $5F22 (unlk / rts)
]

# --autopilot (tests seulement) : dans la boucle des voitures ($2508), une
# voiture humaine est conduite par l'IA (F_047E6) au lieu de F_031F6. Le jeu
# la traite toujours comme humaine : on peut voir fins de course, podium et
# courses suivantes sans savoir conduire au clavier.
AUTOPILOT = [
    (0x2508, '4eba0cec', '4eba22dc'),
]

BSSX = 256          # octets ajoutés au BSS (= BSSX de src/p4.s)
P4B = -0x2B74 - BSSX  # début de la zone ajoutée, relatif à a4

def lea_a4(disp):
    return '41ec%04x' % (disp & 0xFFFF)

def p4_patches(B):
    """B = adresse du code ajouté (fin du TEXT d'origine)."""
    def jsr_pc(at, target):                 # jsr d16(pc) + nop (6 octets)
        d = target - (at + 2)
        assert -0x8000 <= d < 0x8000, hex(at)
        return '4eba%04x4e71' % (d & 0xFFFF)
    def jmp_abs(target):
        return '4ef9%08x' % target
    def loop4(at, disp='fffe'):             # cmpi.w #3,d16(a6) -> #4
        return (at, '0c6e0003' + disp, '0c6e0004' + disp)
    E = lambda n: B + 4 * n                 # table d'entrée de p4.s
    P = [
        # Octets joysticks IKBD déplacés de -$12C4/-$12C3(a4) vers les cases
        # $74/$75 du tableau des touches (-$12C2(a4)), jamais écrites.
        (0x6224, '41eced3c', '41ecedb2'),   # gestionnaire IKBD
        (0x6314, '102ced3c', '102cedb2'),   # F_0629c, joystick 0
        (0x6330, '102ced3d', '102cedb3'),   # F_0629c, joystick 1
        # F_0629c : contrôle inconnu -> ext629c
        (0x6340, '303c00006000000a', jmp_abs(E(0)) + '4e71'),
        # table de sauts, entrée $24 (F_0624A, appelée une fois au démarrage)
        (0x0024, '4ef90000624a', jmp_abs(E(1))),
        # table de sauts, entrée $132 (F_0A2E4, « DRONE LAP n ») : ligne du
        # bas de la voiture verte quand elle est pilotée par un humain
        (0x0132, '4ef90000a2e4', jmp_abs(E(5))),
        # table de sauts, entrée $18c (F_0A546, décompression) : image des
        # options / prepare to race / initiales avec 4 voitures
        (0x018C, '4ef90000a546', jmp_abs(E(6))),
        # F_0E850 : les 6 grands titres -> titles, puis saut à la suite
        (0xE8A6, '3f3c00053f3c00203f3c', '4eb9%08x600000a0' % E(7)),
        # F_0975A : fin de partie si les 4 voitures sont des drones
        (0x97EC, '302cf0b6c06cf0b8c06cf0ba3d40fffc',
                 '4eb9%08x3d40fffc4e714e714e71' % E(8)),
        # inscription d'une voiture : F_0E3CA et F_0F4E2 sur 4 voitures
        loop4(0xE484), loop4(0xF552),
        # écran des options (F_0E850)
        (0xEA10, '41ecde28d0c0', jsr_pc(0xEA10, E(3))),   # x, y libellé, voiture i
        (0xEA28, '41ecde36d0c0', jsr_pc(0xEA28, E(2))),   # nom du contrôle
        loop4(0xEA40),                                    # affichage : 4 voitures
        loop4(0xEA9C),                                    # animations : 4 voitures
        (0xEAD8, '0c400003', '0c400004'),                 # (voiture 3 plus sautée)
        (0xEDD2, '0c400003', '0c400004'),
        (0xEBA4, '0c6e0005fffe', '0c6e0006fffe'),         # F2..F5
        (0xEBBE, 'c07c0003', 'c07c0007'),                 # 8 contrôles
        (0xEBE0, '66000010', '60000010'),                 # 1 (« none ») permis
        (0xEC04, '41ecde24d0c0', jsr_pc(0xEC04, E(4))),   # x, y libellé, touche
        (0xEC1C, '41ecde36d0c0', jsr_pc(0xEC1C, E(2))),
        loop4(0xECBC, 'fffc'), loop4(0xECCA),             # contrôles en double
        (0xEC96, '66000020', '60000020'),                 # plus de conflit souris
        (0xED6E, '41ecde28d0c0', jsr_pc(0xED6E, E(3))),
        (0xED86, '41ecde36d0c0', jsr_pc(0xED86, E(2))),
        loop4(0xED9E),
        # textes du haut des écrans « choix du circuit », « prepare to race »
        # et initiales : 4 colonnes de 80 pixels (bleue, rouge, jaune, verte)
        # au lieu de 3 de 107 : x = base - 11 + 80 * i
        (0xD278, '303c0025323c006b', '303c001a323c0050'),
        (0xD340, '303c0025323c006b', '303c001a323c0050'),
        (0xDA0A, '303c000f322e0008c3fc006b', '303c0004322e0008c3fc0050'),
        (0xDAC4, '303c000f322e0008c3fc006b', '303c0004322e0008c3fc0050'),
        (0xDBC2, '303c000f322e0008c3fc006b', '303c0004322e0008c3fc0050'),
        (0xE2E8, '303c0033322efffec3fc006b', '303c0028322efffec3fc0050'),
        (0xE680, '303c000f323c006b', '303c0004323c0050'),
        (0xE790, '303c000f323c006b', '303c0004323c0050'),
        (0xEF76, '303c000f322efffec3fc006b', '303c0004322efffec3fc0050'),
        (0xEF9C, '303c000f322efffec3fc006b', '303c0004322efffec3fc0050'),
        (0xF526, '303c000f322efffec3fc006b', '303c0004322efffec3fc0050'),
        loop4(0xEFBA),                                    # F_0EE60 : 4 colonnes
        # F_0DD20 (prepare to race) : 4 voitures. Ses tableaux locaux par
        # voiture (3 mots en -$1C, -$16, -$10, -$A(a6)) sont déplacés en
        # -$3C, -$34, -$2C, -$24(a6), 4 mots chacun (voir reframe()).
        loop4(0xDE9E), loop4(0xE29E), loop4(0xE314),
        # fin de sa boucle : prepchk (4 voitures)
        (0xE348, '0c6e0001fff06700fb820c6e0001fff2',
                 '4eb9%08x4a406600fb8060000042' % E(9)),
        # 4e colonne vide si la voiture 4 n'a pas de contrôle
        (0xDE0C, '4eba097e', '4eba%04x' % ((E(11) - 0xDE0E) & 0xFFFF)),
        (0xEFB0, '4eba065a', '4eba%04x' % ((E(12) - 0xEFB2) & 0xFFFF)),
        (0xE308, '4ebadf1a', '4eba%04x' % ((E(13) - 0xE30A) & 0xFFFF)),
        # podium (F_101C6) : couleurs de la voiture 3 comme les autres
        # (voiture + 4 * drone) dans une table à 8 entrées (P4B + 80)
        (0x104EE, '0c500003', '0c500004'),
        (0x1054A, '41ece982', lea_a4(P4B + 80)),
        # clés à molette de départ (choix de la difficulté, F_0EE60) et
        # remise à zéro des clés d'un joueur éliminé (F_101C6) : 4 voitures
        loop4(0xF300), loop4(0x110A8, 'ff90'),
        # F_0F680 : écran « customize car » pour 4 voitures
        loop4(0xF6CC),
        # F_0CFEC (saisie des initiales) : 4 voitures. Tableaux locaux
        # déplacés (reframe_ini) ; boucles à 4 ; les voitures sont servies à
        # tour de rôle : compteur % 3 -> (compteur / 2) & 3 (le compteur
        # baisse de 2 par image) ; fin de saisie : inichk.
        loop4(0xD134, 'fff8'), loop4(0xD1DE, 'fff8'), loop4(0xD2B2, 'fff8'),
        loop4(0xD30E, 'fff8'), loop4(0xD720, 'fff8'),
        (0xD31C, '302effec48c081fc000348403d40ffea',
                 '302effece248c07c00034e713d40ffea'),
        (0xD672, '0c6e0001fffa6700001a0c6e0001fffc670000100c6e0001fffe67000006',
                 '4eb9%08x4a406600001860000010' % E(10) + '4e71' * 7),
    ]
    # tables de positions par voiture (3 cases dans l'original) -> 4 cases
    # dans le BSS ajouté, remplies par init
    TABLES = [(-0x2184, (0xD2F4, 0xD614)), (-0x218A, (0xD2E6, 0xD606)),
              (-0x2190, (0xDE84, 0xDF4A, 0xE180)), (-0x2196, (0xDE76, 0xDF3C, 0xE172)),
              (-0x219C, (0xE102,)), (-0x21A2, (0xE0F4,)),
              (-0x21A8, (0xE01A, 0xE23E)), (-0x21AE, (0xE00C, 0xE230)),
              (-0x21B4, (0xEA82, 0xEB32)), (-0x21BA, (0xEA74, 0xEB20))]
    for k, (disp, sites) in enumerate(TABLES):
        for at in sites:
            P.append((at, lea_a4(disp), lea_a4(P4B + 8 * k)))
    return P, [0x6342, 0xE8A8, 0x97EE, 0xE34A, 0xD674]   # nouvelles relocations

def reframe(text, start, end, link, moves, count):
    """Agrandit le cadre de pile d'une fonction (link a6,#n) et déplace ses
    tableaux locaux : chaque « lea/pea d16(a6) » listé dans moves est
    réécrit. count = nombre de remplacements attendus."""
    old, new = link
    assert text[start:start + 4].hex() == '4e56%04x' % old
    text[start:start + 4] = bytes.fromhex('4e56%04x' % new)
    n = 0
    for a in range(start + 4, end, 2):
        w = text[a:a + 4].hex()
        if w in moves:
            text[a:a + 4] = bytes.fromhex(moves[w]); n += 1
    assert n == count, (hex(start), n)

def reframe_all(text):
    # F_0DD20 (prepare to race) : 4 tableaux de 3 mots -> 4 mots
    reframe(text, 0xDD20, 0xE348, (0xffe4, 0xffc4),
            {'41eeffe4': '41eeffc4', '41eeffea': '41eeffcc', '41eefff0': '41eeffd4',
             '41eefff6': '41eeffdc', '486efff0': '486effd4'}, 28)
    # F_0CFEC (initiales) : curseurs (-$32), initiales 3x3 octets (-$2A),
    # -$1E, -$12, états (-$6) -> 4 voitures
    reframe(text, 0xCFEC, 0xD72E, (0xffce, 0xffa0),
            {'41eeffce': '41eeffa0', '41eeffd6': '41eeffa8', '41eeffd7': '41eeffa9',
             '41eeffd8': '41eeffaa', '41eeffe2': '41eeffb4', '41eeffee': '41eeffbc',
             '41eefffa': '41eeffc4', '486effee': '486effbc', '486efffa': '486effc4'}, 51)

# Correctifs du DATA (décalage dans le DATA ; a4 pointe sur son début).
# Même longueur que l'original, zéro final compris.
def txt(s, n):
    assert len(s) <= n
    return (s.encode() + b' ' * n)[:n].hex()
P4_DATA = [
    (0x1F4, txt('  mouse   ', 10), txt('   none   ', 10)),
    # aide : 1re ligne supprimée (chaîne vide), 2e ligne condensée
    (0x23E, txt('use function keys to select controls for cars', 45),
            '00' + txt('', 44)),
    (0x26C, txt('f2 - blue car   f3 - red car   f4 - yellow car', 46),
            txt('%-46s' % (' ' * 5 + 'f2 blue  f3 red  f4 yellow  f5 green'), 46)),
]

def main():
    a = sys.argv[1:]
    p4 = None
    auto = '--autopilot' in a
    if auto:
        a.remove('--autopilot')
    if '--p4' in a:
        i = a.index('--p4'); p4 = open(a[i + 1], 'rb').read(); del a[i:i + 2]
    if len(a) != 2:
        sys.exit(__doc__)
    raw = open(a[0], 'rb').read()
    if hashlib.md5(raw).hexdigest() != MD5:
        sys.exit('%s : ce n\'est pas le SUPER2.DAT attendu (MD5 %s)' % (a[0], MD5))
    TL, DL, BL, SL = struct.unpack('>IIII', raw[2:18])
    text = bytearray(raw[0x1C:0x1C + TL])
    data = raw[0x1C + TL:0x1C + TL + DL]
    # relocations d'origine
    rel, p = [], 0x1C + TL + DL + SL
    off = struct.unpack('>I', raw[p:p + 4])[0]; p += 4
    if off:
        rel.append(off)
        while raw[p]:
            if raw[p] == 1: off += 254
            else: off += raw[p]; rel.append(off)
            p += 1
    assert all(r < TL for r in rel)          # rien à décaler

    data = bytearray(data)
    patches, newrel = list(HD), []
    if auto:                                # tests seulement
        patches += AUTOPILOT
    if p4:
        pp, newrel = p4_patches(TL)
        patches += pp
        reframe_all(text)
        for at, old, new in P4_DATA:
            old, new = bytes.fromhex(old), bytes.fromhex(new)
            if data[at:at + len(old)] != old:
                sys.exit('octets inattendus dans le DATA en +$%X' % at)
            data[at:at + len(new)] = new
    for at, old, new in patches:
        old, new = bytes.fromhex(old), bytes.fromhex(new)
        assert len(old) == len(new), hex(at)
        if text[at:at + len(old)] != old:
            sys.exit('octets inattendus en $%X' % at)
        text[at:at + len(new)] = new
    if p4:
        text += p4 + b'\0' * (len(p4) & 1)
    rel = sorted(set(rel) | set(newrel))

    if p4:
        BL += BSSX
    out = bytearray(b'\x60\x1a' + struct.pack('>IIII', len(text), DL, BL, 0) + raw[18:0x1C])
    out += text + data
    out += struct.pack('>I', rel[0])
    for x, y in zip(rel, rel[1:]):
        d = y - x
        while d > 254:
            out.append(1); d -= 254
        out.append(d)
    out.append(0)
    open(a[1], 'wb').write(out)
    print('%s : %d octets, TEXT $%X%s, MD5 %s' % (a[1], len(out), len(text),
          ' (dont %d octets de p4)' % len(p4) if p4 else '', hashlib.md5(out).hexdigest()))

if __name__ == '__main__':
    main()
