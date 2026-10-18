"""vbl.py <log.txt> : vitesse du jeu (VBL par image) par tranches de 5 s.

Hatari lancé avec --parse <fichier.ini> contenant
    b pc = <base du TEXT + $A346> :quiet :file <fichier2.ini>
et <fichier2.ini> contenant les deux lignes « e VBL » et « c » : à chaque
échange d'écran (F_0A346), le numéro du VBL est écrit dans le journal.
Base du TEXT : $15BE0 sur STE + EmuTOS 1.3 (256 Ko, uk), donc $1FF26.
"""
import sys, re
from collections import Counter
v = [int(x) for x in re.findall(r'#(\d+) \(dec\)', open(sys.argv[1]).read())]
d = [b - a for a, b in zip(v, v[1:])]
i = 0
while i < len(v):
    j = i
    while j < len(v) and v[j] - v[i] < 250:
        j += 1
    seg = d[i:j - 1]
    if seg:
        print(v[i] // 50, 's', '%.2f VBL/img' % (sum(seg) / len(seg)),
              dict(Counter(seg).most_common(4)))
    i = j
