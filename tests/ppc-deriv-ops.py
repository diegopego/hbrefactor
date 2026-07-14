#!/usr/bin/env python3
"""Guarda da familia DERIVACAO: as tres OPs, e o ELO com offset.

  clone     -- o token copiado CHEGA ao compilador, com a posicao do fonte
  paste     -- o nome colado dentro de outro identificador: token SEM posicao, e o
               `from` diz em que OFFSET do artefato o nome mora (at/len)
  stringify -- o nome citado: string, tambem sem posicao, tambem ligada pelo `from`

uso: ppc-deriv-ops.py <dv.ast.json> <dv.prg>
"""
import json
import sys

d = json.load(open(sys.argv[1]))
src = open(sys.argv[2]).read().split("\n")
lin_forja = [i + 1 for i, l in enumerate(src) if l.strip() == "FORJA Alfa"][0]

falhas = []

# (1) clone: o `cAlvo` do ECOA chega POSICIONADO (prov 's', col nao-nula)
clone = [t for t in d["tokens"]
         if t.get("text") == "cAlvo" and any(f["op"] == "clone" for f in (t.get("from") or []))]
if not clone or clone[0].get("col") is None or clone[0].get("prov") != "s":
    falhas.append("clone: o token copiado deveria chegar posicionado: %s" % clone)

# (2) paste: nasce `fj_Alfa`, SEM posicao, e o `from` aponta o offset do nome
paste = [t for t in d["tokens"]
         if t.get("text") == "fj_Alfa"
         and any(f["op"] == "paste" for f in (t.get("from") or []))]
if len(paste) != 1 or paste[0].get("col") is not None or paste[0].get("prov") != "n":
    falhas.append("paste: o artefato colado deveria vir SEM posicao: %s" % paste)
else:
    f = [x for x in paste[0]["from"] if x["op"] == "paste"][0]
    if (f["at"], f["len"]) != (3, 4):      # "fj_" + "Alfa"
        falhas.append("paste: o `from` deveria dizer at=3 len=4 (o nome dentro do "
                      "artefato), veio at=%s len=%s" % (f["at"], f["len"]))

# (3) stringify: nasce a string "Alfa", tambem sem posicao
strf = [t for t in d["tokens"]
        if t.get("text") == "Alfa"
        and any(f["op"] == "stringify" for f in (t.get("from") or []))]
if len(strf) != 1 or strf[0].get("col") is not None:
    falhas.append("stringify: a string derivada deveria vir SEM posicao: %s" % strf)

# (4) o NOME ESCRITO -- o unico com posicao -- e' o alvo do rename
escrito = [t for a in d["ppApplications"] for t in a["tokens"]
           if t.get("text") == "Alfa" and t.get("line") == lin_forja]
if not escrito or escrito[0].get("col") is None or not escrito[0].get("generates"):
    falhas.append("o nome ESCRITO (linha %d) deveria ter coluna e generates: %s"
                  % (lin_forja, escrito))

for f in falhas:
    print("  ", f)
sys.exit(1 if falhas else 0)
