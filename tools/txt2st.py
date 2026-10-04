"""txt2st.py <source UTF-8> <fichier ST> : texte lisible sur Atari ST.

Jeu de caractères de l'Atari ST (identique au CP437 pour les lettres
accentuées et les guillemets « », de $80 à $AF), fins de ligne CR LF,
lignes de 78 caractères au plus.
"""
import sys

def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    lines = open(sys.argv[1], encoding='utf-8').read().split('\n')
    out = bytearray()
    for n, l in enumerate(lines, 1):
        l = l.rstrip()
        if len(l) > 78:
            sys.exit('%s:%d : ligne de plus de 78 caractères' % (sys.argv[1], n))
        b = l.encode('cp437')
        if any(c >= 0xB0 for c in b):
            sys.exit('%s:%d : caractère absent du jeu de l\'Atari ST' % (sys.argv[1], n))
        out += b + b'\r\n'
    while out.endswith(b'\r\n\r\n'):
        out = out[:-2]
    open(sys.argv[2], 'wb').write(out)

if __name__ == '__main__':
    main()
