"""show.py <début> <fin> : extrait du listing work/ss.lst (adresses hex)."""
import sys
a, b = int(sys.argv[1], 16), int(sys.argv[2], 16)
for l in open('work/ss.lst'):
    t = l[:6]
    s = l.strip()
    if len(t) == 6 and all(c in '0123456789abcdef' for c in t):
        if a <= int(t, 16) <= b: print(l, end='')
    elif s.endswith(':') and s[:2] in ('F_', 'L_', 'P_', 'T_') and a <= int(s[2:-1], 16) <= b:
        print(l, end='')
