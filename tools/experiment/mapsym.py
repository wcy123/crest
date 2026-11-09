import re, sys, bisect
mapfile, crash = sys.argv[1], sys.argv[2]
syms = []
for line in open(mapfile, errors='replace'):
    m = re.match(r'\s*[0-9a-f]{4}:[0-9a-f]{8}\s+(\S+)\s+([0-9a-f]{16})\s+(?:f\s+i?\s*|)\s*(\S*)', line)
    if m:
        syms.append((int(m.group(2), 16), m.group(1), m.group(3)))
syms.sort()
print('symbols:', len(syms))
text = open(crash, errors='replace').read()
seen = []
for off in re.findall(r'crest-opt\.exe\+0x([0-9a-fA-F]+)', text):
    if off in seen: continue
    seen.append(off)
    va = 0x140000000 + int(off, 16)
    i = bisect.bisect_right([s[0] for s in syms], va) - 1
    for j in range(max(0, i - 1), min(len(syms), i + 2)):
        mark = '>>' if j == i else '  '
        print(mark, hex(va), '->', hex(syms[j][0]), syms[j][1][:140], syms[j][2])
    print()
