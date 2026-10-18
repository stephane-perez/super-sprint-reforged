"""title_patch.py <nouveau.PI1> <titre d'origine.png> <sortie.inc>

Fabrique src/title.inc : les retouches de l'écran titre (« REFORGED »,
dessin de Strider) sous forme de correctif, sans rien de l'image du jeu.

- <nouveau.PI1> : l'écran titre retouché (Degas, basse résolution) ;
- <titre d'origine.png> : l'image d'origine en couleurs indexées, dans
  l'ordre de la palette du jeu (par exemple une capture sous Hatari).

Le fichier produit contient :
- titlepal : la nouvelle palette, dans l'ordre des couleurs du jeu (chaque
  couleur du PI1 doit correspondre à une couleur d'origine, éventuellement
  retouchée) ;
- titlepix : pour chaque bloc de 16 pixels qui change, son décalage dans
  l'écran, le masque des pixels changés et leurs 4 plans (bits hors du
  masque à 0). Seuls les pixels redessinés y figurent.
"""
import sys, struct
from PIL import Image

def pi1(path):
    d = open(path, 'rb').read()
    pal = [p & 0x777 for p in struct.unpack('>16H', d[2:34])]
    scr = d[34:34 + 32000]
    idx = [[0] * 320 for _ in range(200)]
    for y in range(200):
        for b in range(20):
            w = struct.unpack('>4H', scr[y * 160 + b * 8:y * 160 + b * 8 + 8])
            for x in range(16):
                bit = 15 - x
                idx[y][b * 16 + x] = sum(((w[p] >> bit) & 1) << p for p in range(4))
    return pal, idx

def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    newpal, new = pi1(sys.argv[1])
    ref = Image.open(sys.argv[2])
    old = ref.load()
    rp = ref.getpalette()[:48]
    oldpal = [((round(rp[i * 3] * 7 / 255)) << 8) | ((round(rp[i * 3 + 1] * 7 / 255)) << 4)
              | round(rp[i * 3 + 2] * 7 / 255) for i in range(16)]
    # couleur du PI1 -> index d'origine : pour chaque index d'origine, la
    # couleur du PI1 la plus fréquente sur ses pixels inchangés
    votes = {}
    for y in range(200):
        for x in range(320):
            votes.setdefault(old[x, y], {}).setdefault(newpal[new[y][x]], 0)
            votes[old[x, y]][newpal[new[y][x]]] += 1
    pal2 = [max(votes[i], key=votes[i].get) if i in votes else oldpal[i] for i in range(16)]
    if len(set(pal2)) != 16:
        sys.exit('palette ambiguë : %s' % ['%03x' % c for c in pal2])
    col2idx = {c: i for i, c in enumerate(pal2)}
    out = ['; src/title.inc : produit par tools/title_patch.py (ne pas modifier)',
           '; écran titre retouché : « REFORGED », dessin de Strider', '',
           'titlepal    dc.w    ' + ','.join('$%03x' % c for c in pal2), '',
           '; bloc : décalage, masque des pixels changés, 4 plans ; -1 = fin',
           'titlepix']
    n = 0
    for y in range(200):
        for b in range(20):
            mask, planes = 0, [0, 0, 0, 0]
            for x in range(16):
                c = newpal[new[y][b * 16 + x]]
                if c not in col2idx:
                    sys.exit('couleur %03x absente de la palette' % c)
                i = col2idx[c]
                if i != old[b * 16 + x, y]:
                    bit = 15 - x
                    mask |= 1 << bit
                    for p in range(4):
                        planes[p] |= ((i >> p) & 1) << bit
            if mask:
                out.append('            dc.w    %d,$%04x,$%04x,$%04x,$%04x,$%04x'
                           % (y * 160 + b * 8, mask, *planes))
                n += 1
    out.append('            dc.w    -1')
    open(sys.argv[3], 'w').write('\n'.join(out) + '\n')
    print('%s : palette %s, %d blocs' % (sys.argv[3], ' '.join('%03x' % c for c in pal2), n))

if __name__ == '__main__':
    main()
