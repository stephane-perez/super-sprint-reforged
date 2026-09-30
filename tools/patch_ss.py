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

def p4_patches(B):
    """B = adresse du code ajouté (fin du TEXT d'origine)."""
    def jsr_pc(at, target):                 # jsr d16(pc) + nop (6 octets)
        d = target - (at + 2)
        assert -0x8000 <= d < 0x8000, hex(at)
        return '4eba%04x4e71' % (d & 0xFFFF)
    def jmp_abs(target):
        return '4ef9%08x' % target
    E = lambda n: B + 4 * n                 # table d'entrée de p4.s
    return [
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
        (0x0132, '4ef90000a2e4', jmp_abs(E(7))),
        # table de sauts, entrée $18c (F_0A546, décompression) : image des
        # options / prepare to race / initiales avec 4 voitures
        (0x018C, '4ef90000a546', jmp_abs(E(8))),
        # F_0E850 : les 6 grands titres -> titles, puis saut à la suite
        (0xE8A6, '3f3c00053f3c00203f3c', '4eb9%08x600000a0' % E(9)),
        # F_0E3CA (une voiture rejoint la course) : 4 voitures, pas de texte
        # d'en-tête pour la 4e
        (0xE422, '4eba0258', '4eba%04x' % ((E(2) - 0xE424) & 0xFFFF)),
        (0xE484, '0c6e0003fffe', '0c6e0004fffe'),
        # F_0F4E2 (idem pendant « prepare to race »)
        (0xF53A, '4eba0024', '4eba%04x' % ((E(6) - 0xF53C) & 0xFFFF)),
        (0xF552, '0c6e0003fffe', '0c6e0004fffe'),
        # écran des options (F_0E850)
        (0xEA10, '41ecde28d0c0', jsr_pc(0xEA10, E(4))),   # x libellé, voiture i
        (0xEA28, '41ecde36d0c0', jsr_pc(0xEA28, E(3))),   # nom du contrôle
        (0xEA40, '0c6e0003fffe', '0c6e0004fffe'),         # affichage : 4 voitures
        (0xEBA4, '0c6e0005fffe', '0c6e0006fffe'),         # F2..F5
        (0xEBBE, 'c07c0003', 'c07c0007'),                 # 8 contrôles
        (0xEBE0, '66000010', '60000010'),                 # 1 (« none ») permis
        (0xEC04, '41ecde24d0c0', jsr_pc(0xEC04, E(5))),   # x libellé, touche
        (0xEC1C, '41ecde36d0c0', jsr_pc(0xEC1C, E(3))),
        (0xECBC, '0c6e0003fffc', '0c6e0004fffc'),         # contrôles en double :
        (0xECCA, '0c6e0003fffe', '0c6e0004fffe'),         # 4 voitures
        (0xEC96, '66000020', '60000020'),                 # plus de conflit souris
        (0xED6E, '41ecde28d0c0', jsr_pc(0xED6E, E(4))),
        (0xED86, '41ecde36d0c0', jsr_pc(0xED86, E(3))),
        (0xED9E, '0c6e0003fffe', '0c6e0004fffe'),
    ], [0x6342, 0xE8A8]                      # nouvelles relocations

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
