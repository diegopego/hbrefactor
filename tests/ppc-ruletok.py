#!/usr/bin/env python3
"""Guarda do corpus (familia ABREVIACAO / ast-15): o `ruletok` diz QUAL literal
da regra um token consumido casou.

O furo que este fato matou: em `#command GRAVAR <x> GRAV <y>`, a keyword
SECUNDARIA `GRAV` escrita POR EXTENSO e um prefixo de 4 letras da CABECA
`GRAVAR` - e `#command` (familia sem 'x') casa keyword abreviada a partir de 4
letras (ppcore.c:2533). Olhando so o TEXTO, os dois sao indistinguiveis; o pp
SABE (ele casou) e ate o ast-14 nao contava. Aqui exigimos o fato: o token
`GRAV` tem de vir com ruletok == 2 (o indice dele no match[] da regra), NAO 0
(a cabeca).
"""
import json
import sys

with open(sys.argv[1]) as fh:
    dump = json.load(fh)

for app in dump["ppApplications"]:
    rule = dump["ppRules"][app["rule"]]
    if not rule.get("file") or "abr.ch" not in rule["file"]:
        continue
    for tok in app["tokens"]:
        if tok.get("text", "").upper() == "GRAV" and tok.get("marker") == 0:
            idx = tok.get("ruletok")
            if idx == 2 and rule["match"][2]["text"].upper() == "GRAV":
                sys.exit(0)

sys.exit(1)
