#!/usr/bin/env python3
"""Guarda do CONTRATO: a tabela de mkinds do docs/ast-schema.md x os dumps do corpus.

O ast-schema e' o unico markdown de FATO fora do pp-corpus -- e e' o que mais mentiu
(ele afirmava que `strdump` nao existia em regra, e que `__DATE__` era dinamico: as
duas falsas). Aqui ele passa a ser conferido nos DOIS sentidos:

  (a) mkind DOCUMENTADO tem de APARECER em algum dump do corpus -- ou trazer, na
      propria linha, a palavra RECUSA (o caso do `dynval`, que o usuario nao escreve);
  (b) mkind que APARECE num dump tem de estar DOCUMENTADO -- senao o core ganhou um
      canal que a doc nao conta.

uso: ppc-schema.py <docs/ast-schema.md> <dir com os dumps do corpus>
"""
import glob
import json
import os
import re
import sys

md, dumps = sys.argv[1], sys.argv[2]

doc = {}
for l in open(md).read().split("\n"):
    m = re.match(r"\s*\|\s*`(\w+)`\s*\|", l)
    if m:
        doc[m.group(1)] = l

vistos = set()
for f in glob.glob(os.path.join(dumps, "*", "*.ast.json")):
    try:
        d = json.load(open(f))
    except Exception:
        continue
    for r in (d.get("ppRules") or []):
        for lado in ("match", "result"):
            for t in (r.get(lado) or []):
                if t.get("mkind"):
                    vistos.add(t["mkind"])

falhas = []
for mk, linha in doc.items():
    if mk in vistos:
        continue
    if "RECUSA" not in linha.upper():
        falhas.append("mkind '%s' esta' documentado e NAO aparece em dump nenhum do "
                      "corpus (nem traz RECUSA na linha)" % mk)
for mk in sorted(vistos):
    if mk not in doc:
        falhas.append("mkind '%s' APARECE nos dumps e NAO esta' no ast-schema" % mk)

for f in falhas:
    print("  ", f)
sys.exit(1 if falhas else 0)
