#!/usr/bin/env python3
import sys
p = sys.argv[1]
start = sys.argv[2]
lines = open(p, encoding='utf-8', errors='replace').read().split('\n')
out, on = [], False
for l in lines:
    if l.startswith(start):
        on = True
    elif on and l == '}':
        out.append(l); break
    if on:
        out.append(l)
print('\n'.join(out))