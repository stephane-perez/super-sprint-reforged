"""check_data.py <dossier> : vérifie les fichiers de données de VOTRE copie.

SUPER.DAT, SUPER1.DAT et INIT.DAT sont recopiés tels quels à côté de
SSPRINT.PRG : ils doivent être ceux de la version étudiée (taille et MD5
ci-dessous), non compressés. SUPER2.DAT est vérifié par patch_ss.py ;
SSPRINT.HSC (records) et SSPRINT.SEQ changent d'une copie à l'autre et ne
sont pas vérifiés.
"""
import sys, os, hashlib, struct

FILES = [                       # nom, taille, MD5
    ('SUPER.DAT', 212650, '3692bea1615e36f003cec5e14bc54669'),
    ('SUPER1.DAT', 17024, 'b3c2e08bb9fd5ab92eab39b45fd713a1'),
    ('INIT.DAT', 5139, '68d72c8952f071b6b0ca513d8bf1c989'),
]

def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    bad = 0
    for name, size, md5 in FILES:
        p = os.path.join(sys.argv[1], name)
        if not os.path.isfile(p):
            print('%s : absent' % p); bad = 1; continue
        d = open(p, 'rb').read()
        if hashlib.md5(d).hexdigest() == md5:
            continue
        bad = 1
        msg = '%s : ce n\'est pas le fichier attendu (%d octets, %d attendus)' % (p, len(d), size)
        # en-tête d'un fichier compressé (taille compressée, taille
        # d'origine, somme), comme dans certaines versions crackées
        if len(d) >= 12:
            packed, unpacked = struct.unpack('>II', d[:8])
            if packed == len(d) - 12 and unpacked == size:
                msg += ' ; il semble compressé : il faut le fichier d\'origine'
        print(msg)
    if bad:
        sys.exit('Fichiers de données incorrects : voir la liste dans README.md.')
    print('Fichiers de données : OK')

if __name__ == '__main__':
    main()
