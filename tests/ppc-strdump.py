#!/usr/bin/env python3
"""Guarda da familia STRDUMP: prova que o mkind `strdump` (o `#<x>`) EXISTE no
`result[]` de regra REAL -- a afirmacao que o corpus dava como recusa
documentada ("nao existe em regra") ate 2026-07-13.

uso: ppc-strdump.py <dump.ast.json> <basename-do-header> [<cabeca-esperada>]
sai 0 se ALGUMA regra declarada naquele header emite um marker de mkind strdump.
"""
import json
import sys

dump, header = sys.argv[1], sys.argv[2]
head = sys.argv[3].upper() if len(sys.argv) > 3 else None

d = json.load(open(dump))
for r in d.get("ppRules") or []:
    f = r.get("file")
    if not f or not f.replace("\\", "/").endswith(header):
        continue
    if head and (r.get("head") or "").upper() != head:
        continue
    if any(m.get("mkind") == "strdump" for m in (r.get("result") or [])):
        print("strdump em regra REAL: %s:%s  #%s %s" %
              (header, r.get("line"), r.get("kind"), r.get("head")))
        sys.exit(0)

print("FALHOU: nenhuma regra de %s%s emite strdump" %
      (header, " com cabeca " + head if head else ""))
sys.exit(1)
