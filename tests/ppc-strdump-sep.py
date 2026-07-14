#!/usr/bin/env python3
"""Guarda da familia STRDUMP: o que SEPARA simbolo de dado nao e' o `generates`
(ele e' true nos DOIS sitios) nem o texto (e' o mesmo) -- e sim a OP da derivacao.

   SELO nLastro AFERIDO  -> o mesmo byte sai com 'clone' E 'stringify'  (simbolo)
   LAVRA nLastro         -> sai so' com 'stringify'                     (dado)

As linhas se COMPUTAM do fonte no estado corrente -- nunca se contam na mao (a
fixture ganha e perde comentario o tempo todo).

uso: ppc-strdump-sep.py <sd.ast.json> <sd.prg>
"""
import json
import sys

dump, prg = sys.argv[1], sys.argv[2]
d = json.load(open(dump))
src = open(prg).read().split("\n")

selo = [i + 1 for i, l in enumerate(src) if l.strip() == "SELO nLastro AFERIDO"][0]
lavra = [i + 1 for i, l in enumerate(src) if l.strip() == "LAVRA nLastro"][0]

ops = {}
for t in d["tokens"]:
    if t.get("text") == "nLastro" and t.get("from"):
        ops.setdefault(t["line"], set()).update(f["op"] for f in t["from"])

gen = {t["line"]: t.get("generates")
       for a in d["ppApplications"] for t in a["tokens"]
       if t.get("text") == "nLastro" and t.get("marker", 0) >= 1}

falhas = []
if ops.get(selo) != {"clone", "stringify"}:
    falhas.append("SELO (linha %d): esperava clone+stringify, veio %s" % (selo, ops.get(selo)))
if ops.get(lavra) != {"stringify"}:
    falhas.append("LAVRA (linha %d): esperava so' stringify, veio %s" % (lavra, ops.get(lavra)))
if not (gen.get(selo) and gen.get(lavra)):
    falhas.append("o `generates` deveria ser true nos DOIS sitios: %s" % gen)

for f in falhas:
    print("  ", f)
sys.exit(1 if falhas else 0)
