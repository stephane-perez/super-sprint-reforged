"""trace_ss.py : désassemblage récursif de Super Sprint (SUPER2.DAT, PRG GEMDOS).

SUPER2.DAT est un programme GEMDOS ordinaire (en-tête $601A, TEXT/DATA/BSS,
table de relocation). Il est chargé ici à l'adresse 0 : les adresses du
listing sont donc des décalages depuis le début du TEXT, et les mots longs
relogés sont connus exactement (contrairement à IK+, image brute).

Registres de base du code C (voir le démarrage en $25E) :
  - a5 = début du TEXT : « jsr $NN(a5) » passe par la table de sauts
    TEXT+$6..$25D (jmp absolus) ; le traceur suit ces appels ;
  - a4 : au démarrage, le DATA est recopié juste APRÈS le BSS, et a4 pointe
    sur ce DATA déplacé (a4 = TEXT + taille TEXT + taille BSS). Donc
    -$xxxx(a4) est dans le BSS et +$xxxx(a4) dans le DATA. Le listing
    ajoute en commentaire l'adresse équivalente dans la disposition du
    fichier (TEXT, DATA, BSS à la suite, base 0) : « ; @13a98 ». Une
    adresse @ < fin du DATA est donc lisible directement dans le listing.

Graines :
  - le point d'entrée (TEXT+0) ;
  - chaque cible relogée qui tombe dans le TEXT (pointeurs de fonctions,
    jsr/jmp/lea absolus) ;
  - chaque « link a6,#n » ($4E56) aligné (le code est du C compilé : une
    fonction = link ... unlk / rts) ;
  - graines faibles, validées à l'essai : cibles de « lea/pea x(pc) » qui
    suivent une fin de flot (routines d'interruption, notées I_xxxxx).

Sortie : work/ss.lst (listing annoté), work/ss_refs.txt (références aux
variables DATA/BSS et aux registres matériels).
"""
import sys, re, struct, os, collections, capstone

if len(sys.argv) < 2:
    sys.exit('usage : python3 tools/trace_ss.py <SUPER2.DAT>   (écrit work/ss.lst)')
raw = open(sys.argv[1], 'rb').read()
if raw[:2] != b'\x60\x1a':
    sys.exit('pas un PRG GEMDOS')
TL, DL, BL, SL = struct.unpack('>IIII', raw[2:18])
img = bytearray(raw[0x1C:0x1C + TL + DL]) + bytearray(BL)
END_T, END_D, END = TL, TL + DL, TL + DL + BL

# --- relocations (base 0 : on note seulement les emplacements) ---
rel = set()
p = 0x1C + TL + DL + SL
off = struct.unpack('>I', raw[p:p + 4])[0]; p += 4
if off:
    rel.add(off)
    while True:
        b = raw[p]; p += 1
        if b == 0: break
        if b == 1: off += 254; continue
        off += b; rel.add(off)

os.makedirs('work', exist_ok=True)
md = capstone.Cs(capstone.CS_ARCH_M68K, capstone.CS_MODE_M68K_000)
md.detail = True

def rd(a, n): return bytes(img[a:a + n])
def w16(a): return int.from_bytes(img[a:a + 2], 'big')
def l32(a): return int.from_bytes(img[a:a + 4], 'big')

_cache = {}
def dec(a):
    if a in _cache: return _cache[a]
    ins = None
    if 0 <= a < END_T - 1 and not a & 1:
        l = list(md.disasm(rd(a, 10), a, 1))
        if l:
            ins = l[0]
            if ins.id == 0 or ins.mnemonic.startswith('dc'):
                ins = None
            elif re.search(r'\(\[|\]\)|\*\s*[248]|,\s*[ad]\d\.[wl]\s*\*', ins.op_str):
                ins = None                       # modes 68020
            else:
                b = w16(a)                       # capstone : asl.w d16(An)
                if (b & 0xF8C0) == 0xE0C0 and ins.size == 2 and ((b >> 3) & 7) in (5, 6, 7):
                    ins = None
    _cache[a] = ins
    return ins

BR = {'bra', 'bsr', 'bhi', 'bls', 'bcc', 'bcs', 'bne', 'beq', 'bvc', 'bvs', 'bpl', 'bmi',
      'bge', 'blt', 'bgt', 'ble', 'bhs', 'blo'}
END_FLOW = {'rts', 'rte', 'rtr', 'jmp', 'bra', 'illegal', 'stop'}

def targets(ins):
    t, mn = [], ins.mnemonic.split('.')[0]
    if mn in BR or mn.startswith('db'):
        for o in ins.operands:
            if o.type == capstone.m68k.M68K_OP_BR_DISP:
                t.append(ins.address + 2 + o.br_disp.disp)
        if not t:
            m = re.search(r'\$([0-9a-f]+)$', ins.op_str)
            if m: t.append(int(m.group(1), 16))
    elif mn in ('jmp', 'jsr'):
        for k in range(2, ins.size - 3):
            if ins.address + k in rel:
                t.append(l32(ins.address + k))
        m = re.fullmatch(r'\$([0-9a-f]+)\(pc\)', ins.op_str.strip())
        if m: t.append(int(m.group(1), 16))
        m = re.fullmatch(r'\$([0-9a-f]+)\(a5\)', ins.op_str.strip())
        if m:                                    # table de sauts : a5 = début du TEXT
            j = int(m.group(1), 16)
            if w16(j) == 0x4EF9: t.append(l32(j + 2))
    return t

code, owner, labels = {}, {}, {}
def trace(start, commit=True):
    """trace depuis start. commit=False : essai, rejeté (None) si le chemin
    rencontre un opcode invalide ou chevauche une instruction connue."""
    todo, new, nown = [start], {}, {}
    while todo:
        a = todo.pop()
        while 0 <= a < END_T and a not in code and a not in new:
            ins = dec(a)
            if ins is None or any((a + k) in owner or (a + k) in nown for k in range(ins.size)):
                if not commit: return None
                break
            new[a] = ins
            for k in range(ins.size): nown[a + k] = a
            for t in targets(ins):
                if 0 <= t < END_T and not t & 1:
                    todo.append(t)
                elif not commit and 0 <= t < END_T:
                    return None
            if ins.mnemonic.split('.')[0] in END_FLOW: break
            a += ins.size
    if commit:
        code.update(new); owner.update(nown)
        for a, ins in new.items():
            for t in targets(ins):
                if 0 <= t < END_T and not t & 1:
                    labels.setdefault(t, 'sub' if ins.mnemonic.startswith(('bsr', 'jsr')) else 'loc')
    return new

def after_end(v):
    """v suit-il une fin de flot (rts/rte/unlk+rts/jmp/bra) ?"""
    w = w16(v - 2)
    return (w in (0x4E75, 0x4E73, 0x4E77) or ((w & 0xFF00) == 0x6000 and w & 0xFF)
            or w16(v - 4) in (0x6000, 0x4EF8) or w16(v - 6) == 0x4EF9)

labels[0] = 'entry'; trace(0)
for r in sorted(rel):                              # pointeurs relogés vers le TEXT
    v = l32(r)
    if 0 <= v < END_T and not v & 1:
        labels.setdefault(v, 'ptr'); trace(v)
for a in range(0, END_T - 4, 2):                   # fonctions C non atteintes
    if w16(a) == 0x4E56 and a not in owner:
        labels.setdefault(a, 'fn'); trace(a)
# graines faibles : lea/pea x(pc) vers du code non reconnu (routines
# d'interruption installées par « lea isr(pc),a0 / move.l a0,$70 »...)
changed = True
while changed:
    changed = False
    for a, ins in sorted(code.items()):
        if ins.mnemonic.split('.')[0] in ('lea', 'pea'):
            m = re.match(r'\$([0-9a-f]+)\(pc\)', ins.op_str)
            if m:
                v = int(m.group(1), 16)
                if v < END_T and not v & 1 and w16(v) and v not in owner and after_end(v) and trace(v, False):
                    labels.setdefault(v, 'isr'); trace(v); changed = True

def seg(v):
    return 'T' if v < END_T else 'D' if v < END_D else 'B' if v < END else None
def name(a):
    k = labels.get(a)
    if not k: return None
    return 'entry' if k == 'entry' else {'sub': 'F_%05x', 'fn': 'F_%05x', 'ptr': 'P_%05x', 'loc': 'L_%05x', 'isr': 'I_%05x'}[k] % a

refs = collections.defaultdict(set)
with open('work/ss.lst', 'w') as f:
    f.write('; Super Sprint - SUPER2.DAT chargé en 0. TEXT $0-$%x, DATA $%x-$%x, BSS $%x-$%x\n'
            % (END_T, END_T, END_D, END_D, END))
    a = 0
    while a < END_D:
        n = name(a)
        if a in code:
            ins = code[a]
            if n: f.write('\n%s:\n' % n)
            ops = ins.op_str
            for k in range(2, ins.size - 3):          # adresses relogées -> noms
                if a + k in rel:
                    v = l32(a + k); s = seg(v)
                    nm = name(v) or ('%s_%05x' % (s, v) if s in 'DB' else None)
                    if s in ('D', 'B'): refs[v].add(a)
                    if nm: ops = re.sub(r'\$%x\b' % v, nm, ops, count=1)
            for m in re.finditer(r'\$(ff[0-9a-f]{4})\b', ops):   # E/S matérielles
                refs[0xFF000000 | int(m.group(1), 16)].add(a)
            cm = []
            for m in re.finditer(r'(-?)\$([0-9a-f]+)\(a4', ins.op_str):
                k = int(m.group(2), 16)
                v = END - k if m.group(1) else END_T + k     # BSS / DATA
                refs[v].add(a); cm.append('@%x' % v)
            m = re.fullmatch(r'\$([0-9a-f]+)\(a5\)', ins.op_str.strip())
            if m and w16(int(m.group(1), 16)) == 0x4EF9:
                v = l32(int(m.group(1), 16) + 2); cm.append('-> %s' % (name(v) or '$%x' % v))
            f.write('%06x  %-20s %-8s %-28s%s\n' % (a, rd(a, ins.size).hex(), ins.mnemonic, ops,
                    ('; ' + ' '.join(cm)) if cm else ''))
            a += ins.size
        else:
            b = a + 1
            while b < END_D and b not in code and b not in labels: b += 1
            if n: f.write('\n%s:\n' % n)
            chunk = rd(a, b - a)
            for i in range(0, len(chunk), 16):
                c = chunk[i:i + 16]
                f.write('%06x  dc.b %-48s ; %s\n' % (a + i, c.hex(' '),
                        ''.join(chr(x) if 32 <= x < 127 else '.' for x in c)))
            a = b
with open('work/ss_refs.txt', 'w') as f:
    for v in sorted(refs):
        f.write('%08x %s\n' % (v, ' '.join('%x' % x for x in sorted(refs[v]))))
ncode = sum(i.size for i in code.values())
print('TEXT %d octets, code reconnu %d (%.1f %%), %d instructions, %d labels, %d relocations'
      % (END_T, ncode, 100 * ncode / END_T, len(code), len(labels), len(rel)))
